function prof = p2_profile(data, cfg, fitBase, paramName, grid, opts)
%P2_PROFILE  Profile likelihood for one parameter of the daily fit.
%
%   prof = p2_profile(data, cfg, fitBase, paramName, grid, opts)
%
%   The parameter is fixed at each grid value and all other free parameters
%   are re-estimated. The 95% interval uses the daily log-residual SSE and a
%   chi-square(1) threshold with residual variance s2 = SSE_min/(n-k).
%
%   opts.nStarts        starts per grid point (2)
%   opts.maxFunEvals    (300)
%   opts.maxIter        (250)
%   opts.verbose        (true)

if nargin < 6 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'nStarts', 2);
opts = set_default(opts, 'maxFunEvals', 300);
opts = set_default(opts, 'maxIter', 250);
opts = set_default(opts, 'verbose', true);

paramName = char(paramName);
if ~ismember(paramName, fitBase.paramNames)
    error('p2_profile:unknownParam', ...
        '%s is not in fitBase.paramNames.', paramName);
end
grid = grid(:);
P = numel(fitBase.paramNames);

prof = struct();
prof.paramName = paramName;
prof.grid = grid;
prof.sseDaily = nan(numel(grid), 1);
prof.cost = nan(numel(grid), 1);
prof.qFull = nan(numel(grid), P);
prof.success = false(numel(grid), 1);

qPrev = fitBase.qFull;
jFix = find(strcmp(fitBase.paramNames, paramName), 1);

for i = 1:numel(grid)
    fixed = fitBase.fixedParams;
    fixed.(paramName) = grid(i);
    o = p2_opts_from_fit(fitBase, ...
        'fixedParams', fixed, ...
        'q0', qPrev, ...
        'nStarts', opts.nStarts, ...
        'maxFunEvals', opts.maxFunEvals, ...
        'maxIter', opts.maxIter, ...
        'functionTolerance', 1e-6, ...
        'stepTolerance', 1e-6, ...
        'verbose', false);
    try
        fitI = fit_daily_seiqrd_core(data, cfg, o);
        prof.sseDaily(i) = fitI.metrics.sseDaily;
        prof.cost(i) = fitI.cost;
        prof.qFull(i, :) = fitI.qFull;
        prof.success(i) = fitI.success;
        qPrev = fitI.qFull;
        qPrev(jFix) = grid(i);
    catch err
        if opts.verbose
            fprintf('  profile %s = %.4f failed: %s\n', ...
                paramName, grid(i), err.message);
        end
    end
    if opts.verbose
        fprintf('  profile %-7s = %8.4f, dSSE = %10.4g\n', ...
            paramName, grid(i), prof.sseDaily(i));
    end
end

sse = prof.sseDaily;
if all(~isfinite(sse))
    prof.sseMin = NaN;
    prof.threshold = NaN;
    prof.ciLow = NaN;
    prof.ciHigh = NaN;
    prof.censoredLow = true;
    prof.censoredHigh = true;
    prof.table = table(grid, sse, nan(size(grid)), prof.cost, ...
        prof.success, 'VariableNames', {'value', 'sse_daily', ...
        'delta_sse', 'cost', 'success'});
    return;
end

[sseMin, imin] = min(sse);
nObs = fitBase.metrics.nAIC;
k = numel(fitBase.freeNames);
s2 = sseMin / max(nObs - k, 1);
threshold = sseMin + 3.841458820694124 * s2;
inCI = isfinite(sse) & sse <= threshold;

prof.sseMin = sseMin;
prof.threshold = threshold;
prof.sseVariance = s2;
prof.inCI = inCI;

lo = imin;
while lo > 1 && inCI(lo - 1)
    lo = lo - 1;
end
hi = imin;
while hi < numel(inCI) && inCI(hi + 1)
    hi = hi + 1;
end
if lo > 1
    prof.ciLow = grid(lo);
    prof.censoredLow = false;
else
    prof.ciLow = -Inf;
    prof.censoredLow = true;
end
if hi < numel(inCI)
    prof.ciHigh = grid(hi);
    prof.censoredHigh = false;
else
    prof.ciHigh = Inf;
    prof.censoredHigh = true;
end

prof.table = table(grid, sse, sse - sseMin, prof.cost, prof.success, ...
    'VariableNames', {'value', 'sse_daily', 'delta_sse', 'cost', 'success'});
end

function s = set_default(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
