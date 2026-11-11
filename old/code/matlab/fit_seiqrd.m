function fit = fit_seiqrd(data, p0, tauGrid, nStarts)
%FIT_SEIQRD  Weighted least-squares fit of beta0, beta1, alpha and mu.
%   A two-phase beta with change point tau (W26--W38) is searched on a grid.
%   fit_seiqrd(data, p0, tauGrid, nStarts) optionally restricts the tau grid
%   and the number of starting points (useful for a fast refit).

if nargin < 2 || isempty(p0)
    p0 = default_params(data);
end
if nargin < 3 || isempty(tauGrid)
    tauGrid = (1:13)';
end
if nargin < 4 || isempty(nStarts)
    nStarts = 3;
end
if exist('lsqnonlin', 'file') ~= 2
    error('fit_seiqrd requires the Optimization Toolbox (lsqnonlin).');
end

lb = [0.05, 0.05, 0.50, 0.05];
ub = [3.00, 3.00, 3.50, 0.50];
q0List = [1.298, 0.847, 1.244, 0.235;
          0.900, 0.500, 1.500, 0.220;
          0.600, 0.350, 1.000, 0.210];
nStarts = min(nStarts, size(q0List, 1));

opts = optimoptions('lsqnonlin', 'Display', 'off', ...
    'MaxFunctionEvaluations', 2000, 'MaxIterations', 1200);

bestCost = inf;
bestQ = [];
bestTau = NaN;
bestFlag = false;

for tau = tauGrid'
    for k = 1:nStarts
        obj = @(q) residuals(q, tau, data, p0);
        try
            [qfit, resnorm, ~, exitflag] = lsqnonlin( ...
                obj, q0List(k, :), lb, ub, opts);
        catch
            continue;
        end
        if resnorm < bestCost
            bestCost = resnorm;
            bestQ = qfit;
            bestTau = tau;
            bestFlag = exitflag > 0;
        end
    end
end

if isempty(bestQ)
    error('All least-squares starts failed.');
end

p = p0;
p.beta0 = bestQ(1);
p.beta1 = bestQ(2);
p.alpha = bestQ(3);
p.mu = bestQ(4);
p.muQ = bestQ(4);
p.tau = bestTau;

sim = simulate_seiqrd(p, data.t, data.y0);
simLong = simulate_seiqrd(p, (0:0.25:27)', data.y0);

weeklyObs = diff(data.cases);
weeklyFit = diff(sim.cases);
cfrModel = sim.deaths(end) / sim.cases(end);
cfrObs = data.deaths(end) / data.cases(end);

endSim = simulate_seiqrd(p, [0; data.endpoint_t], data.y0);
metrics = struct();
metrics.beta0 = p.beta0;
metrics.beta1 = p.beta1;
metrics.alpha = p.alpha;
metrics.mu = p.mu;
metrics.nu = p.nu;
metrics.tau = p.tau;
metrics.tauWeek = 25 + p.tau;
metrics.R0early = sim.r0Early;
metrics.R0late = sim.r0Late;
metrics.CFRmodel = cfrModel;
metrics.CFRobs = cfrObs;
metrics.R2cases = r2_score(data.cases, sim.cases);
metrics.R2deaths = r2_score(data.deaths, sim.deaths);
metrics.RMSEcases = rmse(data.cases, sim.cases);
metrics.RMSEdeaths = rmse(data.deaths, sim.deaths);
metrics.RMSEweekly = rmse(weeklyObs, weeklyFit);
[peakObs, idxObs] = max(weeklyObs);
metrics.peakWeeklyObs = peakObs;
metrics.peakWeekObs = 25 + data.t(idxObs + 1);
metrics.peakWeeklyModel = sim.peak;
metrics.peakWeekModel = sim.peakWeek;
metrics.flatWeek = first_flat_week(sim.t, sim.rt);
metrics.endpointCasesModel = endSim.cases(end);
metrics.endpointDeathsModel = endSim.deaths(end);
metrics.endpointCasesObs = data.endpoint_cases;
metrics.endpointDeathsObs = data.endpoint_deaths;
metrics.endpointCasesErrorPct = 100 * (endSim.cases(end) - data.endpoint_cases) / data.endpoint_cases;
metrics.endpointDeathsErrorPct = 100 * (endSim.deaths(end) - data.endpoint_deaths) / data.endpoint_deaths;
metrics.cost = bestCost;

fit = struct('params', p, 'tau', bestTau, 'sim', sim, ...
    'simLong', simLong, 'metrics', metrics, 'success', bestFlag);
end

function res = residuals(q, tau, data, p0)
p = p0;
p.beta0 = q(1);
p.beta1 = q(2);
p.alpha = q(3);
p.mu = q(4);
p.muQ = q(4);
p.tau = tau;
try
    sim = simulate_seiqrd(p, data.t, data.y0);
catch
    res = 1e6 * ones(4 * numel(data.t) - 1, 1);
    return;
end

cModel = sim.cases;
mModel = sim.deaths;
cObs = data.cases;
mObs = data.deaths;
rC = (cModel - cObs) ./ max(cObs, 50);
rM = (mModel - mObs) ./ max(mObs, 20);
rW = (diff(cModel) - diff(cObs)) ./ max(diff(cObs), 30);
rMw = 0.5 * (diff(mModel) - diff(mObs)) ./ max(diff(mObs), 15);
cfrObs = mObs(end) / cObs(end);
rCFR = 5 * (mModel(end) / cModel(end) - cfrObs);
res = [rC; rM; rW; rMw; rCFR];
end

function v = r2_score(obs, model)
ssRes = sum((obs - model).^2);
ssTot = sum((obs - mean(obs)).^2);
v = 1 - ssRes / ssTot;
end

function v = rmse(obs, model)
v = sqrt(mean((obs - model).^2));
end

function w = first_flat_week(t, rt)
w = NaN;
for i = 1:(numel(rt) - 2)
    if all(rt(i:i+2) < 1)
        w = 25 + t(i);
        return;
    end
end
end
