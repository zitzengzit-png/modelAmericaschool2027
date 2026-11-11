%% Q1: baseline SEIQRD model
% Run from ws/src/matlab:  q1_model
% ASCII-only MATLAB port of the reference model.
clear; clc; close all;

root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % ws
outDir = fullfile(root, 'outputs', 'matlab');
if ~exist(outDir, 'dir'), mkdir(outDir); end

data = load_data();
p = default_params(data);

% Dense output for smooth figures.
t = (0:0.05:27)';
sim = simulate_seiqrd(p, t, p.y0);

fprintf('\n=== Q1 baseline ===\n');
fprintf('N                 : %.0f\n', p.N);
fprintf('beta0 / beta1     : %.3f / %.3f per week\n', p.beta0, p.beta1);
fprintf('alpha / mu       : %.3f / %.3f per week\n', p.alpha, p.mu);
fprintf('sigma / gamma    : %.3f / %.3f per week\n', p.sigma, p.gamma);
fprintf('kappa / nu       : %.2f / %.2f\n', p.kappa, p.nu);
fprintf('R0 early / late  : %.3f / %.3f\n', sim.r0Early, sim.r0Late);
fprintf('C(W52) / M(W52)  : %.0f / %.0f\n', sim.cases(end), sim.deaths(end));
fprintf('Rt<1 from week   : W%d\n', 25 + p.tau);

T = table(25 + sim.t, sim.y(:,1), sim.y(:,2), sim.y(:,3), ...
    sim.y(:,4), sim.y(:,5), sim.y(:,6), sim.y(:,7), ...
    sim.cases, sim.deaths, sim.rt, ...
    'VariableNames', {'week','S','E','I','Q','R','D','M', ...
    'cumCases','cumDeaths','Rt'});
writetable(T, fullfile(outDir, 'q1_baseline.csv'));

fig = figure('Color', 'w', 'Position', [80 80 1120 820]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(25 + sim.t, sim.y(:,1), 'LineWidth', 1.6); hold on;
plot(25 + sim.t, sim.y(:,2), 'LineWidth', 1.6);
plot(25 + sim.t, sim.y(:,3), 'LineWidth', 1.6);
plot(25 + sim.t, sim.y(:,4), 'LineWidth', 1.6);
xlabel('Week (W25 = 25)'); ylabel('Persons');
title('(a) S, E, I, Q'); grid on; box off;
legend('S','E','I','Q','Location','best'); legend boxoff;

nexttile;
plot(25 + sim.t, sim.y(:,5), 'LineWidth', 1.6); hold on;
plot(25 + sim.t, sim.y(:,6), 'LineWidth', 1.6);
plot(25 + sim.t, sim.y(:,7), 'LineWidth', 1.6);
xlabel('Week (W25 = 25)'); ylabel('Persons');
title('(b) R, D, M'); grid on; box off;
legend('R','D','M','Location','best'); legend boxoff;

nexttile;
plot(25 + sim.t, sim.cases, 'LineWidth', 1.8); hold on;
plot(25 + sim.t, sim.deaths, 'LineWidth', 1.8);
xlabel('Week (W25 = 25)'); ylabel('Cumulative persons');
title('(c) Cumulative cases and deaths'); grid on; box off;
legend('C = I+Q+R+M','M','Location','northwest'); legend boxoff;

nexttile;
plot(25 + sim.t, sim.rt, 'LineWidth', 1.8); hold on;
yline(1, 'k--', 'LineWidth', 1.0);
xline(25 + p.tau, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);
xlabel('Week (W25 = 25)'); ylabel('R_t');
title('(d) Effective reproduction number'); grid on; box off;

sgtitle('SEIQRD baseline: 2026 Bundibugyo Ebola outbreak', ...
    'FontSize', 13, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(outDir, 'fig_q1_baseline.png'), 'Resolution', 300);
fprintf('Saved Q1 outputs to %s\n', outDir);
