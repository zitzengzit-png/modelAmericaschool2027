%% run_task4_delivery.m
% Official Task 4 pipeline: delivery caliber (shared Q2 9/20, beta_mult=1).
% Writes structured CSVs to ws/new/outputs/task4/ and a console log.
clear; clc; close all;

outDir = config().task4OutDir;
if ~exist(outDir, 'dir'), mkdir(outDir); end
logFile = fullfile(outDir, 'T4_console.log');
if isfile(logFile), delete(logFile); end

diary(logFile);
fprintf('=== Task 4 delivery pipeline ===\n');
fprintf('Window: 2026-06-21 to 2026-11-09; shared Q2 9/20 parameters.\n');

main = task4_spatial_skeleton();
writetable(main.province_table, fullfile(outDir, 'T4_main.csv'));
fprintf('\nR_net = %.4f; holdout MAE = %.2f (flat %.2f)\n', ...
    main.R_net, main.holdout_mae_model, main.holdout_mae_flat);

stratT = task4_strategies();
writetable(stratT, fullfile(outDir, 'T4_strategies.csv'));

sensT = task4_sensitivity(); %#ok<NASGU>  % writes T4_sensitivity.csv

[holdT, mae] = task4_holdout_table();
writetable(holdT, fullfile(outDir, 'T4_holdout.csv'));
fprintf('\nMAE summary: flat %.2f | shared %.2f | const %.2f | fade %.2f\n', ...
    mae.flat, mae.shared, mae.const, mae.fade);

fprintf('\nTask 4 structured outputs written to %s\n', outDir);

% These two are self-contained scripts with their own clear/clc; their
% tables are captured in T4_console.log.
task4_q2_uncertainty
task4_border_screening

diary off;
