function fit = fit_daily_seiqrd(data, cfg, opts)
%FIT_DAILY_SEIQRD  Fit the daily three-route SEIQRD model.
%
%   fit = fit_daily_seiqrd(data, cfg)
%   fit = fit_daily_seiqrd(data, cfg, opts)
%
%   Six fitted parameters:
%     q = [betaC0, u1, u2, alpha0, mu, rhoRep]
%
%   Fixed: sigma, gamma, gammaQ, nu, rhoH0, rhoF0, rhoM.
%   Observation: C_pred = C0 + rhoRep*(C_model - C_model(0));
%                M_pred = M0 + rhoM*(M_model - M_model(0)).
%   The model is simulated on the full daily series; residuals use the fit
%   window (2026-06-21..2026-10-25), with weekly aggregation and a CFR soft
%   constraint. Holdout (10-26..11-09) is used only for metrics.

if nargin < 3 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'nStarts', 3);
opts = set_default(opts, 'verbose', true);
opts = set_default(opts, 'fixRhoRep', false);
opts = set_default(opts, 'allowRebound', true);

p0 = daily_params(cfg, data);
[y0, initInfo] = daily_initial_state(data, cfg, p0);

tAll = data.daily.t;
tFit = data.t;
Cobs = data.cases;
Mobs = data.deaths;
C0 = Cobs(1);
M0 = Mobs(1);

Wk = data.seriesWeekly;
tWeek = days(Wk.weekEnd(:) - cfg.dayZero);
Cw = Wk.cases;
Mw = Wk.deaths;
idxWeek = tWeek <= tFit(end);

% Bounds for q = [betaC0, u1, u2, alpha0, mu, rhoRep].
% u2 is allowed negative: a negative value is a rebound/relaxation at the
% second knot, which the late plateau requires; u2 >= 0 is the monotone
% reduction case in the modelling note.
lb = [0.03, 0.00, -0.50, 0.03, 0.010, 0.50];
ub = [0.60, 0.95, 0.95, 0.60, 0.090, 0.90];

if ~opts.allowRebound
    lb(3) = 0.00;
end

q0List = [0.20, 0.30, 0.10, 0.15, 0.032, 0.70;
          0.15, 0.20, 0.20, 0.20, 0.036, 0.60;
          0.25, 0.40, 0.05, 0.12, 0.028, 0.80;
          0.12, 0.10, 0.30, 0.25, 0.040, 0.70;
          0.30, 0.50, 0.10, 0.10, 0.025, 0.75];
q0List = q0List(1:min(opts.nStarts, size(q0List, 1)), :);

if opts.fixRhoRep
    lb(6) = 0.999;
    ub(6) = 1.001;
    q0List(:, 6) = 1.0;
end

lsOpts = optimoptions('lsqnonlin', ...
    'Display', 'off', ...
    'MaxFunctionEvaluations', 600, ...
    'MaxIterations', 400, ...
    'FunctionTolerance', 1e-8, ...
    'StepTolerance', 1e-8);

bestCost = inf;
bestQ = [];
bestExit = 0;

for k = 1:size(q0List, 1)
    obj = @(q) residuals(q, data, cfg, p0, y0, tAll, tFit, ...
        Cobs, Mobs, C0, M0, tWeek, Cw, Mw, idxWeek);
    try
        [qfit, resnorm, ~, exitflag] = lsqnonlin( ...
            obj, q0List(k, :), lb, ub, lsOpts);
    catch err
        if opts.verbose
            fprintf('  start %d failed: %s\n', k, err.message);
        end
        continue;
    end
    if opts.verbose
        fprintf(['  start %d: cost %.6g, betaC0 %.4f, u1 %.3f, ' ...
            'u2 %.3f, alpha %.4f, mu %.4f, rhoRep %.3f\n'], ...
            k, resnorm, qfit(1), qfit(2), qfit(3), qfit(4), ...
            qfit(5), qfit(6));
    end
    if resnorm < bestCost
        bestCost = resnorm;
        bestQ = qfit;
        bestExit = exitflag;
    end
end

if isempty(bestQ)
    error('fit_daily_seiqrd:allFailed', 'All least-squares starts failed.');
end

p = apply_q(p0, bestQ);
betaFun = make_beta_fun(p.betaC0, p.u1, p.u2, p.knots);
sim = simulate_daily_seiqrd(p, tAll, y0, betaFun);
[Cpred, Mpred] = observation_curve(sim, C0, M0, p.rhoRep, p.rhoM);
metrics = compute_metrics(data, p, sim, Cpred, Mpred, ...
    C0, M0, tFit, Cobs, Mobs, tWeek, Cw, Mw);

fit = struct();
fit.params = p;
fit.q = bestQ;
fit.y0 = y0;
fit.init = initInfo;
fit.sim = sim;
fit.Cpred = Cpred;
fit.Mpred = Mpred;
fit.betaFun = betaFun;
fit.metrics = metrics;
fit.cost = bestCost;
fit.success = bestExit > 0;
fit.rhoRepMode = opts.fixRhoRep;
fit.allowRebound = opts.allowRebound;
end

% -------------------------------------------------------------------------
% Local functions
% -------------------------------------------------------------------------
function res = residuals(q, data, cfg, p0, y0, tAll, tFit, ...
    Cobs, Mobs, C0, M0, tWeek, Cw, Mw, idxWeek) %#ok<INUSD>

p = apply_q(p0, q);
betaFun = make_beta_fun(p.betaC0, p.u1, p.u2, p.knots);
try
    sim = simulate_daily_seiqrd(p, tAll, y0, betaFun);
catch
    res = 1e6 * ones(300, 1);
    return;
end
if any(~isfinite(sim.C)) || any(~isfinite(sim.M)) || ...
        any(sim.C <= 0) || any(sim.M <= 0)
    res = 1e6 * ones(300, 1);
    return;
end

[Cpred, Mpred] = observation_curve(sim, C0, M0, p.rhoRep, p.rhoM);
nFit = numel(tFit);
idxFit = 1:nFit;

% Daily log residuals.
rC = log(Cpred(idxFit)) - log(Cobs);
rM = cfg.fitWeights.mu * (log(Mpred(idxFit)) - log(Mobs));

% Weekly aggregation residuals (fit window only).
CwPred = interp1(tAll, Cpred, tWeek, 'linear', 'extrap');
MwPred = interp1(tAll, Mpred, tWeek, 'linear', 'extrap');
rCw = cfg.fitWeights.weekly * ...
    (log(CwPred(idxWeek)) - log(Cw(idxWeek)));
rMw = cfg.fitWeights.weekly * cfg.fitWeights.mu * ...
    (log(MwPred(idxWeek)) - log(Mw(idxWeek)));

% CFR soft constraint at the end of the fit window.
cfrModel = (Mpred(nFit) - M0) / (Cpred(nFit) - C0);
cfrObs = (Mobs(end) - M0) / (Cobs(end) - C0);
rCFR = cfg.fitWeights.cfr * (cfrModel - cfrObs);

% Weak priors.
rAlpha = cfg.fitWeights.alpha * log(q(4) / cfg.alphaPrior);
rMu = cfg.fitWeights.muPrior * log(q(5) / cfg.muPrior);
rRho = cfg.fitWeights.rho * ((q(6) - 0.70) / 0.20);

res = [rC; rM; rCw; rMw; rCFR; rAlpha; rMu; rRho];
end

function p = apply_q(p0, q)
p = p0;
p.betaC0 = q(1);
p.u1 = q(2);
p.u2 = q(3);
p.alpha = q(4);
p.mu = q(5);
p.muQ = q(5);
p.rhoRep = q(6);
end

function [Cpred, Mpred] = observation_curve(sim, C0, M0, rhoRep, rhoM)
Cpred = C0 + rhoRep * (sim.C - sim.C(1));
Mpred = M0 + rhoM * (sim.M - sim.M(1));
end

function m = compute_metrics(data, p, sim, Cpred, Mpred, ...
    C0, M0, tFit, Cobs, Mobs, tWeek, Cw, Mw)

nFit = numel(tFit);
idxFit = 1:nFit;
idxHold = nFit + 1:numel(Cpred);

m = struct();
m.R2cases = r2(Cobs, Cpred(idxFit));
m.R2deaths = r2(Mobs, Mpred(idxFit));
m.RMSEcases = rmse(Cobs, Cpred(idxFit));
m.RMSEdeaths = rmse(Mobs, Mpred(idxFit));

CwPred = interp1(sim.t, Cpred, tWeek, 'linear', 'extrap');
MwPred = interp1(sim.t, Mpred, tWeek, 'linear', 'extrap');
m.weeklyR2cases = r2(Cw, CwPred);
m.weeklyR2deaths = r2(Mw, MwPred);
m.weeklyRMSEcases = rmse(Cw, CwPred);
m.weeklyRMSEdeaths = rmse(Mw, MwPred);
m.CwPred = CwPred;
m.MwPred = MwPred;

m.holdoutR2cases = r2(data.holdout.cases, Cpred(idxHold));
m.holdoutR2deaths = r2(data.holdout.deaths, Mpred(idxHold));
m.holdoutRMSEcases = rmse(data.holdout.cases, Cpred(idxHold));
m.holdoutRMSEdeaths = rmse(data.holdout.deaths, Mpred(idxHold));
m.holdoutMAPEcases = 100 * mean(abs(Cpred(idxHold) - ...
    data.holdout.cases) ./ data.holdout.cases);
m.holdoutMAPEdeaths = 100 * mean(abs(Mpred(idxHold) - ...
    data.holdout.deaths) ./ data.holdout.deaths);
m.holdoutMaxRelCases = 100 * max(abs(Cpred(idxHold) - ...
    data.holdout.cases) ./ data.holdout.cases);
m.holdoutMaxRelDeaths = 100 * max(abs(Mpred(idxHold) - ...
    data.holdout.deaths) ./ data.holdout.deaths);

m.CFRmodel = (Mpred(nFit) - M0) / (Cpred(nFit) - C0);
m.CFRobs = (Mobs(end) - M0) / (Cobs(end) - C0);

[R0, Rc, Rh, Rf] = r0_daily(p, p.betaC0);
m.R0 = R0;
m.Rc = Rc;
m.Rh = Rh;
m.Rf = Rf;
betaLate = p.betaC0 * (1 - p.u1) * (1 - p.u2);
[R0late, RcLate, RhLate, RfLate] = r0_daily(p, betaLate);
m.R0late = R0late;
m.RcLate = RcLate;
m.RhLate = RhLate;
m.RfLate = RfLate;

n = numel(Cobs) + numel(Mobs);
sse = sum((log(Cpred(idxFit)) - log(Cobs)).^2) + ...
    sum((log(Mpred(idxFit)) - log(Mobs)).^2);
k = 6;
m.AIC = n * log(sse / n) + 2 * k;
m.BIC = n * log(sse / n) + k * log(n);

m.params = table( ...
    ["betaC0"; "u1"; "u2"; "alpha0"; "mu"; "rhoRep"; ...
     "sigma"; "gamma"; "gammaQ"; "nu"; "rhoH0"; "rhoF0"; "rhoM"], ...
    [p.betaC0; p.u1; p.u2; p.alpha; p.mu; p.rhoRep; ...
     p.sigma; p.gamma; p.gammaQ; p.nu; p.rhoH0; p.rhoF0; p.rhoM], ...
    ["day^-1"; "-"; "-"; "day^-1"; "day^-1"; "-"; ...
     "day^-1"; "day^-1"; "day^-1"; "day^-1"; "-"; "-"; "-"], ...
    'VariableNames', {'parameter', 'estimate', 'unit'});
end

function v = r2(obs, model)
ssRes = sum((obs - model).^2);
ssTot = sum((obs - mean(obs)).^2);
if ssTot == 0
    v = NaN;
else
    v = 1 - ssRes / ssTot;
end
end

function v = rmse(obs, model)
v = sqrt(mean((obs - model).^2));
end

function s = set_default(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
