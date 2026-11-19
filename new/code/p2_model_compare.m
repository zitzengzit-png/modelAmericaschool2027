function cmp = p2_model_compare(data, cfg, fitBase, opts)
%P2_MODEL_COMPARE  Compare 2-knot, constrained 2-knot and 3-knot variants.
%
%   Baseline: 2 knots, u2 allowed negative (rebound).
%   Constrained: 2 knots, u2 >= 0 (monotone reduction).
%   3-knot: 2026-07-13, 2026-08-17, 2026-10-11 (u3 free).
%
%   AIC/BIC use the daily log-residual SSE and the number of FREE parameters.

if nargin < 4 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'nStarts', 3);
opts = set_default(opts, 'verbose', true);

% 1. Constrained two-knot model (u2 >= 0).
o2 = p2_opts_from_fit(fitBase, ...
    'allowRebound', false, ...
    'nStarts', opts.nStarts, ...
    'functionTolerance', 1e-6, ...
    'stepTolerance', 1e-6, ...
    'verbose', false);
o2.q0 = fitBase.qFull;
fitC = fit_daily_seiqrd_core(data, cfg, o2);

% 2. Three-knot model.
p3 = {'betaC0', 'u1', 'u2', 'u3', 'alpha0', 'mu', 'rhoRep'};
knots3 = days(cfg.knotDates(:) - cfg.dayZero)';
knots3 = sort(knots3);
q0_3 = zeros(1, numel(p3));
for i = 1:numel(p3)
    j = find(strcmp(fitBase.paramNames, p3{i}), 1);
    if isempty(j)
        q0_3(i) = 0.05;
    else
        q0_3(i) = fitBase.qFull(j);
    end
end
o3 = p2_opts_from_fit(fitBase, ...
    'paramNames', p3, ...
    'knots', knots3, ...
    'nStarts', opts.nStarts, ...
    'functionTolerance', 1e-6, ...
    'stepTolerance', 1e-6, ...
    'verbose', false);
o3.q0 = q0_3;
fit3 = fit_daily_seiqrd_core(data, cfg, o3);

fits = {fitBase, fitC, fit3};
models = ["2knot_rebound"; "2knot_u2_nonneg"; "3knot"];
n = numel(fits);
rows = cell(n, 1);
for i = 1:n
    f = fits{i};
    m = f.metrics;
    rows{i} = table(models(i), m.kAIC, m.nAIC, m.sseDaily, m.AIC, m.BIC, ...
        m.R2cases, m.R2deaths, m.weeklyR2cases, m.weeklyR2deaths, ...
        m.holdoutMAPEcases, m.holdoutMAPEdeaths, ...
        m.R0, m.R0late, qget(f, 'betaC0'), qget(f, 'u1'), ...
        qget(f, 'u2'), qget(f, 'u3'), f.cost, f.success, ...
        'VariableNames', {'model', 'kAIC', 'nAIC', 'sseDaily', 'AIC', ...
        'BIC', 'R2cases', 'R2deaths', 'weeklyR2cases', ...
        'weeklyR2deaths', 'holdoutMAPEcases', 'holdoutMAPEdeaths', ...
        'R0', 'R0late', 'betaC0', 'u1', 'u2', 'u3', 'cost', 'success'});
end
T = vertcat(rows{:});
T.deltaAIC = T.AIC - min(T.AIC);
T.deltaBIC = T.BIC - min(T.BIC);

Wk = data.seriesWeekly;
weekNewObs = [NaN; diff(Wk.cases)];
weekNew = [NaN; diff(fitBase.metrics.CwPred)];
weekNewC = [NaN; diff(fitC.metrics.CwPred)];
weekNew3 = [NaN; diff(fit3.metrics.CwPred)];
cmp = struct();
cmp.models = models;
cmp.table = T;
cmp.fits = fits;
cmp.weekly = table(Wk.week, Wk.weekEnd, weekNewObs, weekNew, ...
    weekNewC, weekNew3, 'VariableNames', {'week', 'week_end', ...
    'observed', 'fit_2knot', 'fit_2knot_nonneg', 'fit_3knot'});
[~, iBest] = min(T.AIC);
cmp.bestModel = T.model(iBest);
if opts.verbose
    disp(T);
end
end

function v = qget(fit, name)
j = find(strcmp(fit.paramNames, name), 1);
if isempty(j)
    v = NaN;
else
    v = fit.qFull(j);
end
end

function s = set_default(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
