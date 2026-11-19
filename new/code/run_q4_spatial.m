%% Q4: 8-province spatial SEIQRD, gravity proxy, calibration, R_net, strategies
% Run from ws/new/code:  run_q4_spatial
% Writes ws/new/outputs/q4/Q4_*.csv|json|png
clear; clc; close all;

cfg = config();
outDir = cfg.q4OutDir;
figDir = fullfile(outDir, 'Q4_figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

fprintf('=== Q4 spatial model ===\n');
D = q4_load_data(cfg, struct('mShare', 0.015, 'gamma', 1.5));
p = D.p;
y0 = q4_initial_state(D, p, 0);

fprintf('Calibrating province beta multipliers to 10/25 totals...\n');
fit = q4_calibrate(D, p, D.P, y0, struct('nStarts', 2, 'verbose', true));
p2 = p;
p2.betaMult = fit.betaMult;

out = q4_simulate(D, p2, D.P, y0, 0:141);
C10m = out.C(127, :)';
C11m = out.C(end, :)';
Cobs10 = D.C10;
Cobs11 = D.C11;
netObs = Cobs11 - Cobs10;
netModel = C11m - C10m;
flatBase = (D.C10 - D.C1018) * 15 / 7;

valid = isfinite(netObs) & isfinite(netModel) & isfinite(flatBase);
maeModel = mean(abs(netModel(valid) - netObs(valid)));
maeFlat  = mean(abs(flatBase(valid) - netObs(valid)));

[Rnet, Rlocal, K] = q4_rnet(D, p2, D.P, out.S(end, :), 141);
RlocT = table(D.provNames, Rlocal, 'VariableNames', ...
    {'province', 'R_local'});

fitT = table(D.provNames, Cobs10, C10m, Cobs10 - C10m, ...
    Cobs11, C11m, netObs, netModel, flatBase, ...
    'VariableNames', {'province', 'C_obs_1025', 'C_model_1025', ...
    'err_1025', 'C_obs_1109', 'C_model_1109', ...
    'net_obs', 'net_model', 'flat_baseline'});
writetable(fitT, fullfile(outDir, 'Q4_province_fit.csv'));

bmT = table(D.provNames, p2.betaMult, ...
    'VariableNames', {'province', 'beta_mult'});
writetable(bmT, fullfile(outDir, 'Q4_beta_mult.csv'));
writetable(RlocT, fullfile(outDir, 'Q4_Rnet.csv'));

fprintf('MAE holdout: model %.2f | flat %.2f\n', maeModel, maeFlat);
fprintf('R_net = %.4f\n', Rnet);

% Strategies from 10/25 state.
y0late = q4_initial_state(D, p2, 126);
stratT = q4_strategies(D, p2, D.P, y0late);
writetable(stratT, fullfile(outDir, 'Q4_strategies.csv'));

% Cross-border branch risk.
borderT = q4_border_risk([9 1], [0.8 1.0 1.05 1.2 1.5], [0.5 1 Inf]);
writetable(borderT, fullfile(outDir, 'Q4_border_risk.csv'));

%% Figures
% 1. Network / geography
fig = figure('Color', 'w', 'Position', [60 60 900 720]);
hold on;
for i = 1:D.nP
    for j = i+1:D.nP
        if D.A(i,j) > 0
            plot(D.lon([i j]), D.lat([i j]), '-', ...
                'Color', [0.65 0.65 0.65], 'LineWidth', 1.0);
        end
    end
end
sz = 80 + 450 * sqrt(D.N / max(D.N));
scatter(D.lon, D.lat, sz, 'filled', 'MarkerFaceColor', [0.25 0.55 0.85], ...
    'MarkerEdgeColor', 'k');
for i = 1:D.nP
    if D.lon(i) > 29.5
        text(D.lon(i) - 0.35, D.lat(i) + 0.12, D.provNames{i}, ...
            'FontSize', 8.5, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'right');
    else
        text(D.lon(i) + 0.35, D.lat(i) + 0.12, D.provNames{i}, ...
            'FontSize', 8.5, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'left');
    end
end
xlim([min(D.lon) - 1.2, max(D.lon) + 1.2]);
ylim([min(D.lat) - 0.8, max(D.lat) + 0.8]);
xlabel('Longitude'); ylabel('Latitude');
title('Q4: 8-province adjacency and population (bubble)');
grid on; box on; axis equal;
exportgraphics(fig, fullfile(figDir, 'Q4_network.png'), 'Resolution', 300);

% 2. P matrix
fig = figure('Color', 'w', 'Position', [60 60 760 660]);
imagesc(D.P); colorbar;
set(gca, 'XTick', 1:D.nP, 'XTickLabel', D.provNames, ...
    'YTick', 1:D.nP, 'YTickLabel', D.provNames, ...
    'TickLabelInterpreter', 'none');
xtickangle(45);
title('Q4: stay-share matrix P (column-stochastic)');
xlabel('source province j'); ylabel('receiving province i');
exportgraphics(fig, fullfile(figDir, 'Q4_Pmatrix.png'), 'Resolution', 300);

% 3. 10/25 fit
fig = figure('Color', 'w', 'Position', [60 60 1000 480]);
bar([Cobs10, C10m], 'grouped');
set(gca, 'XTick', 1:D.nP, 'XTickLabel', D.provNames, ...
    'TickLabelInterpreter', 'none');
xtickangle(45);
legend({'observed', 'model'}, 'Location', 'northeast'); legend boxoff;
ylabel('cumulative confirmed cases'); title('Q4: fit at 2026-10-25');
grid on; box off;
exportgraphics(fig, fullfile(figDir, 'Q4_fit.png'), 'Resolution', 300);

% 4. holdout
fig = figure('Color', 'w', 'Position', [60 60 1000 480]);
bar([netObs, netModel, flatBase], 'grouped');
set(gca, 'XTick', 1:D.nP, 'XTickLabel', D.provNames, ...
    'TickLabelInterpreter', 'none');
xtickangle(45);
legend({'observed', 'model', 'flat baseline'}, ...
    'Location', 'northeast'); legend boxoff;
ylabel('net increase 10/26-11/09'); title('Q4: holdout net increase');
grid on; box off;
exportgraphics(fig, fullfile(figDir, 'Q4_holdout.png'), 'Resolution', 300);

% 5. R_net vs m
mGrid = [0.005 0.015 0.030 0.050];
Rscan = nan(size(mGrid));
for k = 1:numel(mGrid)
    Pm = gravity_P(D, mGrid(k), 1.5);
    Rscan(k) = q4_rnet(D, p2, Pm, out.S(end, :), 141);
end
fig = figure('Color', 'w', 'Position', [60 60 760 500]);
plot(mGrid * 100, Rscan, 'o-', 'LineWidth', 1.8, 'MarkerSize', 6);
yline(1, 'k--', 'R=1');
xlabel('out-of-province stay share m (%)');
ylabel('R_{net}');
title('Q4: network threshold vs mobility proxy');
grid on; box off;
exportgraphics(fig, fullfile(figDir, 'Q4_Rnet.png'), 'Resolution', 300);

% 6. border risk (k=1)
fig = figure('Color', 'w', 'Position', [60 60 820 500]);
Bk = borderT(borderT.k == 1, :);
hold on;
for n = [9 1]
    idx = Bk.nSeeds == n;
    plot(Bk.m(idx), 100 * Bk.p_nonextinct(idx), 'o-', ...
        'LineWidth', 1.8, 'MarkerSize', 6);
end
xlabel('local secondary-case mean m'); ylabel('P(at least one non-extinct) %');
title('Q4: import risk, k=1');
legend({'Kenya n=9', 'Nigeria n=1'}, 'Location', 'northwest'); legend boxoff;
grid on; box off;
exportgraphics(fig, fullfile(figDir, 'Q4_border.png'), 'Resolution', 300);

%% Summary
summary = struct();
summary.generated_utc = string(datetime('now', 'TimeZone', 'UTC'), ...
    'yyyy-MM-dd''T''HH:mm:ss''Z''');
summary.provinces = D.provNames;
summary.mShare = D.mShare;
summary.Rnet = Rnet;
summary.Rlocal = table2struct(RlocT);
summary.betaMult = table2struct(bmT);
summary.mae_holdout_model = maeModel;
summary.mae_holdout_flat = maeFlat;
summary.calibration_cost = fit.cost;
summary.calibration_C10_obs = Cobs10;
summary.calibration_C10_model = C10m;
summary.strategies = table2struct(stratT);
summary.border = table2struct(borderT);
summary.notes = ['P is a gravity stay-share proxy, not observed OD; ' ...
    'beta_mult absorbs reporting/behaviour; rho_rep=1 approximation.'];
summary.warning = ['Holdout MAE is worse than the flat baseline; ' ...
    'R_net is conditional and must not be used as a final prediction. ' ...
    'Low-burden provinces are fixed at beta_mult=1.'];
write_json(fullfile(outDir, 'Q4_summary.json'), summary);

fprintf('\nQ4 outputs written to %s\n', outDir);

% -------------------------------------------------------------------------
function P = gravity_P(D, mShare, gamma)
nP = D.nP;
W = zeros(nP);
for i = 1:nP
    for j = 1:nP
        if i ~= j && D.A(i,j) > 0
            W(i,j) = D.N(i) * D.N(j) * ...
                (D.distKm(i,j) / 1000)^(-gamma);
        end
    end
end
colW = sum(W, 1);
P = zeros(nP);
for j = 1:nP
    if colW(j) > 0
        B = W(:,j) / colW(j);
        P(:,j) = mShare * B;
        P(j,j) = 1 - mShare;
    else
        P(j,j) = 1;
    end
end
end

function write_json(file, s)
fid = fopen(file, 'w');
fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true));
fclose(fid);
end

