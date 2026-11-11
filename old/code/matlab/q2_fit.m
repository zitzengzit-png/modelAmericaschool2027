%% Q2: SEIQRD parameter estimation and fit
% Run from ws/src/matlab:  q2_fit
clear; clc; close all;

root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % ws
outDir = fullfile(root, 'outputs', 'matlab');
if ~exist(outDir, 'dir'), mkdir(outDir); end

data = load_data();
p0 = default_params(data);

fprintf('Fitting SEIQRD model (tau grid W26--W38, 3 starts) ...\n');
nStarts = 3;   % legacy reference fit: 3 starting points
fit = fit_seiqrd(data, p0, (1:13)', nStarts);
p = fit.params;
m = fit.metrics;
sim = fit.sim;

fprintf('\n=== Fit results ===\n');
fprintf('tau               : W%d (t=%d)\n', round(m.tauWeek), p.tau);
fprintf('beta0 / beta1     : %.3f / %.3f week^-1\n', p.beta0, p.beta1);
fprintf('alpha / mu        : %.3f / %.3f week^-1\n', p.alpha, p.mu);
fprintf('R0 early / late   : %.3f / %.3f\n', m.R0early, m.R0late);
fprintf('R2 cases / deaths : %.4f / %.4f\n', m.R2cases, m.R2deaths);
fprintf('RMSE C / M / W    : %.1f / %.1f / %.1f\n', ...
    m.RMSEcases, m.RMSEdeaths, m.RMSEweekly);
fprintf('CFR model / obs   : %.3f / %.3f\n', m.CFRmodel, m.CFRobs);
fprintf('Peak weekly       : obs %.0f @W%d; model %.0f @W%d\n', ...
    m.peakWeeklyObs, round(m.peakWeekObs), m.peakWeeklyModel, round(m.peakWeekModel));
fprintf('Rt<1 block        : W%d\n', round(m.flatWeek));
fprintf('Endpoint W%d       : %.0f cases (%+.1f%%), %.0f deaths (%+.1f%%)\n', ...
    25 + data.endpoint_t, m.endpointCasesModel, m.endpointCasesErrorPct, ...
    m.endpointDeathsModel, m.endpointDeathsErrorPct);

%% Save parameter and metric tables
paramTable = table( ...
    ["beta0";"beta1";"tau";"alpha";"mu";"nu";"sigma";"gamma";"gammaQ";"kappa";"R0_early";"R0_late"], ...
    [p.beta0;p.beta1;p.tau;p.alpha;p.mu;p.nu;p.sigma;p.gamma;p.gammaQ;p.kappa;m.R0early;m.R0late], ...
    ["week^-1";"week^-1";"week index";"week^-1";"week^-1";"week^-1";"week^-1";"week^-1";"week^-1";"-";"-";"-"], ...
    'VariableNames', {'parameter','estimate','unit'});
writetable(paramTable, fullfile(outDir, 'fit_parameters_matlab.csv'));

obs = table(data.t, 25 + data.t, data.cases, sim.cases, ...
    data.deaths, sim.deaths, ...
    [NaN; diff(data.cases)], [NaN; diff(sim.cases)], ...
    'VariableNames', {'t','week','cases_obs','cases_fit', ...
    'deaths_obs','deaths_fit','weekly_obs','weekly_fit'});
writetable(obs, fullfile(outDir, 'fit_observations_matlab.csv'));

fid = fopen(fullfile(outDir, 'fit_metrics_matlab.json'), 'w');
fprintf(fid, '%s', jsonencode(m, 'PrettyPrint', true));
fclose(fid);

save(fullfile(outDir, 'fit_result_matlab.mat'), 'fit', 'data', 'p');

%% Figure: cumulative cases/deaths, weekly incidence, Rt
fig = figure('Color', 'w', 'Position', [80 80 1120 820]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(25 + data.t, data.cases, 'ko', 'MarkerSize', 5, 'MarkerFaceColor', 'k');
hold on;
plot(25 + sim.t, sim.cases, 'r-', 'LineWidth', 2.0);
xlabel('Week (W25 = 25)'); ylabel('Cumulative confirmed cases');
title('(a) Cumulative confirmed cases'); grid on; box off;
legend('Observed', 'Model', 'Location', 'northwest'); legend boxoff;

nexttile;
plot(25 + data.t, data.deaths, 'ko', 'MarkerSize', 5, 'MarkerFaceColor', 'k');
hold on;
plot(25 + sim.t, sim.deaths, 'r-', 'LineWidth', 2.0);
xlabel('Week (W25 = 25)'); ylabel('Cumulative deaths');
title('(b) Cumulative deaths'); grid on; box off;

nexttile;
bar(25 + sim.t(2:end), diff(data.cases), 0.65, ...
    'FaceColor', [0.62 0.79 0.88], 'EdgeColor', [0.29 0.56 0.76]);
hold on;
plot(25 + sim.t(2:end), diff(sim.cases), '-o', 'Color', [0.75 0.22 0.17], ...
    'LineWidth', 1.8, 'MarkerSize', 3.5);
xlabel('Week (W25 = 25)'); ylabel('Weekly new confirmed cases');
title('(c) Weekly incidence'); grid on; box off;
legend('Observed', 'Model', 'Location', 'northeast'); legend boxoff;

nexttile;
plot(25 + sim.t, sim.rt, '-', 'Color', [0.08 0.40 0.75], 'LineWidth', 2.0);
hold on;
yline(1, 'k--', 'LineWidth', 1.0);
xline(25 + p.tau, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);
xlabel('Week (W25 = 25)'); ylabel('Effective reproduction number R_t');
title('(d) Effective reproduction number'); grid on; box off;

sgtitle(sprintf('SEIQRD fit to the 2026 Bundibugyo Ebola outbreak (W%d-W%d)', ...
    data.week(1), data.week(end)), 'FontSize', 13, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(outDir, 'fig_fit_matlab.png'), 'Resolution', 300);

fprintf('\nSaved results to %s\n', outDir);
