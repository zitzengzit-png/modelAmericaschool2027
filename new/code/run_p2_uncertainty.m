%% P2: uncertainty, sensitivity and model comparison
% Run from ws/new/code:  run_p2_uncertainty
% Writes ws/new/outputs/p2/P2_*.csv|json|png
clear; clc; close all;

cfg = config();
data = load_data(cfg);
outDir = cfg.p2OutDir;

fprintf('=== P2 uncertainty ===\n');
fprintf('fit     : %s .. %s\n', string(cfg.fitStart, 'yyyy-MM-dd'), ...
    string(cfg.fitEnd, 'yyyy-MM-dd'));
fprintf('holdout : %s .. %s\n', string(cfg.holdStart, 'yyyy-MM-dd'), ...
    string(cfg.holdEnd, 'yyyy-MM-dd'));
fprintf('outDir  : %s\n', outDir);

%% 1. Baseline P1 fit (final code)
fprintf('\n--- baseline P1 fit ---\n');
fitBase = fit_daily_seiqrd(data, cfg, struct( ...
    'nStarts', 3, 'verbose', true, 'fixRhoRep', true));
mBase = fitBase.metrics;

writetable(mBase.params, fullfile(outDir, 'P2_baseline_parameters.csv'));
baseOut = rmfield(mBase, 'params');
baseOut.params = table2struct(mBase.params);
baseOut.qFull = fitBase.qFull;
baseOut.paramNames = fitBase.paramNames;
baseOut.freeNames = fitBase.freeNames;
baseOut.fixedParams = fitBase.fixedParams;
baseOut.y0 = fitBase.y0;
baseOut.knots = fitBase.knots;
baseOut.allowRebound = fitBase.allowRebound;
fid = fopen(fullfile(outDir, 'P2_baseline_metrics.json'), 'w');
fprintf(fid, '%s', jsonencode(baseOut, 'PrettyPrint', true));
fclose(fid);

%% 2. Block bootstrap (7-day and 14-day blocks)
fprintf('\n--- block bootstrap ---\n');
nL = numel(cfg.p2.blockLengths);
boots = cell(nL, 1);
paramTables = cell(nL, 1);
derivedTables = cell(nL, 1);
validRows = cell(nL, 1);
for j = 1:nL
    L = cfg.p2.blockLengths(j);
    fprintf('block length %d days\n', L);
    optsB = struct( ...
        'nBoot', cfg.p2.nBoot, ...
        'blockLen', L, ...
        'seed', cfg.p2.seed + L, ...
        'nStarts', cfg.p2.bootStarts, ...
        'maxFunEvals', cfg.p2.bootMaxFunEvals, ...
        'maxIter', cfg.p2.bootMaxIter, ...
        'maxCostFactor', cfg.p2.maxCostFactor, ...
        'verbose', true);
    boots{j} = p2_bootstrap(data, cfg, fitBase, optsB);

    writetable(boots{j}.runs, fullfile(outDir, ...
        sprintf('P2_bootstrap_runs_%dd.csv', L)));
    writetable(boots{j}.pred, fullfile(outDir, ...
        sprintf('P2_bootstrap_predictions_%dd.csv', L)));

    T = boots{j}.summaryParams;
    T.blockLen = repmat(L, height(T), 1);
    paramTables{j} = T;
    T = boots{j}.summaryDerived;
    T.blockLen = repmat(L, height(T), 1);
    derivedTables{j} = T;
    validRows{j} = table(L, boots{j}.nBoot, nnz(boots{j}.valid), ...
        100 * nnz(boots{j}.valid) / boots{j}.nBoot, ...
        'VariableNames', {'blockLen', 'nBoot', 'nValid', 'validPct'});
end
P2bootParams = vertcat(paramTables{:});
P2bootDerived = vertcat(derivedTables{:});
P2bootValid = vertcat(validRows{:});
writetable(P2bootParams, fullfile(outDir, 'P2_bootstrap_parameters.csv'));
writetable(P2bootDerived, fullfile(outDir, 'P2_bootstrap_derived.csv'));
writetable(P2bootValid, fullfile(outDir, 'P2_bootstrap_valid.csv'));
disp(P2bootValid);

%% 3. Profile likelihood: alpha0, u1, rhoRep
fprintf('\n--- profile likelihood ---\n');
fitFree = fit_daily_seiqrd(data, cfg, struct( ...
    'nStarts', 3, 'verbose', true, 'fixRhoRep', false));

estA = fitBase.params.alpha;
estU = fitBase.params.u1;
estR = fitFree.params.rhoRep;
gridA = unique([linspace(max(0.08, 0.5 * estA), ...
    min(0.55, 1.5 * estA), cfg.p2.profileN), estA]);
gridU = unique([linspace(max(0.00, estU - 0.20), ...
    min(0.95, estU + 0.20), cfg.p2.profileN), estU]);
gridR = unique([cfg.p2.rhoRepGrid(:)', estR, 1.0]);

optsP = struct( ...
    'nStarts', cfg.p2.profileStarts, ...
    'maxFunEvals', cfg.p2.profileMaxFunEvals, ...
    'maxIter', cfg.p2.profileMaxIter, ...
    'verbose', true);
profA = p2_profile(data, cfg, fitBase, 'alpha0', gridA, optsP);
profU = p2_profile(data, cfg, fitBase, 'u1', gridU, optsP);
profR = p2_profile(data, cfg, fitFree, 'rhoRep', gridR, optsP);

profiles = {profA, profU, profR};
profNames = ["alpha0", "u1", "rhoRep"];
for i = 1:numel(profiles)
    T = addvars(profiles{i}.table, ...
        repmat(profNames(i), height(profiles{i}.table), 1), ...
        'Before', 1, 'NewVariableNames', 'parameter');
    writetable(T, fullfile(outDir, sprintf('P2_profile_%s.csv', ...
        char(profNames(i)))));
end

profRows = {
    'alpha0', estA, profA.ciLow, profA.ciHigh, profA.sseMin, ...
        profA.threshold, profA.censoredLow, profA.censoredHigh;
    'u1', estU, profU.ciLow, profU.ciHigh, profU.sseMin, ...
        profU.threshold, profU.censoredLow, profU.censoredHigh;
    'rhoRep', estR, profR.ciLow, profR.ciHigh, profR.sseMin, ...
        profR.threshold, profR.censoredLow, profR.censoredHigh};
profCI = cell2table(profRows, 'VariableNames', {'parameter', ...
    'estimate', 'ciLow', 'ciHigh', 'sseMin', 'threshold', ...
    'censoredLow', 'censoredHigh'});
writetable(profCI, fullfile(outDir, 'P2_profile_ci.csv'));
disp(profCI);


%% 4. Sensitivity of fixed assumptions
fprintf('\n--- fixed-parameter sensitivity ---\n');
optsS = struct( ...
    'nStarts', cfg.p2.sensStarts, ...
    'maxFunEvals', cfg.p2.sensMaxFunEvals, ...
    'maxIter', cfg.p2.sensMaxIter, ...
    'verbose', true);
sens = p2_sensitivity(data, cfg, fitBase, optsS);
writetable(sens.table, fullfile(outDir, 'P2_sensitivity.csv'));
writetable(sens.tornado, fullfile(outDir, 'P2_sensitivity_tornado.csv'));
disp(sens.table(:, {'scenario', 'R0late', 'holdoutMAPEcases', 'CFRmodel'}));

%% 5. Model comparison: 2 knots vs 3 knots, u2 constraint
fprintf('\n--- model comparison ---\n');
optsC = struct('nStarts', cfg.p2.compareStarts, 'verbose', true);
cmp = p2_model_compare(data, cfg, fitBase, optsC);
writetable(cmp.table, fullfile(outDir, 'P2_model_comparison.csv'));
writetable(cmp.weekly, fullfile(outDir, 'P2_model_comparison_weekly.csv'));
disp(cmp.table(:, {'model', 'kAIC', 'AIC', 'BIC', 'deltaAIC', ...
    'holdoutMAPEcases', 'R0late'}));
fprintf('best AIC model: %s\n', cmp.bestModel);


%% 6. Figures
fprintf('\n--- figures ---\n');
% 6.1 bootstrap parameter distributions (14-day blocks)
boot = boots{end};
Q = boot.q(boot.valid, :);
paramNames = fitBase.paramNames;
fig = figure('Color', 'w', 'Position', [60 60 1200 700]);
tiledlayout(2, 4, 'Padding', 'compact', 'TileSpacing', 'compact');
for i = 1:numel(paramNames)
    nexttile;
    histogram(Q(:, i), 20, 'FaceColor', [0.45 0.65 0.85], ...
        'EdgeColor', 'w');
    hold on;
    xline(fitBase.qFull(i), 'r-', 'LineWidth', 1.5);
    if strcmp(paramNames{i}, 'u2')
        xline(-0.5, 'k:', 'LineWidth', 1.0);
        xline(0.95, 'k:', 'LineWidth', 1.0);
    end
    xlabel(paramNames{i}); ylabel('count');
    if strcmp(paramNames{i}, 'rhoRep')
        title(sprintf('%s (fixed)', paramNames{i}));
    else
        title(sprintf('%s (block %d)', paramNames{i}, boot.blockLen));
    end
    grid on; box off;
end
nexttile;
histogram(boot.derived(boot.valid, 5), 20, ...
    'FaceColor', [0.85 0.55 0.45], 'EdgeColor', 'w');
hold on; xline(mBase.R0late, 'r-', 'LineWidth', 1.5);
xlabel('R0 late'); ylabel('count'); title('R0 late'); grid on; box off;
nexttile;
histogram(boot.derived(boot.valid, 11), 20, ...
    'FaceColor', [0.55 0.75 0.55], 'EdgeColor', 'w');
hold on; xline(mBase.holdoutMAPEcases, 'r-', 'LineWidth', 1.5);
xlabel('holdout MAPE cases (%)'); ylabel('count');
title('holdout MAPE'); grid on; box off;
sgtitle('P2: block bootstrap (valid replicates)', ...
    'FontSize', 13, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(outDir, 'P2_bootstrap.png'), ...
    'Resolution', 300);

% 6.2 prediction fan (14-day blocks)
pred = boot.pred;
fig = figure('Color', 'w', 'Position', [60 60 1100 760]);
tiledlayout(2, 1, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
x = datenum(pred.date);
fill([x; flipud(x)], [pred.cases_p2_5; flipud(pred.cases_p97_5)], ...
    [0.85 0.90 0.97], 'EdgeColor', 'none');
hold on;
plot(x, pred.cases_obs, 'ko', 'MarkerSize', 3);
plot(x, pred.cases_base, 'r-', 'LineWidth', 1.5);
plot(x, pred.cases_p50, 'b--', 'LineWidth', 1.2);
xline(datenum(cfg.fitEnd), 'k--');
ylabel('Cumulative cases'); title('(a) Cases: bootstrap 95% band');
grid on; box off; datetick('x', 'mm-dd', 'keepticks');
legend({'95% band', 'observed', 'baseline', 'median'}, ...
    'Location', 'northwest'); legend boxoff;
nexttile;
fill([x; flipud(x)], [pred.deaths_p2_5; flipud(pred.deaths_p97_5)], ...
    [0.97 0.90 0.90], 'EdgeColor', 'none');
hold on;
plot(x, pred.deaths_obs, 'ko', 'MarkerSize', 3);
plot(x, pred.deaths_base, 'r-', 'LineWidth', 1.5);
plot(x, pred.deaths_p50, 'b--', 'LineWidth', 1.2);
xline(datenum(cfg.fitEnd), 'k--');
ylabel('Cumulative deaths'); title('(b) Deaths: bootstrap 95% band');
grid on; box off; datetick('x', 'mm-dd', 'keepticks');
legend({'95% band', 'observed', 'baseline', 'median'}, ...
    'Location', 'northwest'); legend boxoff;
sgtitle('P2: bootstrap prediction band', ...
    'FontSize', 13, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(outDir, 'P2_bootstrap_forecast.png'), ...
    'Resolution', 300);


% 6.3 profile likelihood
fig = figure('Color', 'w', 'Position', [60 60 1200 360]);
tiledlayout(1, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
for i = 1:numel(profiles)
    pr = profiles{i};
    nexttile;
    plot(pr.grid, pr.sseDaily, 'o-', 'LineWidth', 1.5, ...
        'MarkerSize', 4);
    hold on;
    yline(pr.threshold, 'r--', 'LineWidth', 1.2);
    xline(profCI.estimate(i), 'k:', 'LineWidth', 1.1);
    if i == 3
        xline(1.0, 'g:', 'LineWidth', 1.1);
    end
    xlabel(pr.paramName); ylabel('daily SSE');
    title(sprintf('%s profile', pr.paramName));
    grid on; box off;
end
sgtitle('P2: profile likelihood (95% threshold)', ...
    'FontSize', 13, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(outDir, 'P2_profile.png'), ...
    'Resolution', 300);

% 6.4 sensitivity
T = sens.table;
fig = figure('Color', 'w', 'Position', [60 60 1100 420]);
tiledlayout(1, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
nexttile;
bar(T.R0late, 'FaceColor', [0.45 0.65 0.85]);
hold on; yline(mBase.R0late, 'r--', 'LineWidth', 1.2);
set(gca, 'XTick', 1:height(T), 'XTickLabel', cellstr(T.scenario), ...
    'XTickLabelRotation', 45, 'TickLabelInterpreter', 'none');
ylabel('R0 late'); title('(a) R0 late'); grid on; box off;
nexttile;
bar(T.holdoutMAPEcases, 'FaceColor', [0.85 0.55 0.45]);
hold on; yline(mBase.holdoutMAPEcases, 'r--', 'LineWidth', 1.2);
set(gca, 'XTick', 1:height(T), 'XTickLabel', cellstr(T.scenario), ...
    'XTickLabelRotation', 45, 'TickLabelInterpreter', 'none');
ylabel('holdout MAPE cases (%)'); title('(b) Holdout error');
grid on; box off;
sgtitle('P2: sensitivity to fixed assumptions', ...
    'FontSize', 13, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(outDir, 'P2_sensitivity.png'), ...
    'Resolution', 300);

% 6.5 model comparison: weekly incidence
W = cmp.weekly;
fig = figure('Color', 'w', 'Position', [60 60 1000 420]);
bar(W.week_end, W.observed, 0.55, 'FaceColor', ...
    [0.75 0.83 0.90], 'EdgeColor', [0.35 0.55 0.75]);
hold on;
plot(W.week_end, W.fit_2knot, 'r-o', 'LineWidth', 1.4, 'MarkerSize', 4);
plot(W.week_end, W.fit_2knot_nonneg, 'b--s', 'LineWidth', 1.4, ...
    'MarkerSize', 4);
plot(W.week_end, W.fit_3knot, 'g-.d', 'LineWidth', 1.4, 'MarkerSize', 4);
xline(cfg.fitEnd, 'k--');
xlabel('Week ending'); ylabel('Weekly new cases');
title('P2: 2-knot vs constrained vs 3-knot');
legend({'observed', '2-knot rebound', '2-knot u2>=0', '3-knot'}, ...
    'Location', 'northeast'); legend boxoff;
grid on; box off; xtickformat('MM-dd');
ax = gca;
ax.XAxis.SecondaryLabel.Visible = 'off';
exportgraphics(fig, fullfile(outDir, 'P2_model_comparison.png'), ...
    'Resolution', 300);


%% 7. JSON summary
summary = struct();
summary.generated_utc = string(datetime('now', 'TimeZone', 'UTC'), ...
    'yyyy-MM-dd''T''HH:mm:ss''Z''');
summary.settings = cfg.p2;
summary.baseline = struct();
summary.baseline.qFull = fitBase.qFull;
summary.baseline.paramNames = fitBase.paramNames;
summary.baseline.freeNames = fitBase.freeNames;
summary.baseline.fixedParams = fitBase.fixedParams;
mb = mBase;
mb = rmfield(mb, 'params');
summary.baseline.metrics = mb;

B = struct('blockLen', {}, 'nValid', {}, 'summaryParams', {}, ...
    'summaryDerived', {});
for j = 1:numel(boots)
    B(j).blockLen = boots{j}.blockLen;
    B(j).nValid = nnz(boots{j}.valid);
    B(j).summaryParams = table2struct(boots{j}.summaryParams);
    B(j).summaryDerived = table2struct(boots{j}.summaryDerived);
end
summary.bootstrap = B;
summary.profiles = table2struct(profCI);
summary.sensitivity = table2struct(sens.table);
summary.modelComparison = table2struct(cmp.table);
summary.bestModel = cmp.bestModel;
summary.files = { ...
    'P2_baseline_parameters.csv', 'P2_baseline_metrics.json', ...
    'P2_bootstrap_parameters.csv', 'P2_bootstrap_derived.csv', ...
    'P2_bootstrap_valid.csv', 'P2_bootstrap_runs_7d.csv', ...
    'P2_bootstrap_runs_14d.csv', 'P2_bootstrap_predictions_7d.csv', ...
    'P2_bootstrap_predictions_14d.csv', 'P2_bootstrap.png', ...
    'P2_bootstrap_forecast.png', 'P2_profile_alpha0.csv', ...
    'P2_profile_u1.csv', 'P2_profile_rhoRep.csv', ...
    'P2_profile_ci.csv', 'P2_profile.png', 'P2_sensitivity.csv', ...
    'P2_sensitivity_tornado.csv', 'P2_sensitivity.png', ...
    'P2_model_comparison.csv', 'P2_model_comparison_weekly.csv', ...
    'P2_model_comparison.png'};
fid = fopen(fullfile(outDir, 'P2_summary.json'), 'w');
fprintf(fid, '%s', jsonencode(summary, 'PrettyPrint', true));
fclose(fid);

fprintf('\nP2 outputs written to %s\n', outDir);

