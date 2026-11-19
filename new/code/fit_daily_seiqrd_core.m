function fit = fit_daily_seiqrd_core(data, cfg, opts)
%FIT_DAILY_SEIQRD_CORE  Generalized daily three-route SEIQRD fit.
%
%   fit = fit_daily_seiqrd_core(data, cfg)
%   fit = fit_daily_seiqrd_core(data, cfg, opts)
%
%   Default parameter vector (P1 baseline):
%       q = [betaC0, u1, u2, alpha0, mu, rhoRep]
%
%   Model:
%       dS/dt = -S/N*(betaC*I + betaH*Q + betaF*D)
%       betaH = rhoH0*betaC,  betaF = rhoF0*betaC
%       betaC(t) = betaC0 * prod_i (1 - u_i * 1(t >= knot_i))
%
%   Options (default in parentheses):
%     paramNames        ({'betaC0','u1','u2','alpha0','mu','rhoRep'})
%     fixedParams       (struct(); e.g. struct('rhoRep',1))
%     knots             (cfg.betaKnots; pass 3 knots for the P2 comparison)
%     lb, ub            (full paramNames bounds; default by parameter name)
%     q0, q0List        (full paramNames warm starts; prepended to defaults)
%     nStarts           (3)
%     fixRhoRep         (false; shortcut for fixedParams.rhoRep = 1)
%     allowRebound      (true; u2/u3 lower bound -0.50, u1 always >= 0)
%     E0Scale, D0Scale  (1, 1; initial-condition sensitivity)
%     maxFunEvals       (600)
%     maxIter           (400)
%     functionTolerance (1e-8)
%     stepTolerance     (1e-8)
%     useWeekly         (true)
%     useCFR            (true)
%     usePriors         (true)
%     verbose           (true)
%
%   The residual vector is the same P1 objective: daily log cumulative
%   residuals, weekly log residuals, a CFR soft constraint and weak priors.
%   AIC/BIC are computed from the daily log residuals only, with k equal to
%   the number of FREE parameters.

if nargin < 3 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'paramNames', {'betaC0','u1','u2','alpha0','mu','rhoRep'});
opts = set_default(opts, 'fixedParams', struct());
opts = set_default(opts, 'knots', []);
opts = set_default(opts, 'lb', []);
opts = set_default(opts, 'ub', []);
opts = set_default(opts, 'q0', []);
opts = set_default(opts, 'q0List', []);
opts = set_default(opts, 'nStarts', 3);
opts = set_default(opts, 'fixRhoRep', false);
opts = set_default(opts, 'allowRebound', true);
opts = set_default(opts, 'E0Scale', 1);
opts = set_default(opts, 'D0Scale', 1);
opts = set_default(opts, 'maxFunEvals', 600);
opts = set_default(opts, 'maxIter', 400);
opts = set_default(opts, 'functionTolerance', 1e-8);
opts = set_default(opts, 'stepTolerance', 1e-8);
opts = set_default(opts, 'useWeekly', true);
opts = set_default(opts, 'useCFR', true);
opts = set_default(opts, 'usePriors', true);
opts = set_default(opts, 'verbose', true);

paramNames = cellstr(string(opts.paramNames));
paramNames = paramNames(:)';
validate_param_names(paramNames);

uNames = paramNames(~cellfun(@isempty, regexp(paramNames, '^u\d+$', 'once')));
if isempty(uNames)
    error('fit_daily_seiqrd_core:noU', 'At least one u_i parameter is required.');
end
uNums = cellfun(@(s) str2double(s(2:end)), uNames);
if any(diff(uNums) <= 0)
    error('fit_daily_seiqrd_core:uOrder', 'u parameters must be in ascending order.');
end

if isempty(opts.knots)
    knots = days(cfg.betaKnots(:) - cfg.dayZero)';
elseif isdatetime(opts.knots)
    knots = days(opts.knots(:) - cfg.dayZero)';
else
    knots = double(opts.knots(:))';
end
knots = sort(knots);
if numel(knots) ~= numel(uNames)
    error('fit_daily_seiqrd_core:knotMismatch', ...
        '%d knots given for %d u parameters.', numel(knots), numel(uNames));
end

p0 = daily_params(cfg, data);
p0.knots = knots(:);
p0.uVec = ones(numel(knots), 1);   % overwritten by apply_q_full

fixedParams = opts.fixedParams;
if opts.fixRhoRep
    fixedParams.rhoRep = 1.0;
end
fixedNames = fieldnames(fixedParams);
for i = 1:numel(fixedNames)
    if ~ismember(fixedNames{i}, paramNames)
        error('fit_daily_seiqrd_core:unknownFixed', ...
            'fixedParams.%s is not in paramNames.', fixedNames{i});
    end
end
freeIdx = find(~ismember(paramNames, fixedNames));
freeNames = paramNames(freeIdx);
if isempty(freeIdx)
    error('fit_daily_seiqrd_core:noFree', 'All parameters are fixed.');
end

[lbFull, ubFull] = default_bounds(paramNames, opts.allowRebound);
if ~isempty(opts.lb)
    if numel(opts.lb) ~= numel(paramNames)
        error('fit_daily_seiqrd_core:lbSize', 'opts.lb must match paramNames.');
    end
    lbFull = double(opts.lb(:))';
end
if ~isempty(opts.ub)
    if numel(opts.ub) ~= numel(paramNames)
        error('fit_daily_seiqrd_core:ubSize', 'opts.ub must match paramNames.');
    end
    ubFull = double(opts.ub(:))';
end
if any(lbFull > ubFull)
    error('fit_daily_seiqrd_core:badBounds', 'lb must be <= ub.');
end

q0FullList = default_q0_list(paramNames);
if ~isempty(opts.q0List)
    q0FullList = double(opts.q0List);
    if isvector(q0FullList)
        q0FullList = q0FullList(:)';
    end
    if size(q0FullList, 2) ~= numel(paramNames)
        error('fit_daily_seiqrd_core:q0ListSize', ...
            'opts.q0List must have one column per paramName.');
    end
end
if ~isempty(opts.q0)
    q0 = double(opts.q0(:))';
    if numel(q0) ~= numel(paramNames)
        error('fit_daily_seiqrd_core:q0Size', ...
            'opts.q0 must have one entry per paramName.');
    end
    q0FullList = [q0; q0FullList];
end
for i = 1:numel(fixedNames)
    j = find(strcmp(paramNames, fixedNames{i}), 1);
    q0FullList(:, j) = fixedParams.(fixedNames{i});
end
q0Free = q0FullList(:, freeIdx);
q0Free = min(max(q0Free, lbFull(freeIdx)), ubFull(freeIdx));
q0Free = unique(q0Free, 'rows', 'stable');
opts.nStarts = min(opts.nStarts, size(q0Free, 1));
if opts.nStarts < 1
    error('fit_daily_seiqrd_core:noStart', 'No valid starting point.');
end
q0Free = q0Free(1:opts.nStarts, :);
lb = lbFull(freeIdx);
ub = ubFull(freeIdx);

% Initial state at 2026-06-21 (first-week warm start).
[y0, initInfo] = daily_initial_state(data, cfg, p0);
[y0, initInfo] = scale_initial_state(y0, initInfo, data.N, ...
    opts.E0Scale, opts.D0Scale);

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
nFit = numel(tFit);

ctx = struct();
ctx.data = data;
ctx.cfg = cfg;
ctx.p0 = p0;
ctx.y0 = y0;
ctx.tAll = tAll;
ctx.tFit = tFit;
ctx.Cobs = Cobs;
ctx.Mobs = Mobs;
ctx.C0 = C0;
ctx.M0 = M0;
ctx.tWeek = tWeek;
ctx.Cw = Cw;
ctx.Mw = Mw;
ctx.idxWeek = idxWeek;
ctx.paramNames = paramNames;
ctx.fixedParams = fixedParams;
ctx.freeIdx = freeIdx;
ctx.freeNames = freeNames;
ctx.opts = opts;

nRes = 2 * nFit;
if opts.useWeekly
    nRes = nRes + 2 * nnz(idxWeek);
end
if opts.useCFR
    nRes = nRes + 1;
end
if opts.usePriors
    if any(strcmp(freeNames, 'alpha0'))
        nRes = nRes + 1;
    end
    if any(strcmp(freeNames, 'mu'))
        nRes = nRes + 1;
    end
    if any(strcmp(freeNames, 'rhoRep'))
        nRes = nRes + 1;
    end
end
ctx.nRes = nRes;

lsOpts = optimoptions('lsqnonlin', ...
    'Display', 'off', ...
    'MaxFunctionEvaluations', opts.maxFunEvals, ...
    'MaxIterations', opts.maxIter, ...
    'FunctionTolerance', opts.functionTolerance, ...
    'StepTolerance', opts.stepTolerance);

bestCost = inf;
bestQ = [];
bestExit = 0;

for k = 1:size(q0Free, 1)
    obj = @(q) residuals(q, ctx);
    try
        [qfit, resnorm, ~, exitflag] = lsqnonlin( ...
            obj, q0Free(k, :), lb, ub, lsOpts);
    catch err
        if opts.verbose
            fprintf('  start %d failed: %s\n', k, err.message);
        end
        continue;
    end
    if opts.verbose
        fprintf('  start %d: cost %.6g\n', k, resnorm);
        for j = 1:numel(freeNames)
            fprintf('    %-8s %.6f\n', freeNames{j}, qfit(j));
        end
    end
    if resnorm < bestCost
        bestCost = resnorm;
        bestQ = qfit;
        bestExit = exitflag;
    end
end

if isempty(bestQ)
    error('fit_daily_seiqrd_core:allFailed', 'All least-squares starts failed.');
end

qFullBest = full_from_free(bestQ, paramNames, fixedParams, freeIdx);
p = apply_q_full(p0, paramNames, qFullBest);
betaFun = make_beta_fun_multi(p.betaC0, p.uVec, p.knots);
sim = simulate_daily_seiqrd(p, tAll, y0, betaFun);
[Cpred, Mpred] = observation_curve(sim, C0, M0, p.rhoRep, p.rhoM);
metrics = compute_metrics(data, p, sim, Cpred, Mpred, C0, M0, ...
    tFit, Cobs, Mobs, tWeek, Cw, Mw, betaFun, freeNames, ...
    qFullBest, paramNames);

fit = struct();
fit.params = p;
fit.q = bestQ;
fit.qFull = qFullBest;
fit.paramNames = paramNames;
fit.freeNames = freeNames;
fit.fixedParams = fixedParams;
fit.freeIdx = freeIdx;
fit.lb = lbFull;
fit.ub = ubFull;
fit.knots = knots;
fit.uVec = p.uVec;
fit.y0 = y0;
fit.init = initInfo;
fit.sim = sim;
fit.Cpred = Cpred;
fit.Mpred = Mpred;
fit.betaFun = betaFun;
fit.metrics = metrics;
fit.cost = bestCost;
fit.success = bestExit > 0;
fit.rhoRepMode = logical(opts.fixRhoRep);
fit.allowRebound = logical(opts.allowRebound);
fit.resid = struct( ...
    'logC', log(Cpred(1:numel(tFit))) - log(Cobs), ...
    'logM', log(Mpred(1:numel(tFit))) - log(Mobs));
end


% -------------------------------------------------------------------------
% Objective and parameter mapping
% -------------------------------------------------------------------------
function res = residuals(qFree, ctx)
qFull = full_from_free(qFree, ctx.paramNames, ...
    ctx.fixedParams, ctx.freeIdx);
p = apply_q_full(ctx.p0, ctx.paramNames, qFull);
betaFun = make_beta_fun_multi(p.betaC0, p.uVec, p.knots);

nFit = numel(ctx.tFit);
nFail = ctx.nRes;
try
    sim = simulate_daily_seiqrd(p, ctx.tAll, ctx.y0, betaFun);
catch
    res = 1e6 * ones(nFail, 1);
    return;
end
if any(~isfinite(sim.C)) || any(~isfinite(sim.M)) || ...
        any(sim.C <= 0) || any(sim.M <= 0)
    res = 1e6 * ones(nFail, 1);
    return;
end

[Cpred, Mpred] = observation_curve(sim, ctx.C0, ctx.M0, ...
    p.rhoRep, p.rhoM);
rC = log(Cpred(1:nFit)) - log(ctx.Cobs);
rM = ctx.cfg.fitWeights.mu * (log(Mpred(1:nFit)) - log(ctx.Mobs));
res = [rC; rM];

if ctx.opts.useWeekly
    CwPred = interp1(ctx.tAll, Cpred, ctx.tWeek, 'linear', 'extrap');
    MwPred = interp1(ctx.tAll, Mpred, ctx.tWeek, 'linear', 'extrap');
    rCw = ctx.cfg.fitWeights.weekly * ...
        (log(CwPred(ctx.idxWeek)) - log(ctx.Cw(ctx.idxWeek)));
    rMw = ctx.cfg.fitWeights.weekly * ctx.cfg.fitWeights.mu * ...
        (log(MwPred(ctx.idxWeek)) - log(ctx.Mw(ctx.idxWeek)));
    res = [res; rCw; rMw];
end

if ctx.opts.useCFR
    cfrModel = (Mpred(nFit) - ctx.M0) / (Cpred(nFit) - ctx.C0);
    cfrObs = (ctx.Mobs(end) - ctx.M0) / (ctx.Cobs(end) - ctx.C0);
    res = [res; ctx.cfg.fitWeights.cfr * (cfrModel - cfrObs)];
end

if ctx.opts.usePriors
    if any(strcmp(ctx.freeNames, 'alpha0'))
        ia = find(strcmp(ctx.paramNames, 'alpha0'), 1);
        res = [res; ctx.cfg.fitWeights.alpha * ...
            log(qFull(ia) / ctx.cfg.alphaPrior)];
    end
    if any(strcmp(ctx.freeNames, 'mu'))
        im = find(strcmp(ctx.paramNames, 'mu'), 1);
        res = [res; ctx.cfg.fitWeights.muPrior * ...
            log(qFull(im) / ctx.cfg.muPrior)];
    end
    if any(strcmp(ctx.freeNames, 'rhoRep'))
        ir = find(strcmp(ctx.paramNames, 'rhoRep'), 1);
        res = [res; ctx.cfg.fitWeights.rho * ...
            ((qFull(ir) - 0.70) / 0.20)];
    end
end
end

function qFull = full_from_free(qFree, paramNames, fixedParams, freeIdx)
qFull = zeros(1, numel(paramNames));
qFull(freeIdx) = qFree(:)';
fixedNames = fieldnames(fixedParams);
for i = 1:numel(fixedNames)
    j = find(strcmp(paramNames, fixedNames{i}), 1);
    qFull(j) = fixedParams.(fixedNames{i});
end
end

function p = apply_q_full(p0, paramNames, qFull)
p = p0;
uNames = paramNames(~cellfun(@isempty, regexp(paramNames, '^u\d+$', 'once')));
uVec = zeros(numel(p.knots), 1);
for i = 1:numel(uNames)
    uVec(i) = qFull(strcmp(paramNames, uNames{i}));
end
p.uVec = uVec;
for i = 1:numel(paramNames)
    switch paramNames{i}
        case 'betaC0'
            p.betaC0 = qFull(i);
        case {'alpha0', 'alpha'}
            p.alpha = qFull(i);
        case 'mu'
            p.mu = qFull(i);
            p.muQ = qFull(i);
        case 'rhoRep'
            p.rhoRep = qFull(i);
        otherwise
            if isempty(regexp(paramNames{i}, '^u\d+$', 'once'))
                error('fit_daily_seiqrd_core:unknownParam', ...
                    'Unknown parameter %s.', paramNames{i});
            end
    end
end
for i = 1:numel(uVec)
    p.(sprintf('u%d', i)) = uVec(i);
end
end

function [Cpred, Mpred] = observation_curve(sim, C0, M0, rhoRep, rhoM)
Cpred = C0 + rhoRep * (sim.C - sim.C(1));
Mpred = M0 + rhoM * (sim.M - sim.M(1));
end


% -------------------------------------------------------------------------
% Metrics, bounds and defaults
% -------------------------------------------------------------------------
function m = compute_metrics(data, p, sim, Cpred, Mpred, C0, M0, ...
    tFit, Cobs, Mobs, tWeek, Cw, Mw, betaFun, freeNames, ...
    qFull, paramNames)

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

betaEarly = betaFun(0);
betaLate = betaFun(tFit(end));
[R0, Rc, Rh, Rf] = r0_daily(p, betaEarly);
m.R0 = R0; m.Rc = Rc; m.Rh = Rh; m.Rf = Rf;
[R0late, RcLate, RhLate, RfLate] = r0_daily(p, betaLate);
m.R0late = R0late;
m.RcLate = RcLate;
m.RhLate = RhLate;
m.RfLate = RfLate;
m.betaCEarly = betaEarly;
m.betaCLate = betaLate;

rC = log(Cpred(idxFit)) - log(Cobs);
rM = log(Mpred(idxFit)) - log(Mobs);
sseDaily = sum(rC.^2) + sum(rM.^2);
nAIC = numel(Cobs) + numel(Mobs);
kAIC = numel(freeNames);
m.sseDaily = sseDaily;
m.nAIC = nAIC;
m.kAIC = kAIC;
m.AIC = nAIC * log(sseDaily / nAIC) + 2 * kAIC;
m.BIC = nAIC * log(sseDaily / nAIC) + kAIC * log(nAIC);

units = cell(numel(paramNames), 1);
for i = 1:numel(paramNames)
    switch paramNames{i}
        case {'betaC0', 'alpha0', 'alpha', 'mu'}
            units{i} = 'day^-1';
        otherwise
            units{i} = '-';
    end
end
namesOut = [paramNames(:); {'sigma'; 'gamma'; 'gammaQ'; 'nu'; ...
    'rhoH0'; 'rhoF0'; 'rhoM'}];
valuesOut = [qFull(:); p.sigma; p.gamma; p.gammaQ; p.nu; ...
    p.rhoH0; p.rhoF0; p.rhoM];
unitsOut = [units; {'day^-1'; 'day^-1'; 'day^-1'; 'day^-1'; ...
    '-'; '-'; '-'}];
m.params = table(namesOut, valuesOut, unitsOut, ...
    'VariableNames', {'parameter', 'estimate', 'unit'});
end

function [lb, ub] = default_bounds(names, allowRebound)
n = numel(names);
lb = zeros(1, n);
ub = zeros(1, n);
for i = 1:n
    switch names{i}
        case 'betaC0'
            lb(i) = 0.03; ub(i) = 0.60;
        case {'alpha0', 'alpha'}
            lb(i) = 0.03; ub(i) = 0.60;
        case 'mu'
            lb(i) = 0.010; ub(i) = 0.090;
        case 'rhoRep'
            lb(i) = 0.50; ub(i) = 0.90;
        otherwise
            if isempty(regexp(names{i}, '^u\d+$', 'once'))
                error('fit_daily_seiqrd_core:unknownParam', ...
                    'No default bounds for %s.', names{i});
            end
            ub(i) = 0.95;
            if strcmp(names{i}, 'u1') || ~allowRebound
                lb(i) = 0.0;
            else
                lb(i) = -0.50;
            end
    end
end
end

function q0 = default_q0_list(paramNames)
allNames = {'betaC0', 'u1', 'u2', 'u3', 'alpha0', 'mu', 'rhoRep'};
allQ = [0.20, 0.30, 0.10, 0.05, 0.15, 0.032, 0.70;
        0.15, 0.20, 0.20, 0.10, 0.20, 0.036, 0.60;
        0.25, 0.40, 0.05, 0.00, 0.12, 0.028, 0.80;
        0.12, 0.10, 0.30, 0.10, 0.25, 0.040, 0.70;
        0.30, 0.50, 0.10, 0.05, 0.10, 0.025, 0.75;
        0.18, 0.35, 0.25, 0.08, 0.18, 0.030, 0.65;
        0.22, 0.45, -0.20, 0.06, 0.22, 0.038, 0.85;
        0.14, 0.25, -0.50, 0.03, 0.35, 0.034, 0.75];
q0 = zeros(size(allQ, 1), numel(paramNames));
for i = 1:numel(paramNames)
    name = paramNames{i};
    if strcmp(name, 'alpha')
        name = 'alpha0';
    end
    j = find(strcmp(allNames, name), 1);
    if isempty(j)
        error('fit_daily_seiqrd_core:noDefaultStart', ...
            'No default starting value for %s.', paramNames{i});
    end
    q0(:, i) = allQ(:, j);
end
end

function validate_param_names(names)
allowed = {'betaC0', 'u1', 'u2', 'u3', 'u4', 'alpha0', 'alpha', ...
    'mu', 'rhoRep'};
for i = 1:numel(names)
    if ~ismember(names{i}, allowed)
        error('fit_daily_seiqrd_core:unknownParam', ...
            'Unknown parameter %s.', names{i});
    end
end
if numel(unique(names)) ~= numel(names)
    error('fit_daily_seiqrd_core:duplicateParam', ...
        'paramNames contains duplicates.');
end
end

function [y0, info] = scale_initial_state(y0, info, N, E0Scale, D0Scale)
y0 = y0(:);
y0(2) = y0(2) * E0Scale;
y0(6) = y0(6) * D0Scale;
y0(1) = N - sum(y0(2:7));
if y0(1) <= 0
    error('fit_daily_seiqrd_core:negativeS', ...
        'Scaled initial S is %.1f; check E0Scale/D0Scale.', y0(1));
end
info.E0Scale = E0Scale;
info.D0Scale = D0Scale;
info.E0 = y0(2);
info.D0 = y0(6);
info.S0 = y0(1);
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

