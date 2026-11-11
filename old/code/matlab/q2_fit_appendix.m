%% Q2 appendix: weighted least-squares fit with five parameters
% Extracted from the reference docx appendix and adapted to the current
% data loader and output folder. The main fit used by the project is
% q2_fit.m (four parameters with nu fixed); this script preserves the
% appendix variant, which puts nu in the parameter vector with a very
% tight bound so that nu is effectively fixed but explicit.
%
% Run from ws/src/matlab:  q2_fit_appendix
clear; clc; close all;

root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % ws
outDir = fullfile(root, 'outputs', 'matlab');
if ~exist(outDir, 'dir'), mkdir(outDir); end

data = load_data();
p0 = default_params(data);

t = data.t;
C_obs = data.cases;
M_obs = data.deaths;
N = data.N;
C0 = data.C0;
M0 = data.M0;
Q0 = data.Q0;
Rc0 = data.R0;
I0 = data.I0;
E0 = data.E0;
D0 = data.D0;
S0 = data.S0;

sigma = p0.sigma;
gamma = p0.gamma;
gammaQ = p0.gammaQ;
kappa = p0.kappa;
nu0 = p0.nu;

% tau is the change point; W25 is t=0, so W26-W38 is t=1..13.
tauGrid = (1:13)';

% q = [beta0, beta1, alpha, mu, nu]
lb = [0.05, 0.05, 0.50, 0.05, nu0 - 1e-6];
ub = [3.00, 3.00, 3.50, 0.50, nu0 + 1e-6];
q0List = [0.60, 0.35, 1.50, 0.21, nu0;
          0.40, 0.20, 1.00, 0.20, nu0;
          0.90, 0.50, 2.00, 0.25, nu0];

opts = optimoptions('lsqnonlin', 'Display', 'off', ...
    'MaxFunctionEvaluations', 3000, 'MaxIterations', 1500);

bestSSE = inf;
bestQ = [];
bestTau = [];
for tau = tauGrid'
    for k = 1:size(q0List, 1)
        obj = @(q) residual_q2_weekly(q, tau, t, C_obs, M_obs, N, ...
            S0, E0, I0, Q0, Rc0, D0, M0, ...
            sigma, gamma, gammaQ, kappa);
        [qfit, resnorm] = lsqnonlin(obj, q0List(k, :), lb, ub, opts);
        if resnorm < bestSSE
            bestSSE = resnorm;
            bestQ = qfit;
            bestTau = tau;
        end
    end
end

beta0 = bestQ(1);
beta1 = bestQ(2);
alpha = bestQ(3);
mu = bestQ(4);
nu = bestQ(5);
muQ = mu;
tau = bestTau;

if abs(beta0 - ub(1)) < 1e-3
    warning('beta0 reached its upper bound; check starting values or model.');
end
if tau == tauGrid(1)
    warning('tau reached the lower grid bound; the change point may be outside the search range.');
end

Y = simulate_q2(bestQ, bestTau, t, N, ...
    S0, E0, I0, Q0, Rc0, D0, M0, ...
    sigma, gamma, gammaQ, kappa);
C_model = Y(:,3) + Y(:,4) + Y(:,5) + Y(:,7);
M_model = Y(:,7);

% R0 and Rt
beta_t = beta0 * (t < tau) + beta1 * (t >= tau);
R0_t = beta_t ./ (alpha + gamma + mu) ...
    + (beta_t * kappa / nu) .* ( ...
    mu ./ (alpha + gamma + mu) ...
    + alpha * muQ ./ ((alpha + gamma + mu) * (gammaQ + muQ)));
Rt = R0_t .* Y(:,1) / N;
R0_baseline = beta0 / (alpha + gamma + mu) ...
    + (beta0 * kappa / nu) * ( ...
    mu / (alpha + gamma + mu) ...
    + alpha * muQ / ((alpha + gamma + mu) * (gammaQ + muQ)));

% Weekly incidence and flattening week
newC_obs = diff(C_obs);
newC_model = diff(C_model);
t_new = t(2:end);
[peakC, idxPeak] = max(newC_obs);
weekPeak = 26 + (idxPeak - 1);
ma_obs = movmean(newC_obs, 3);
[peakMA, idxMA] = max(ma_obs);
weekMA = 26 + (idxMA - 1);

flatWeek = NaN;
for i = 1:numel(Rt) - 2
    if all(Rt(i:i+2) < 1)
        flatWeek = 25 + (i - 1);
        break;
    end
end

fprintf('\n=== Q2 appendix fit ===\n');
fprintf('tau              : W%d (t=%d)\n', 25 + tau, tau);
fprintf('beta0 / beta1    : %.4f / %.4f per week\n', beta0, beta1);
fprintf('alpha / mu       : %.4f / %.4f per week\n', alpha, mu);
fprintf('nu               : %.4f per week\n', nu);
fprintf('R0 (beta0)       : %.3f\n', R0_baseline);
fprintf('CFR model        : %.3f\n', M_model(end) / C_model(end));
fprintf('Weekly peak      : W%d, %d cases\n', weekPeak, peakC);
fprintf('3-week mean peak : W%d, %.1f cases\n', weekMA, peakMA);
if isnan(flatWeek)
    fprintf('Rt did not stay below 1 for three weeks.\n');
else
    fprintf('Rt<1 for three weeks from W%d.\n', flatWeek);
end

R2_C = 1 - sum((C_obs - C_model).^2) / sum((C_obs - mean(C_obs)).^2);
R2_M = 1 - sum((M_obs - M_model).^2) / sum((M_obs - mean(M_obs)).^2);
RMSE_C = sqrt(mean((C_obs - C_model).^2));
RMSE_M = sqrt(mean((M_obs - M_model).^2));
RMSE_W = sqrt(mean((diff(C_model) - diff(C_obs)).^2));
fprintf('R2 cases / deaths: %.4f / %.4f\n', R2_C, R2_M);
fprintf('RMSE C / M / W   : %.1f / %.1f / %.1f\n', RMSE_C, RMSE_M, RMSE_W);

paramTable = table( ...
    ["beta0"; "beta1"; "tau"; "alpha"; "mu"; "nu"; "R0"], ...
    [beta0; beta1; tau; alpha; mu; nu; R0_baseline], ...
    ["week^-1"; "week^-1"; "week index"; "week^-1"; "week^-1"; "week^-1"; "-"], ...
    'VariableNames', {'parameter', 'estimate', 'unit'});
writetable(paramTable, fullfile(outDir, 'q2_appendix_parameters.csv'));

obsTable = table(t, 25 + t, C_obs, C_model, M_obs, M_model, ...
    [NaN; newC_obs], [NaN; newC_model], ...
    'VariableNames', {'t', 'week', 'cases_obs', 'cases_fit', ...
    'deaths_obs', 'deaths_fit', 'weekly_obs', 'weekly_fit'});
writetable(obsTable, fullfile(outDir, 'q2_appendix_observations.csv'));

fig = figure('Color', 'w', 'Position', [80 80 1120 820]);
tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plot(25 + t, C_obs, 'ko', 'MarkerSize', 5, 'MarkerFaceColor', 'k'); hold on;
plot(25 + t, C_model, 'r-', 'LineWidth', 1.8);
xlabel('Week (W25 = 25)'); ylabel('Cumulative confirmed cases');
title('(a) Cumulative cases'); grid on; box off;
legend('Observed', 'Fitted', 'Location', 'northwest'); legend boxoff;

nexttile;
plot(25 + t, M_obs, 'ko', 'MarkerSize', 5, 'MarkerFaceColor', 'k'); hold on;
plot(25 + t, M_model, 'r-', 'LineWidth', 1.8);
xlabel('Week (W25 = 25)'); ylabel('Cumulative deaths');
title('(b) Cumulative deaths'); grid on; box off;

nexttile;
bar(25 + t_new, newC_obs, 0.65, 'FaceColor', [0.62 0.79 0.88], ...
    'EdgeColor', [0.29 0.56 0.76]); hold on;
plot(25 + t_new, newC_model, 'r-o', 'LineWidth', 1.6, 'MarkerSize', 3.5);
xlabel('Week (W25 = 25)'); ylabel('Weekly new cases');
title('(c) Weekly incidence'); grid on; box off;
legend('Observed', 'Fitted', 'Location', 'northeast'); legend boxoff;

nexttile;
plot(25 + t, Rt, 'b-', 'LineWidth', 1.8); hold on;
yline(1, 'k--', 'LineWidth', 1.0);
xline(25 + tau, ':', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.0);
xlabel('Week (W25 = 25)'); ylabel('R_t');
title('(d) Effective reproduction number'); grid on; box off;

sgtitle(sprintf('Q2 appendix fit: SEIQRD model, W%d-W%d', ...
    data.week(1), data.week(end)), 'FontSize', 13, 'FontWeight', 'bold');
exportgraphics(fig, fullfile(outDir, 'fig_q2_appendix_fit.png'), 'Resolution', 300);
fprintf('Saved Q2 appendix outputs to %s\n', outDir);


%% Local functions
function res = residual_q2_weekly(q, tau, t, C_obs, M_obs, N, ...
    S0, E0, I0, Q0, Rc0, D0, M0, sigma, gamma, gammaQ, kappa)

Y = simulate_q2(q, tau, t, N, ...
    S0, E0, I0, Q0, Rc0, D0, M0, ...
    sigma, gamma, gammaQ, kappa);
C_model = Y(:,3) + Y(:,4) + Y(:,5) + Y(:,7);
M_model = Y(:,7);

rC = (C_model - C_obs) ./ max(C_obs, 50);
rM = (M_model - M_obs) ./ max(M_obs, 20);
CFR_model = M_model(end) / C_model(end);
CFR_obs = M_obs(end) / C_obs(end);
rCFR = 5 * (CFR_model - CFR_obs);
rW = (diff(C_model) - diff(C_obs)) ./ max(diff(C_obs), 30);
rMw = 0.5 * (diff(M_model) - diff(M_obs)) ./ max(diff(M_obs), 15);
res = [rC; rM; rW; rMw; rCFR];
end

function Y = simulate_q2(q, tau, t, N, ...
    S0, E0, I0, Q0, Rc0, D0, M0, sigma, gamma, gammaQ, kappa)

beta0 = q(1);
beta1 = q(2);
alpha = q(3);
mu = q(4);
nu = q(5);
muQ = mu;
y0 = [S0; E0; I0; Q0; Rc0; D0; M0];
odeopt = odeset('RelTol', 1e-7, 'AbsTol', 1e-9);

t1 = 0:0.05:tau;
[t1, Y1] = ode45(@(tt, y) ode_q2(tt, y, beta0, ...
    alpha, mu, muQ, nu, sigma, gamma, gammaQ, kappa, N), ...
    t1, y0, odeopt);

ytau = Y1(end, :);
t2 = tau:0.05:t(end);
[t2, Y2] = ode45(@(tt, y) ode_q2(tt, y, beta1, ...
    alpha, mu, muQ, nu, sigma, gamma, gammaQ, kappa, N), ...
    t2, ytau, odeopt);

tf = [t1; t2(2:end)];
Yf = [Y1; Y2(2:end, :)];
Y = interp1(tf, Yf, t, 'linear');
end

function dydt = ode_q2(~, y, beta, ...
    alpha, mu, muQ, nu, sigma, gamma, gammaQ, kappa, N)

S = y(1);
E = y(2);
I = y(3);
Q = y(4);
D = y(6);

foi = beta * S * (I + kappa * D) / N;
dydt = [ ...
    -foi; ...
    foi - sigma * E; ...
    sigma * E - (alpha + gamma + mu) * I; ...
    alpha * I - (gammaQ + muQ) * Q; ...
    gamma * I + gammaQ * Q; ...
    mu * I + muQ * Q - nu * D; ...
    mu * I + muQ * Q];
end

