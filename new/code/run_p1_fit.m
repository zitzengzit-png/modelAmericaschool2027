%% P1: daily three-route SEIQRD fitting
% Run from ws/new/code:  run_p1_fit
% Writes ws/new/outputs/p1/P1_*.csv|json|png
clear; clc; close all;

cfg = config();
data = load_data(cfg);

fprintf('=== P1 daily three-route fit ===\n');
fprintf('fit     : %s .. %s (%d days)\n', ...
    string(cfg.fitStart, 'yyyy-MM-dd'), ...
    string(cfg.fitEnd, 'yyyy-MM-dd'), numel(data.t));
fprintf('holdout : %s .. %s (%d days)\n', ...
    string(cfg.holdStart, 'yyyy-MM-dd'), ...
    string(cfg.holdEnd, 'yyyy-MM-dd'), numel(data.holdout.t));
fprintf('knots   : %s, %s\n', ...
    string(cfg.betaKnots(1), 'yyyy-MM-dd'), ...
    string(cfg.betaKnots(2), 'yyyy-MM-dd'));

fit = fit_daily_seiqrd(data, cfg, struct('nStarts', 3, 'verbose', true, ...
    'fixRhoRep', true));
p = fit.params;
m = fit.metrics;

fprintf('\n=== fitted parameters ===\n');
fprintf('betaC0  : %.5f day^-1\n', p.betaC0);
fprintf('u1 / u2 : %.4f / %.4f\n', p.u1, p.u2);
fprintf('alpha0  : %.5f day^-1\n', p.alpha);
fprintf('mu      : %.5f day^-1\n', p.mu);
if fit.rhoRepMode
    rhoMode = 'fixed';
else
    rhoMode = 'estimated';
end
fprintf('rhoRep  : %.4f (%s)\n', p.rhoRep, rhoMode);
fprintf('fixed   : sigma %.3f, gamma %.3f, nu %.3f, rhoH0 %.2f, rhoF0 %.2f\n', ...
    p.sigma, p.gamma, p.nu, p.rhoH0, p.rhoF0);

fprintf('\n=== fit quality ===\n');
fprintf('daily   : R2 %.4f / %.4f, RMSE %.1f / %.1f\n', ...
    m.R2cases, m.R2deaths, m.RMSEcases, m.RMSEdeaths);
fprintf('weekly  : R2 %.4f / %.4f, RMSE %.1f / %.1f\n', ...
    m.weeklyR2cases, m.weeklyR2deaths, ...
    m.weeklyRMSEcases, m.weeklyRMSEdeaths);
fprintf('holdout : R2 %.4f / %.4f, RMSE %.1f / %.1f\n', ...
    m.holdoutR2cases, m.holdoutR2deaths, ...
    m.holdoutRMSEcases, m.holdoutRMSEdeaths);
fprintf('holdout : MAPE %.2f%% / %.2f%%, max %.2f%% / %.2f%%\n', ...
    m.holdoutMAPEcases, m.holdoutMAPEdeaths, ...
    m.holdoutMaxRelCases, m.holdoutMaxRelDeaths);
fprintf('CFR     : model %.4f, obs %.4f\n', m.CFRmodel, m.CFRobs);
fprintf('R0 early: %.3f = Rc %.3f + Rh %.3f + Rf %.3f\n', ...
    m.R0, m.Rc, m.Rh, m.Rf);
fprintf('R0 late : %.3f = Rc %.3f + Rh %.3f + Rf %.3f\n', ...
    m.R0late, m.RcLate, m.RhLate, m.RfLate);
fprintf('cost    : %.6g, success %d\n', fit.cost, fit.success);

% Reff(t) on the daily grid.
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
bc = arrayfun(fit.betaFun, data.daily.t);
Reff = fit.sim.y(:, 1) / p.N .* ( ...
    bc ./ a + p.alpha * p.rhoH0 * bc ./ (a * b) + ...
    (p.rhoF0 * bc ./ p.nu) .* ...
    (p.mu ./ a + p.alpha * p.muQ ./ (a * b)));

% -------------------------------------------------------------------------
% Tables
% -------------------------------------------------------------------------
writetable(m.params, fullfile(cfg.p1OutDir, 'P1_parameters.csv'));

phase = repmat("fit", numel(data.daily.date), 1);
phase(data.daily.date > cfg.fitEnd) = "holdout";
obs = table(data.daily.date, data.daily.cases, fit.Cpred, ...
    data.daily.deaths, fit.Mpred, phase, Reff, ...
    'VariableNames', {'date', 'cases_obs', 'cases_pred', ...
    'deaths_obs', 'deaths_pred', 'phase', 'Reff'});
writetable(obs, fullfile(cfg.p1OutDir, 'P1_observations.csv'));

Wk = data.seriesWeekly;
weekNewObs = [NaN; diff(Wk.cases)];
weekNewPred = [NaN; diff(m.CwPred)];
week = table(Wk.week, Wk.weekEnd, Wk.cases, m.CwPred, ...
    Wk.deaths, m.MwPred, weekNewObs, weekNewPred, ...
    'VariableNames', {'week', 'week_end', 'cases_obs', 'cases_pred', ...
    'deaths_obs', 'deaths_pred', 'weekly_new_obs', 'weekly_new_pred'});
writetable(week, fullfile(cfg.p1OutDir, 'P1_weekly_fit.csv'));

R0tab = table( ...
    ["R0_early"; "Rc_early"; "Rh_early"; "Rf_early"; ...
     "R0_late"; "Rc_late"; "Rh_late"; "Rf_late"; ...
     "betaC0"; "betaC_late"; "alpha0"; "mu"; "rhoRep"], ...
    [m.R0; m.Rc; m.Rh; m.Rf; m.R0late; m.RcLate; m.RhLate; m.RfLate; ...
     p.betaC0; p.betaC0 * (1 - p.u1) * (1 - p.u2); ...
     p.alpha; p.mu; p.rhoRep], ...
    'VariableNames', {'item', 'value'});
writetable(R0tab, fullfile(cfg.p1OutDir, 'P1_R0_channels.csv'));

% JSON summary (drop the table field, add as struct array).
out = rmfield(m, 'params');
out.params = table2struct(m.params);
out.q = fit.q;
out.y0 = fit.y0;
out.cost = fit.cost;
out.success = fit.success;
out.rhoRepMode = fit.rhoRepMode;
out.allowRebound = fit.allowRebound;
out.fit_start = string(cfg.fitStart, 'yyyy-MM-dd');
out.fit_end = string(cfg.fitEnd, 'yyyy-MM-dd');
out.hold_start = string(cfg.holdStart, 'yyyy-MM-dd');
out.hold_end = string(cfg.holdEnd, 'yyyy-MM-dd');
out.knots = [string(cfg.betaKnots(1), 'yyyy-MM-dd'); ...
    string(cfg.betaKnots(2), 'yyyy-MM-dd')];
out.init_source = fit.init.source;
out.E0 = fit.init.E0;
out.D0 = fit.init.D0;

fid = fopen(fullfile(cfg.p1OutDir, 'P1_metrics.json'), 'w');
fprintf(fid, '%s', jsonencode(out, 'PrettyPrint', true));
fclose(fid);

% -------------------------------------------------------------------------
% Figure: cumulative cases/deaths, weekly incidence, Reff
% -------------------------------------------------------------------------
fig = figure('Color', 'w', 'Position', [80 80 1200 860]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(data.daily.date, data.daily.cases, 'ko', 'MarkerSize', 3, ...
    'DisplayName', 'Observed'); hold on;
plot(data.daily.date, fit.Cpred, 'r-', 'LineWidth', 1.8, ...
    'DisplayName', 'Model');
xline(cfg.fitEnd, 'k--', 'fit end');
xlabel('Date'); ylabel('Cumulative confirmed cases');
title('(a) Cumulative cases'); grid on; box off;
legend('Location', 'northwest'); legend boxoff;
xtickformat('MM-dd');

nexttile;
plot(data.daily.date, data.daily.deaths, 'ko', 'MarkerSize', 3, ...
    'DisplayName', 'Observed'); hold on;
plot(data.daily.date, fit.Mpred, 'r-', 'LineWidth', 1.8, ...
    'DisplayName', 'Model');
xline(cfg.fitEnd, 'k--', 'fit end');
xlabel('Date'); ylabel('Cumulative deaths');
title('(b) Cumulative deaths'); grid on; box off;
legend('Location', 'northwest'); legend boxoff;
xtickformat('MM-dd');

nexttile;
bar(Wk.weekEnd, weekNewObs, 0.6, 'FaceColor', [0.62 0.79 0.88], ...
    'EdgeColor', [0.29 0.56 0.76], 'DisplayName', 'Observed');
hold on;
plot(Wk.weekEnd, weekNewPred, 'r-o', 'LineWidth', 1.5, ...
    'MarkerSize', 4, 'DisplayName', 'Model');
xline(cfg.fitEnd, 'k--', 'fit end');
xlabel('Date'); ylabel('Weekly new cases');
title('(c) Weekly incidence'); grid on; box off;
legend('Location', 'northeast'); legend boxoff;
xtickformat('MM-dd');

nexttile;
plot(data.daily.date, Reff, 'b-', 'LineWidth', 1.8, ...
    'DisplayName', 'R_{eff}');
hold on; yline(1, 'k--', 'LineWidth', 1.0, 'DisplayName', 'R=1');
xline(cfg.betaKnots(1), ':', 'knot 1', 'Color', [0.4 0.4 0.4]);
xline(cfg.betaKnots(2), ':', 'knot 2', 'Color', [0.4 0.4 0.4]);
xline(cfg.fitEnd, 'k--', 'fit end');
xlabel('Date'); ylabel('R_{eff}(t)');
title('(d) Effective reproduction number'); grid on; box off;
legend('Location', 'northwest'); legend boxoff;
xtickformat('MM-dd');

sgtitle('P1: daily three-route SEIQRD fit', ...
    'FontSize', 13, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(cfg.p1OutDir, 'P1_fit.png'), ...
    'Resolution', 300);

fprintf('\nSaved P1 outputs to %s\n', cfg.p1OutDir);
