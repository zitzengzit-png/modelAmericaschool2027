function boot = p2_bootstrap(data, cfg, fitBase, opts)
%P2_BOOTSTRAP  Moving-block bootstrap for the daily SEIQRD fit.
%
%   boot = p2_bootstrap(data, cfg, fitBase, opts)
%
%   opts.nBoot          number of replicates (100)
%   opts.blockLen       block length in days (7 or 14)
%   opts.seed           RNG seed
%   opts.nStarts        starts per replicate (1, warm start)
%   opts.maxFunEvals    (300)
%   opts.maxIter        (250)
%   opts.maxCostFactor  reject a replicate above this multiple of the
%                       baseline cost (3.0)
%   opts.verbose        print progress (true)
%
%   Residuals are the daily log residuals of the baseline fit. Blocks of
%   length blockLen are drawn with replacement and the same block indices are
%   used for cases and deaths, preserving their cross-correlation. Pseudo
%   observations are made monotone and cases are kept >= deaths. The initial
%   state is held fixed (conditional bootstrap).

if nargin < 4 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'nBoot', 100);
opts = set_default(opts, 'blockLen', 7);
opts = set_default(opts, 'seed', 20261111);
opts = set_default(opts, 'nStarts', 1);
opts = set_default(opts, 'maxFunEvals', 300);
opts = set_default(opts, 'maxIter', 250);
opts = set_default(opts, 'maxCostFactor', 3.0);
opts = set_default(opts, 'verbose', true);

nFit = numel(data.t);
if isfield(fitBase, 'resid')
    rC = fitBase.resid.logC;
    rM = fitBase.resid.logM;
else
    rC = log(data.cases) - log(fitBase.Cpred(1:nFit));
    rM = log(data.deaths) - log(fitBase.Mpred(1:nFit));
end
rC = rC(:);
rM = rM(:);
rC(1) = 0;
rM(1) = 0;
poolC = rC(2:end);
poolM = rM(2:end);
nRes = numel(poolC);
if opts.blockLen < 1 || opts.blockLen > nRes
    error('p2_bootstrap:badBlock', ...
        'blockLen must be between 1 and %d.', nRes);
end

rng(opts.seed, 'twister');
P = numel(fitBase.paramNames);
Q = nan(opts.nBoot, P);
costs = nan(opts.nBoot, 1);
success = false(opts.nBoot, 1);
Cstore = nan(numel(data.daily.date), opts.nBoot);
Mstore = nan(numel(data.daily.date), opts.nBoot);
derivedNames = {'R0', 'Rc', 'Rh', 'Rf', 'R0late', 'RcLate', ...
    'RhLate', 'RfLate', 'CFRmodel', 'betaCLate', ...
    'holdoutMAPEcases', 'holdoutMAPEdeaths'};
D = nan(opts.nBoot, numel(derivedNames));
baselineDerived = derived_from_fit(fitBase);

nBlocks = ceil(nRes / opts.blockLen);
tWeek = days(data.seriesWeekly.weekEnd(:) - cfg.dayZero);

for b = 1:opts.nBoot
    starts = randi(nRes - opts.blockLen + 1, nBlocks, 1);
    idx = zeros(nBlocks * opts.blockLen, 1);
    for j = 1:nBlocks
        idx((j - 1) * opts.blockLen + (1:opts.blockLen)) = ...
            (starts(j):starts(j) + opts.blockLen - 1)';
    end
    idx = idx(1:nRes);

    logC = log(fitBase.Cpred(1:nFit));
    logM = log(fitBase.Mpred(1:nFit));
    logC(2:end) = logC(2:end) + poolC(idx);
    logM(2:end) = logM(2:end) + poolM(idx);

    Cb = exp(logC);
    Mb = exp(logM);
    Cb(1) = data.cases(1);
    Mb(1) = data.deaths(1);
    Cb = cummax(Cb);
    Mb = cummax(Mb);
    Cb = max(Cb, Mb);

    dataB = data;
    dataB.cases = Cb;
    dataB.deaths = Mb;
    CwB = interp1(data.t, Cb, tWeek, 'linear');
    MwB = interp1(data.t, Mb, tWeek, 'linear');
    okWeek = isfinite(CwB) & isfinite(MwB);
    dataB.seriesWeekly.cases(okWeek) = CwB(okWeek);
    dataB.seriesWeekly.deaths(okWeek) = MwB(okWeek);

    o = p2_opts_from_fit(fitBase, ...
        'nStarts', opts.nStarts, ...
        'maxFunEvals', opts.maxFunEvals, ...
        'maxIter', opts.maxIter, ...
        'functionTolerance', 1e-6, ...
        'stepTolerance', 1e-6, ...
        'verbose', false);
    try
        fitB = fit_daily_seiqrd_core(dataB, cfg, o);
        Q(b, :) = fitB.qFull;
        costs(b) = fitB.cost;
        success(b) = fitB.success;
        Cstore(:, b) = fitB.Cpred;
        Mstore(:, b) = fitB.Mpred;
        D(b, :) = derived_from_fit(fitB);
    catch err
        if opts.verbose
            fprintf('  bootstrap %3d failed: %s\n', b, err.message);
        end
    end

    if opts.verbose && (mod(b, 10) == 0 || b == opts.nBoot)
        fprintf('  block %2d: %3d/%3d done, valid %d\n', ...
            opts.blockLen, b, opts.nBoot, nnz(isfinite(costs)));
    end
end

valid = isfinite(costs) & costs <= opts.maxCostFactor * fitBase.cost & ...
    all(isfinite(Q), 2);

boot = struct();
boot.blockLen = opts.blockLen;
boot.nBoot = opts.nBoot;
boot.seed = opts.seed;
boot.q = Q;
boot.costs = costs;
boot.success = success;
boot.valid = valid;
boot.derived = D;
boot.derivedNames = derivedNames;
boot.baselineDerived = baselineDerived;
boot.summaryParams = p2_summary_table(fitBase.paramNames, ...
    Q(valid, :), fitBase.qFull);
boot.summaryDerived = p2_summary_table(derivedNames, ...
    D(valid, :), baselineDerived);

runs = table((1:opts.nBoot)', repmat(opts.blockLen, opts.nBoot, 1), ...
    costs, success, valid, ...
    'VariableNames', {'replicate', 'blockLen', 'cost', 'success', 'valid'});
runs = [runs, array2table(Q, 'VariableNames', ...
    matlab.lang.makeValidName(fitBase.paramNames))];
boot.runs = runs;

if any(valid)
    Cq = quantile_rows(Cstore(:, valid), [0.025 0.5 0.975]);
    Mq = quantile_rows(Mstore(:, valid), [0.025 0.5 0.975]);
else
    Cq = nan(numel(data.daily.date), 3);
    Mq = nan(numel(data.daily.date), 3);
end
boot.pred = table(data.daily.date, data.daily.cases, fitBase.Cpred, ...
    Cq(:, 1), Cq(:, 2), Cq(:, 3), ...
    data.daily.deaths, fitBase.Mpred, Mq(:, 1), Mq(:, 2), Mq(:, 3), ...
    'VariableNames', {'date', 'cases_obs', 'cases_base', ...
    'cases_p2_5', 'cases_p50', 'cases_p97_5', ...
    'deaths_obs', 'deaths_base', 'deaths_p2_5', 'deaths_p50', ...
    'deaths_p97_5'});
end

% -------------------------------------------------------------------------
function d = derived_from_fit(fit)
m = fit.metrics;
d = [m.R0, m.Rc, m.Rh, m.Rf, m.R0late, m.RcLate, m.RhLate, ...
    m.RfLate, m.CFRmodel, m.betaCLate, ...
    m.holdoutMAPEcases, m.holdoutMAPEdeaths];
end

function Q = quantile_rows(X, probs)
n = size(X, 1);
Q = nan(n, numel(probs));
for i = 1:n
    x = X(i, :);
    x = x(isfinite(x));
    if isempty(x)
        continue;
    end
    for j = 1:numel(probs)
        Q(i, j) = local_quantile(x, probs(j));
    end
end
end

function q = local_quantile(x, p)
x = sort(x(:));
n = numel(x);
if n == 1
    q = x;
    return;
end
pos = 1 + (n - 1) * p;
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    q = x(lo);
else
    q = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
end

function s = set_default(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end

