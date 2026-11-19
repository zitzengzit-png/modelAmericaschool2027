function sens = p2_sensitivity(data, cfg, fitBase, opts)
%P2_SENSITIVITY  One-at-a-time sensitivity of fixed P1 assumptions.
%
%   Varies rhoH0 (0.30/0.50), rhoF0 (2.86/3.83), nu (0.35/0.70) and the
%   initial E0/D0 scales (+/-50%), refitting the five free parameters each
%   time. rhoRep stays fixed at 1, as in the P1 baseline.

if nargin < 4 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'nStarts', 1);
opts = set_default(opts, 'maxFunEvals', 400);
opts = set_default(opts, 'maxIter', 300);
opts = set_default(opts, 'verbose', true);

base = struct('rhoH0', cfg.rhoH0, 'rhoF0', cfg.rhoF0, 'nu', cfg.nu, ...
    'E0Scale', 1, 'D0Scale', 1);

scenario = {
    'baseline',      base.rhoH0, base.rhoF0, base.nu, 1.0, 1.0
    'rhoH0_low',     0.30,       base.rhoF0, base.nu, 1.0, 1.0
    'rhoH0_high',    0.50,       base.rhoF0, base.nu, 1.0, 1.0
    'rhoF0_low',     base.rhoH0, 2.86,       base.nu, 1.0, 1.0
    'rhoF0_high',    base.rhoH0, 3.83,       base.nu, 1.0, 1.0
    'nu_low',        base.rhoH0, base.rhoF0, 0.35,    1.0, 1.0
    'nu_high',       base.rhoH0, base.rhoF0, 0.70,    1.0, 1.0
    'E0_low',        base.rhoH0, base.rhoF0, base.nu, 0.5, 1.0
    'E0_high',       base.rhoH0, base.rhoF0, base.nu, 1.5, 1.0
    'D0_low',        base.rhoH0, base.rhoF0, base.nu, 1.0, 0.5
    'D0_high',       base.rhoH0, base.rhoF0, base.nu, 1.0, 1.5
};

n = size(scenario, 1);
rows = cell(n, 1);
for i = 1:n
    name = scenario{i, 1};
    cfgS = cfg;
    cfgS.rhoH0 = scenario{i, 2};
    cfgS.rhoF0 = scenario{i, 3};
    cfgS.nu = scenario{i, 4};
    e0 = scenario{i, 5};
    d0 = scenario{i, 6};

    if i == 1
        fitI = fitBase;
    else
        o = p2_opts_from_fit(fitBase, ...
            'nStarts', opts.nStarts, ...
            'maxFunEvals', opts.maxFunEvals, ...
            'maxIter', opts.maxIter, ...
            'functionTolerance', 1e-6, ...
            'stepTolerance', 1e-6, ...
            'E0Scale', e0, ...
            'D0Scale', d0, ...
            'verbose', false);
        try
            fitI = fit_daily_seiqrd_core(data, cfgS, o);
        catch err
            if opts.verbose
                fprintf('  sensitivity %s failed: %s\n', name, err.message);
            end
            continue;
        end
    end

    m = fitI.metrics;
    rows{i} = table(string(name), cfgS.rhoH0, cfgS.rhoF0, cfgS.nu, ...
        e0, d0, ...
        qget(fitI, 'betaC0'), qget(fitI, 'u1'), qget(fitI, 'u2'), ...
        qget(fitI, 'alpha0'), qget(fitI, 'mu'), qget(fitI, 'rhoRep'), ...
        m.R0, m.Rc, m.Rh, m.Rf, m.R0late, m.RcLate, m.RhLate, m.RfLate, ...
        m.CFRmodel, m.CFRobs, m.holdoutMAPEcases, m.holdoutMAPEdeaths, ...
        m.holdoutRMSEcases, m.AIC, fitI.cost, fitI.success, ...
        'VariableNames', {'scenario', 'rhoH0', 'rhoF0', 'nu', ...
        'E0Scale', 'D0Scale', 'betaC0', 'u1', 'u2', 'alpha0', 'mu', ...
        'rhoRep', 'R0', 'Rc', 'Rh', 'Rf', 'R0late', 'RcLate', ...
        'RhLate', 'RfLate', 'CFRmodel', 'CFRobs', ...
        'holdoutMAPEcases', 'holdoutMAPEdeaths', 'holdoutRMSEcases', ...
        'AIC', 'cost', 'success'});
    if opts.verbose
        fprintf('  sensitivity %-10s: R0late %.3f, holdMAPE %.2f%%\n', ...
            name, m.R0late, m.holdoutMAPEcases);
    end
end
sens = struct();
sens.scenario = scenario;
rows = rows(~cellfun(@isempty, rows));
if isempty(rows)
    error('p2_sensitivity:allFailed', 'All sensitivity fits failed.');
end
sens.table = vertcat(rows{:});

groups = {'rhoH0', 'rhoH0_low', 'rhoH0_high'; ...
          'rhoF0', 'rhoF0_low', 'rhoF0_high'; ...
          'nu',    'nu_low',    'nu_high'; ...
          'E0',    'E0_low',    'E0_high'; ...
          'D0',    'D0_low',    'D0_high'};
metrics = {'R0late', 'holdoutMAPEcases', 'CFRmodel'};
T = sens.table;
names = string(T.scenario);
torn = table();
for g = 1:size(groups, 1)
    ilo = find(names == groups{g, 2}, 1);
    ihi = find(names == groups{g, 3}, 1);
    if isempty(ilo) || isempty(ihi)
        continue;
    end
    for j = 1:numel(metrics)
        lo = T.(metrics{j})(ilo);
        hi = T.(metrics{j})(ihi);
        row = table(string(groups{g, 1}), string(metrics{j}), lo, hi, ...
            abs(hi - lo), 'VariableNames', {'parameter', 'metric', ...
            'low', 'high', 'range'});
        torn = [torn; row]; %#ok<AGROW>
    end
end
sens.tornado = torn;
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
