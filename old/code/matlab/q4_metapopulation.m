%% Q4: seven-province SEIQRD metapopulation model
% Extracted from the reference docx appendix and cleaned to ASCII-only
% MATLAB. Run from ws/src/matlab:  q4_metapopulation
%
% NOTE: the province list and initial state below are the reference W41 /
% 7-province snapshot. Q1/Q2 have been switched to the 2026-11-08 tracker
% source (8 provinces / 67 zones, W45); Q4 has not yet been extended to that
% latest spatial snapshot. Treat the scenario numbers as legacy reference
% results until the 8-province/W45 initial state is wired in.
%
% The model copies the Q1 SEIQRD states in each province, connects the
% provinces with a row-normalised adjacency matrix, and adds:
%   - inter-provincial movement of S, E, I and R (Q and D stay local);
%   - a treatment-capacity ceiling on the admission rate;
%   - a province-level ring-vaccination protection factor;
%   - ten policy scenarios, including a 15% beta rebound stress test.
%
% All outputs are written to ws/outputs/matlab.
clear; clc; close all;
set(0, 'defaultFigureColor', 'w', 'defaultAxesFontSize', 10, ...
    'defaultAxesBox', 'on');

root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % ws
outDir = fullfile(root, 'outputs', 'matlab');
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% 1. Provinces and W41 initial state
name = ["Ituri"; "Nord-Kivu"; "Haut-Uele"; "Tshopo"; ...
    "Sud-Kivu"; "Bas-Uele"; "Sud-Ubangi"];
n = numel(name);

N = [6556455; 9095202; 3361576; 4159613; 7879065; 2032860; 3808453];
C0 = [6695; 1911; 383; 59; 3; 13; 2];
M0 = [3099; 1092; 162; 22; 1; 4; 1];
new0 = [245; 182; 24; 9; 0; 3; 0];

% The W41 report gives 895 patients in isolation and 2,389 cumulative
% recoveries. Unobserved state variables are allocated by province burden.
w = max(new0, 1);
w = w / sum(w);
Q0 = 895 * w;
Rc0 = 2389 * (C0 / sum(C0));
I0 = max(C0 - M0 - Q0 - Rc0, 0);
E0 = new0 / 0.70;                       % weekly new cases x mean incubation
D0 = (2 / 7) * [131; 87; 10; 5; 0; 0; 0]; % two-day unburied approximation
S0 = N - E0 - I0 - Q0 - Rc0 - D0 - M0;

assert(all(S0 > 0), 'Initial state must be non-negative.');
y0 = [S0; E0; I0; Q0; Rc0; D0; M0];

%% 2. Epidemiological parameters
p.sigma = 0.70;
p.gamma = 0.21;
p.gammaQ = 0.21;
p.mu = 0.235;
p.muQ = 0.235;
p.kappa = 3;
p.alpha = 1.244;
p.nu = 3.5;
p.N = N;
p.beta = 0.847 * ones(n, 1);   % post-W32 fitted transmission rate
p.mobility = 0.015;            % assumed weekly inter-provincial mobility
p.T = 24;                      % 24-week projection

% W is a transparent adjacency proxy, not an observed OD matrix.
% Rows are origins, columns are destinations.
W = zeros(n);
edge = [1 2; 1 3; 1 4; 2 3; 2 4; 2 5; 3 4; 3 6; 4 6; 4 7; 5 4; 6 7];
for k = 1:size(edge, 1)
    W(edge(k,1), edge(k,2)) = 1;
    W(edge(k,2), edge(k,1)) = 1;
end
W = W ./ max(sum(W, 2), 1);
p.W = W;

% W41 system-wide bed capacity is 1,539. The fitted alpha already reflects
% current admission capacity, so K is a high surge warning threshold.
active = I0 + Q0;
p.K = 100 * 1539 * active / sum(active);
p.vax = zeros(n, 1);
p.phi = zeros(n, 1);

%% 3. Scenarios
% "Rebound" means a 15% unfavourable increase in beta after relaxation;
% it is a robustness stress test, not a forecast.
S(1)  = makeScenario('Current fitted control', 1, 1, 1, 0, 0, 0);
S(2)  = makeScenario('Travel restriction only', 0.30, 1, 1, 0, 0, 0);
S(3)  = makeScenario('Resource scaling only', 1, 1, 1, 1.00, 0, 0);
S(4)  = makeScenario('Safe burial only', 1, 2, 1, 0, 0, 0);
S(5)  = makeScenario('Ring vaccination only', 1, 1, 1, 0, 0, 0.10);
S(6)  = makeScenario('Rebound, no action', 1, 1, 1.15, 0, 0, 0);
S(7)  = makeScenario('Rebound, travel restriction only', 0.30, 1, 1.15, 0, 0, 0);
S(8)  = makeScenario('Rebound, resource scaling only', 1, 1, 1.15, 1.00, 0, 0);
S(9)  = makeScenario('Rebound, safe burial only', 1, 2, 1.15, 0, 0, 0);
S(10) = makeScenario('Rebound, combination package', 0.40, 1.50, 1.15, 0.60, 0.10, 0.10);

%% 4. Integrate and compute policy indicators
Z = cell(numel(S), 1);
rows = cell(numel(S), 1);
for k = 1:numel(S)
    [t, Y] = ode15s(@(tt, yy) rhs(tt, yy, p, S(k)), [0 p.T], y0, ...
        odeset('RelTol', 1e-8, 'AbsTol', 1e-6, ...
        'NonNegative', 1:(7 * n), 'MaxStep', 0.1));
    Z{k} = struct('t', t, 'Y', Y, 'scenario', S(k));
    [tot, seeded, peak, peakweek, Reff0] = indicators(t, Y, p, S(k));
    rows{k} = table(string(S(k).name), tot, seeded, peak, peakweek, Reff0, ...
        'VariableNames', {'Scenario', 'CumulativeCasesW65', ...
        'DeathsOutsideIturi', 'PeakWeeklyCases', ...
        'PeakWeekFromW41', 'InitialNetworkRe'});
end

T = vertcat(rows{:});
disp(T);
writetable(T, fullfile(outDir, 'Q4_scenario_results.csv'));

%% 5. Figures
plotTotals(Z);
exportgraphics(gcf, fullfile(outDir, 'Q4_total_cases.png'), 'Resolution', 300);
plotMapBurden(Z, name);
exportgraphics(gcf, fullfile(outDir, 'Q4_provincial_burden.png'), 'Resolution', 300);
fprintf('Saved Q4 outputs to %s\n', outDir);


%% Local functions
function s = makeScenario(name, mob, burial, betaScale, resource, phi, vax)
s.name = name;
s.mob = mob;
s.burial = burial;
s.betaScale = betaScale;
s.resource = resource;
s.phi = phi;
s.vax = vax;
end

function dy = rhs(~, y, p, s)
n = numel(p.N);
Y = reshape(y, n, 7);
S = Y(:,1); E = Y(:,2); I = Y(:,3);
Ql = Y(:,4); D = Y(:,6);

beta = p.beta * s.betaScale .* (1 - s.phi);
nu = p.nu * s.burial;

% Resource scaling shortens the admission delay. The capacity term stops
% the admission rate from being extrapolated without limit during a surge.
ae = p.alpha * (1 + s.resource) .* min(1, p.K ./ max(I + Ql, 1));

% Ring vaccination is represented as a protection factor for identified
% contacts in active provinces. It does not enter R, so vaccinated persons
% are not misclassified as recovered cases.
ring = s.vax * (I + Ql > 0);
lam = beta .* (1 - ring) .* S .* (I + p.kappa * D) ./ p.N;

dS = -lam;
dE = lam - p.sigma * E;
dI = p.sigma * E - (ae + p.gamma + p.mu) .* I;
dQ = ae .* I - (p.gammaQ + p.muQ) .* Ql;
dR = p.gamma * I + p.gammaQ * Ql;
dD = p.mu * I + p.muQ * Ql - nu .* D;
dM = p.mu * I + p.muQ * Ql;

% S, E, I and R move between provinces; Q and D stay local.
for c = [1 2 3 5]
    x = Y(:,c);
    move = s.mob * (p.W' * x - sum(p.W, 2) .* x);
    switch c
        case 1, dS = dS + move;
        case 2, dE = dE + move;
        case 3, dI = dI + move;
        case 5, dR = dR + move;
    end
end

dy = reshape([dS dE dI dQ dR dD dM], 7 * n, 1);
end

function [tot, seeded, peak, pweek, Re0] = indicators(t, Y, p, s)
n = numel(p.N);
A = reshape(Y, [], n, 7);
C = squeeze(A(:,:,3) + A(:,:,4) + A(:,:,5) + A(:,:,7));
Ct = sum(C, 2);
W = 0:1:p.T;
Cw = interp1(t, Ct, W, 'pchip');
nw = diff(Cw);

tot = Cw(end);
seeded = sum(A(end, 2:end, 7));
[peak, ii] = max(nw);
pweek = ii;

a = p.alpha + p.gamma + p.mu;
Re0 = mean((1 - s.vax) * p.beta * s.betaScale * (1 - s.phi) ./ a + ...
    (1 - s.vax) * p.beta * s.betaScale * (1 - s.phi) * p.kappa * p.mu ./ ...
    (p.nu * s.burial * (p.gamma + p.mu)));
end


function plotTotals(Z)
figure('Position', [80 80 980 540]); hold on; grid on;
pick = [1 2 3 4 5 6 7 8 9 10];

cc = [0.00 0.45 0.74;   % 1 current fitted control (blue)
      0.85 0.33 0.10;   % 2 travel restriction only (orange-red)
      0.93 0.69 0.13;   % 3 resource scaling only (gold)
      0.49 0.18 0.56;   % 4 safe burial only (purple)
      0.47 0.67 0.19;   % 5 ring vaccination only (green)
      0.30 0.75 0.93;   % 6 rebound, no action (light blue)
      0.64 0.08 0.18;   % 7 rebound, travel restriction only (dark red)
      0.95 0.35 0.65;   % 8 rebound, resource scaling only (magenta)
      0.00 0.55 0.45;   % 9 rebound, safe burial only (teal)
      0.55 0.35 0.10];  % 10 rebound, combination package (brown)
ls = [repmat({'-'}, 5, 1); repmat({'--'}, 5, 1)];

% W25-W41 observed points; W41 end date is the scenario start.
t0 = datetime(2026, 10, 11);
obsDates = t0 - days(7 * (16:-1:0));
obsCases = [1193 1453 1826 2180 2640 3255 3755 4330 4987 ...
    5536 6103 6688 7260 7735 8118 8603 9066];
plot(obsDates, obsCases, 'ko--', 'LineWidth', 1.4, 'MarkerSize', 4, ...
    'MarkerFaceColor', 'k', 'DisplayName', 'W25-W41 observed cases');

for q = 1:numel(pick)
    z = Z{pick(q)};
    n = size(z.Y, 2) / 7;
    A = reshape(z.Y, [], n, 7);
    C = sum(A(:,:,3) + A(:,:,4) + A(:,:,5) + A(:,:,7), 2);
    dates = t0 + days(7 * z.t);
    plot(dates, C, 'LineWidth', 1.7, 'Color', cc(q,:), ...
        'LineStyle', ls{q}, 'DisplayName', z.scenario.name);
end

xlabel('Date (W25-W41 observed; W42+ scenario)');
ylabel('Cumulative confirmed cases');
xtickformat('MM-dd');
title('Q4: observed cases and inter-provincial scenarios');
legend('Location', 'northwest', 'FontSize', 8);
end

function plotMapBurden(Z, name)
figure('Position', [80 80 980 480]);
ids = [6 10];
titles = {'Rebound, no action', 'Rebound, combination package'};

for k = 1:2
    z = Z{ids(k)};
    n = numel(name);
    A = reshape(z.Y, [], n, 7);
    C0 = A(1,:,3) + A(1,:,4) + A(1,:,5) + A(1,:,7);
    Ce = A(end,:,3) + A(end,:,4) + A(end,:,5) + A(end,:,7);
    subplot(1, 2, k);
    bar(Ce(:) - C0(:));
    grid on;
    set(gca, 'XTick', 1:n, 'XTickLabel', name, 'XTickLabelRotation', 35);
    ylabel('24-week new cases');
    title(titles{k});
end

sgtitle('Q4: provincial 24-week new cases');
end

