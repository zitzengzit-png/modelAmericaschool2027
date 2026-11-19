%% Q2: daily-aligned second-question method
% Keeps the P0 daily standard (127 fit / 15 holdout), and adopts the good
% parts of ideas/数据处理方案确定(1).md:
%   - 6-parameter betaC+rhoH+rhoF parameterization
%   - log NLS + CFR soft constraint
%   - rhoRep estimated as a sensitivity, baseline fixed at 1
%   - MultiStart 8
%   - 2/3-node AIC/BIC + tau-grid sensitivity
%   - block bootstrap with 14/21-day blocks
%   - profile rhoRep, alpha0, rhoH0
%
% Writes ws/new/outputs/q2/ and the Q2 daily observation CSV.
clear; clc; close all;

cfg = config();
data = load_data(cfg);
outDir = cfg.q2OutDir;
Q2 = build_q2_daily_data(data, cfg);

writetable(Q2.daily, fullfile(cfg.trackerDir, ...
    'q2_daily_observations_20261111.csv'));
writetable(Q2.weekly, fullfile(cfg.trackerDir, ...
    'q2_weekly_validation_20261111.csv'));
fprintf('Q2 daily: %d rows, fit %d, holdout %d\n', height(Q2.daily), ...
    nnz(Q2.daily.phase == "fit"), nnz(Q2.daily.phase == "holdout"));

%% 1. Baseline fixed rhoRep=1 and free-rhoRep sensitivity
fprintf('\n--- Q2 baseline fits ---\n');
fitFix = fit_daily_seiqrd(data, cfg, struct('nStarts', 8, ...
    'verbose', true, 'fixRhoRep', true));
fitFree = fit_daily_seiqrd(data, cfg, struct('nStarts', 8, ...
    'verbose', true, 'fixRhoRep', false));

write_fit(outDir, fitFix, 'Q2_fixed');
write_fit(outDir, fitFree, 'Q2_free');

fprintf('fixed rhoRep: R2 %.4f/%.4f holdMAPE %.3f/%.3f R0 %.3f late %.3f\n', ...
    fitFix.metrics.R2cases, fitFix.metrics.R2deaths, ...
    fitFix.metrics.holdoutMAPEcases, fitFix.metrics.holdoutMAPEdeaths, ...
    fitFix.metrics.R0, fitFix.metrics.R0late);
fprintf('free  rhoRep: %.4f, R2 %.4f/%.4f holdMAPE %.3f/%.3f R0 %.3f late %.3f\n', ...
    fitFree.params.rhoRep, fitFree.metrics.R2cases, ...
    fitFree.metrics.R2deaths, fitFree.metrics.holdoutMAPEcases, ...
    fitFree.metrics.holdoutMAPEdeaths, fitFree.metrics.R0, ...
    fitFree.metrics.R0late);

%% 2. Profile: alpha0, rhoRep, rhoH0
fprintf('\n--- Q2 profiles ---\n');
optsP = struct('nStarts', 2, 'maxFunEvals', 400, 'maxIter', 300, ...
    'verbose', true);
a0 = fitFix.params.alpha;
gridA = unique([linspace(max(0.08, 0.5 * a0), min(0.55, 1.5 * a0), 9), a0]);
profA = p2_profile(data, cfg, fitFix, 'alpha0', gridA, optsP);
gridR = unique([0.50:0.05:1.00, fitFree.params.rhoRep, 1.0]);
profR = p2_profile(data, cfg, fitFree, 'rhoRep', gridR, optsP);

writetable(add_param(profA.table, "alpha0"), ...
    fullfile(outDir, 'Q2_profile_alpha0.csv'));
writetable(add_param(profR.table, "rhoRep"), ...
    fullfile(outDir, 'Q2_profile_rhoRep.csv'));

rhoGrid = [0.30 0.40 0.50];
rhoRows = cell(numel(rhoGrid), 1);
for i = 1:numel(rhoGrid)
    cfgH = cfg;
    cfgH.rhoH0 = rhoGrid(i);
    if abs(rhoGrid(i) - cfg.rhoH0) < 1e-12
        f = fitFix;
    else
        f = fit_daily_seiqrd(data, cfgH, struct('nStarts', 3, ...
            'verbose', true, 'fixRhoRep', true));
    end
    m = f.metrics;
    rhoRows{i} = table(rhoGrid(i), f.params.rhoH0, m.R0, m.Rc, ...
        m.Rh, m.Rf, m.R0late, m.RcLate, m.RhLate, m.RfLate, ...
        m.R2cases, m.R2deaths, m.holdoutMAPEcases, m.holdoutMAPEdeaths, ...
        m.AIC, m.BIC, f.cost, f.success, ...
        'VariableNames', {'rhoH0', 'rhoH0_used', 'R0', 'Rc', 'Rh', ...
        'Rf', 'R0late', 'RcLate', 'RhLate', 'RfLate', 'R2cases', ...
        'R2deaths', 'holdoutMAPEcases', 'holdoutMAPEdeaths', ...
        'AIC', 'BIC', 'cost', 'success'});
end
rhoTable = vertcat(rhoRows{:});
writetable(rhoTable, fullfile(outDir, 'Q2_rhoH_sensitivity.csv'));

profCI = make_profile_ci(profA, profR, fitFix, fitFree);
writetable(profCI, fullfile(outDir, 'Q2_profile_ci.csv'));

%% 3. AIC/BIC: 2 vs 3 nodes, plus second-knot grid
fprintf('\n--- Q2 node comparison ---\n');
p3 = {'betaC0', 'u1', 'u2', 'u3', 'alpha0', 'mu', 'rhoRep'};
knots3 = days([datetime(2026, 7, 14); datetime(2026, 8, 17); ...
    datetime(2026, 10, 11)] - cfg.dayZero)';
q0_3 = zeros(1, numel(p3));
for i = 1:numel(p3)
    j = find(strcmp(fitFix.paramNames, p3{i}), 1);
    if isempty(j)
        q0_3(i) = 0.05;
    else
        q0_3(i) = fitFix.qFull(j);
    end
end
fit3 = fit_daily_seiqrd(data, cfg, struct('nStarts', 5, ...
    'verbose', true, 'fixRhoRep', true, 'paramNames', {p3}, ...
    'knots', knots3, 'q0', q0_3));

nodeRows = { ...
    table("2knot", fitFix.metrics.kAIC, fitFix.metrics.AIC, ...
        fitFix.metrics.BIC, fitFix.metrics.R2cases, ...
        fitFix.metrics.R2deaths, fitFix.metrics.holdoutMAPEcases, ...
        fitFix.metrics.holdoutMAPEdeaths, fitFix.metrics.R0late, ...
        fitFix.cost, fitFix.success, ...
        'VariableNames', {'model', 'k', 'AIC', 'BIC', 'R2cases', ...
        'R2deaths', 'holdoutMAPEcases', 'holdoutMAPEdeaths', ...
        'R0late', 'cost', 'success'}); ...
    table("3knot", fit3.metrics.kAIC, fit3.metrics.AIC, ...
        fit3.metrics.BIC, fit3.metrics.R2cases, ...
        fit3.metrics.R2deaths, fit3.metrics.holdoutMAPEcases, ...
        fit3.metrics.holdoutMAPEdeaths, fit3.metrics.R0late, ...
        fit3.cost, fit3.success, ...
        'VariableNames', {'model', 'k', 'AIC', 'BIC', 'R2cases', ...
        'R2deaths', 'holdoutMAPEcases', 'holdoutMAPEdeaths', ...
        'R0late', 'cost', 'success'})};
nodeTable = vertcat(nodeRows{:});
nodeTable.deltaAIC = nodeTable.AIC - min(nodeTable.AIC);
nodeTable.deltaBIC = nodeTable.BIC - min(nodeTable.BIC);
writetable(nodeTable, fullfile(outDir, 'Q2_node_comparison.csv'));

tauRows = cell(3, 1);
t2Grid = [datetime(2026, 9, 20); datetime(2026, 10, 11); ...
    datetime(2026, 11, 1)];
for i = 1:numel(t2Grid)
    cfgT = cfg;
    cfgT.betaKnots = [datetime(2026, 8, 17); t2Grid(i)];
    f = fit_daily_seiqrd(data, cfgT, struct('nStarts', 3, ...
        'verbose', true, 'fixRhoRep', true));
    m = f.metrics;
    tauRows{i} = table(string(t2Grid(i), 'yyyy-MM-dd'), m.AIC, m.BIC, ...
        m.R2cases, m.R2deaths, m.holdoutMAPEcases, m.holdoutMAPEdeaths, ...
        m.R0late, f.cost, f.success, ...
        'VariableNames', {'t2', 'AIC', 'BIC', 'R2cases', 'R2deaths', ...
        'holdoutMAPEcases', 'holdoutMAPEdeaths', 'R0late', ...
        'cost', 'success'});
end
tauTable = vertcat(tauRows{:});
writetable(tauTable, fullfile(outDir, 'Q2_tau_grid.csv'));


%% 4. Block bootstrap: 14/21-day blocks
fprintf('\n--- Q2 block bootstrap ---\n');
nL = numel(cfg.q2.blockLengths);
boots = cell(nL, 1);
bootSummary = cell(nL, 1);
for j = 1:nL
    L = cfg.q2.blockLengths(j);
    fprintf('block length %d days, %d replicates\n', L, cfg.q2.nBoot);
    boots{j} = p2_bootstrap(data, cfg, fitFix, struct( ...
        'nBoot', cfg.q2.nBoot, 'blockLen', L, ...
        'seed', cfg.q2.seed + L, 'nStarts', 1, ...
        'maxFunEvals', 300, 'maxIter', 250, ...
        'maxCostFactor', 3.0, 'verbose', true));
    writetable(boots{j}.runs, fullfile(outDir, ...
        sprintf('Q2_bootstrap_runs_%dd.csv', L)));
    writetable(boots{j}.pred, fullfile(outDir, ...
        sprintf('Q2_bootstrap_predictions_%dd.csv', L)));
    T = boots{j}.summaryParams;
    T.blockLen = repmat(L, height(T), 1);
    bootSummary{j} = T;
end
bootParams = vertcat(bootSummary{:});
writetable(bootParams, fullfile(outDir, 'Q2_bootstrap_parameters.csv'));

%% 5. Summary JSON
summary = struct();
summary.generated_utc = string(datetime('now', 'TimeZone', 'UTC'), ...
    'yyyy-MM-dd''T''HH:mm:ss''Z''');
summary.data_file = 'q2_daily_observations_20261111.csv';
summary.daily_fit = [string(cfg.fitStart, 'yyyy-MM-dd'); ...
    string(cfg.fitEnd, 'yyyy-MM-dd')];
summary.daily_holdout = [string(cfg.holdStart, 'yyyy-MM-dd'); ...
    string(cfg.holdEnd, 'yyyy-MM-dd')];
summary.fixed_rhoRep = strip_fit(fitFix);
summary.free_rhoRep = strip_fit(fitFree);
summary.rhoH_sensitivity = table2struct(rhoTable);
summary.profile_ci = table2struct(profCI);
summary.node_comparison = table2struct(nodeTable);
summary.tau_grid = table2struct(tauTable);
summary.bootstrap = struct();
for j = 1:nL
    summary.bootstrap(j).blockLen = boots{j}.blockLen;
    summary.bootstrap(j).nValid = nnz(boots{j}.valid);
    summary.bootstrap(j).summaryParams = table2struct(boots{j}.summaryParams);
end
fid = fopen(fullfile(outDir, 'Q2_summary.json'), 'w');
fprintf(fid, '%s', jsonencode(summary, 'PrettyPrint', true));
fclose(fid);

fprintf('\nQ2 outputs written to %s\n', outDir);


% -------------------------------------------------------------------------
function write_fit(outDir, fit, prefix)
writetable(fit.metrics.params, fullfile(outDir, [prefix '_parameters.csv']));
m = fit.metrics;
m = rmfield(m, 'params');
m.params = table2struct(fit.metrics.params);
m.q = fit.q;
m.qFull = fit.qFull;
m.paramNames = fit.paramNames;
m.freeNames = fit.freeNames;
m.fixedParams = fit.fixedParams;
m.y0 = fit.y0;
m.knots = fit.knots;
fid = fopen(fullfile(outDir, [prefix '_metrics.json']), 'w');
fprintf(fid, '%s', jsonencode(m, 'PrettyPrint', true));
fclose(fid);
end

function T = add_param(T, name)
T = addvars(T, repmat(name, height(T), 1), 'Before', 1, ...
    'NewVariableNames', 'parameter');
end

function T = make_profile_ci(profA, profR, fitA, fitR)
T = table(["alpha0"; "rhoRep"], [fitA.params.alpha; fitR.params.rhoRep], ...
    [profA.ciLow; profR.ciLow], [profA.ciHigh; profR.ciHigh], ...
    [profA.sseMin; profR.sseMin], [profA.threshold; profR.threshold], ...
    [profA.censoredLow; profR.censoredLow], ...
    [profA.censoredHigh; profR.censoredHigh], ...
    'VariableNames', {'parameter', 'estimate', 'ciLow', 'ciHigh', ...
    'sseMin', 'threshold', 'censoredLow', 'censoredHigh'});
end

function s = strip_fit(fit)
m = fit.metrics;
s = rmfield(m, 'params');
s.params = table2struct(m.params);
s.q = fit.q;
s.qFull = fit.qFull;
s.paramNames = fit.paramNames;
s.freeNames = fit.freeNames;
s.fixedParams = fit.fixedParams;
s.y0 = fit.y0;
s.knots = fit.knots;
end

