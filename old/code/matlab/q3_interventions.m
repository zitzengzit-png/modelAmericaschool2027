%% Q3: single-factor and combined intervention analysis
% Extracted from the reference docx appendix (Q3_final.m) and cleaned to
% ASCII-only MATLAB. Run from ws/src/matlab:  q3_interventions
%
% NOTE: the parameter block below is the reference W41 / 7-province baseline.
% Q1/Q2 have been switched to the 2026-11-08 tracker source (W25-W45); Q3 has
% not yet been refitted to those latest parameters. Recompute p.beta0/beta1/
% alpha/mu and the initial state before presenting Q3 as a current result.
%
% The model is the same SEIQRD model as Q1/Q2. Four intervention levers
% are mapped to model parameters:
%   case isolation        -> alpha = 7 / d_alpha
%   safe burial           -> nu    = 7 / d_nu
%   risk communication    -> beta  = beta * (1 - phi_C)
%   contact tracing       -> alpha = 7 / ((1-phi_T) d_alpha + phi_T d_T)
%
% All outputs are written to ws/outputs/matlab.
clear; clc; close all;
set(0, 'defaultFigureColor', 'w', 'defaultAxesFontSize', 10, ...
    'defaultAxesLineWidth', 0.9, 'defaultAxesBox', 'on');

root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % ws
outDir = fullfile(root, 'outputs', 'matlab');
if ~exist(outDir, 'dir'), mkdir(outDir); end

%% 1. Baseline parameters (from Q2)
p.beta0 = 1.298;  p.beta1 = 0.847;  p.tau = 7;    % t=0 <-> W25, W32 <-> t=7
p.kappa = 3.0;    p.sigma = 0.70;
p.alpha = 1.244;  p.gamma = 0.21;   p.mu = 0.235;
p.gammaQ = 0.21;  p.muQ = 0.235;
p.nu = 3.5;       p.N = 36893224;
p.E0 = 300; p.I0 = 350; p.Q0 = 196; p.Rc0 = 112; p.D0 = 20; p.M0 = 535;
p.S0 = p.N - p.M0 - (p.E0 + p.I0 + p.Q0 + p.Rc0);
p.y0 = [p.S0; p.E0; p.I0; p.Q0; p.Rc0; p.D0; p.M0];
p.tObs = 16;  p.Tend = 27;  p.dT = 1.0;   % W41 / W52 / tracing delay (days)

%% 2. Baseline and self-check
B = simu(p, p.alpha, p.nu, 0, 0);
a0 = p.alpha + p.gamma + p.mu;
G = 1 / a0 + p.kappa * p.mu / (p.nu * (p.gamma + p.mu));
dA0 = 7 / p.alpha;
dNu0 = 7 / p.nu;

fprintf('\n=== baseline ===\n');
fprintf('C41 = %.0f (obs 9066, dev %+.1f%%) | C52 = %.0f\n', ...
    B.C41, 100 * (B.C41 - 9066) / 9066, B.C52);
fprintf('weekly peak = %.0f @W%d (obs 657 @W33) | Imax = %.0f\n', ...
    B.peakNew, B.peakWeek, B.Imax);
fprintf('R0(beta0) = %.3f | R0(beta1) = %.3f | G = %.4f | D-only floor = %.3f\n', ...
    B.R0a, B.R0b, G, p.beta0 * p.kappa * p.mu / (p.nu * (p.gamma + p.mu)));
fprintf('current delays: d_alpha = %.2f d, d_nu = %.2f d\n', dA0, dNu0);
if abs(B.C41 - 9066) / 9066 > 0.10
    warning('baseline C41 deviates >10%%; check beta/kappa/nu and y0.');
end

%% 3. One-factor sweeps
dA = 6:-0.25:2;
dNu = 7:-0.25:1;
phiC = 0:0.02:0.60;
phiT = 0:0.02:0.80;

S.alpha = sweepX(@(x) simu(p, 7 / x, p.nu, 0, 0), dA);
S.nu = sweepX(@(x) simu(p, p.alpha, 7 / x, 0, 0), dNu);
S.phiC = sweepX(@(x) simu(p, p.alpha, p.nu, x, 0), phiC);
S.phiT = sweepX(@(x) simu(p, p.alpha, p.nu, 0, x), phiT);

fprintf('\n=== crossing points (R0=1) ===\n');
printCross('isolation d_alpha', S.alpha.x, S.alpha);
printCross('safe burial d_nu', S.nu.x, S.nu);
printCross('communication phi_C', S.phiC.x, S.phiC);
printCross('tracing phi_T', S.phiT.x, S.phiT);
fprintf('\nsanity check on burial axis:\n');
fprintf('  min R0 = %.4f (should be >1, no crossing)\n', min(S.nu.R0a));
fprintf('  C52 at d_nu=%.2f: %.0f | at d_nu=%.2f: %.0f | baseline: %.0f\n', ...
    S.nu.x(1), S.nu.C52(1), S.nu.x(end), S.nu.C52(end), B.C52);
assert(S.nu.C52(1) < S.nu.C52(end), 'burial axis: C52 must rise with delay');

%% 4. Fig 3-1: one-factor response
f1 = figure('Position', [60 60 960 760], 'Name', 'Fig3-1');
yl = [-100 25];
chN = S.nu.C52 ./ B.C52 - 1;
iOut = find(chN > yl(2) / 100);
if isempty(iOut)
    noteB = '';
else
    dOut = min(S.nu.x(iOut));
    noteB = {sprintf('d_\\nu > %.2f d: off-scale', dOut), ...
        '(burial-disruption scenario)'};
end

panel(1, S.alpha, 'Admission delay d_\alpha (days)', '(a) Case isolation', ...
    B, true, yl, '');
panel(2, S.nu, 'Safe-burial delay d_\nu (days)', '(b) Safe burial', ...
    B, true, yl, noteB);
panel(3, S.phiC, 'Contact-rate reduction \phi_C', '(c) Risk communication', ...
    B, false, yl, '');
panel(4, S.phiT, 'Contact-rate reduction \phi_T', '(d) Contact tracing', ...
    B, false, yl, '');
exportgraphics(f1, fullfile(outDir, 'Fig3-1_one_factor.png'), 'Resolution', 300);

%% 5. Fig 3-2: isolation vs burial
boxAN = [3, 1.5, dA0 - 3, dNu0 - 1.5];
[DA, DNU] = meshgrid(dA, dNu);
[R0g2, Cg2] = grid2d(p, DA, DNU, 'AN');
heatF(DA, DNU, Cg2, R0g2, 'Admission delay d_\alpha (days)', ...
    'Safe-burial delay d_\nu (days)', 'C_{52} (thousands)', ...
    fullfile(outDir, 'Fig3-2_isolation_burial'), boxAN);

%% 6. Fig 3-3: communication vs burial
boxCN = [0, 1.5, 0.30, dNu0 - 1.5];
[PC, DNU2] = meshgrid(phiC, dNu);
[R0g3, Cg3] = grid2d(p, PC, DNU2, 'CN');
heatF(PC, DNU2, Cg3, R0g3, 'Contact-rate reduction \phi_C', ...
    'Safe-burial delay d_\nu (days)', 'C_{52} (thousands)', ...
    fullfile(outDir, 'Fig3-3_communication_burial'), boxCN);

%% 7. Fig 3-4: communication vs isolation
boxCA = [0, 3, 0.30, dA0 - 3];
[PA, DA2] = meshgrid(phiC, dA);
[R0g4, Cg4] = grid2d(p, PA, DA2, 'CA');
heatF(PA, DA2, Cg4, R0g4, 'Contact-rate reduction \phi_C', ...
    'Admission delay d_\alpha (days)', 'C_{52} (thousands)', ...
    fullfile(outDir, 'Fig3-4_communication_isolation'), boxCA);

%% 8. Criteria table
c0 = critAll(p, p.beta0);
c1 = critAll(p, p.beta1);
Ea = -p.alpha / (a0^2 * G);
En = -(p.kappa * p.mu / (p.nu * (p.gamma + p.mu))) / G;
dRdA = p.beta0 * 7 / (a0^2 * dA0^2);
dRdN = p.beta0 * p.kappa * p.mu / (7 * (p.gamma + p.mu));

nm = ["G"; "R0_beta0"; "R0_beta1"; "D_only_floor_beta0"; "D_only_floor_beta1"; ...
    "E_beta"; "E_alpha"; "E_nu"; "abs_En_over_Ea"; ...
    "dR0_dd_alpha"; "dR0_dd_nu"; "ratio_nu_over_alpha"; ...
    "d_alpha_crit_beta0"; "d_nu_crit_beta0"; "phiC_crit_beta0"; "phiT_crit_beta0"; ...
    "d_alpha_crit_beta1"; "d_nu_crit_beta1"; "d_alpha_now"; "d_nu_now"];
vl = [G; c0.R0; c1.R0; c0.pc; c1.pc; 1; Ea; En; abs(En / Ea); dRdA; dRdN; ...
    dRdN / dRdA; c0.dac; c0.dnuc; c0.phic; c0.phiT; c1.dac; c1.dnuc; dA0; dNu0];
Crit = table(nm, vl, 'VariableNames', {'Item', 'Value'});
fprintf('\n=== criteria ===\n');
disp(Crit);
writetable(Crit, fullfile(outDir, 'Q3_criteria.csv'));


%% 9. Combination grid
dAg = [6 5 4.5 4 3.5 3 2.5 2];
dNg = [7 5 4 3 2 1.5 1];
pCg = [0 0.1 0.2 0.3];
pTg = [0 0.2 0.4];
[A1, A2, A3, A4] = ndgrid(dAg, dNg, pCg, pTg);
nG = numel(A1);
dAv = A1(:); dNv = A2(:); pCv = A3(:); pTv = A4(:);
R0v = zeros(nG, 1);
for k = 1:nG
    ae = alphaEff(p, 7 / dAv(k), pTv(k));
    R0v(k) = R0f(p.beta0 * (1 - pCv(k)), ae, p.gamma, p.mu, ...
        p.gammaQ, p.muQ, 7 / dNv(k), p.kappa);
end

feas = dAv >= 3 & dAv <= dA0 & dNv >= 1.5 & dNv <= dNu0 ...
    & pCv <= 0.30 & pTv <= 0.30;
selF = (R0v < 1) & feas;
selA = R0v < 1;
fprintf('\nR0(beta0)<1: %d / %d (full grid) | %d / %d (feasible set)\n', ...
    nnz(selA), nG, nnz(selF), nnz(feas));
fprintf('feasible set: 3<=d_alpha<=%.2f d, 1.5<=d_nu<=%.2f d, phi<=0.30\n', ...
    dA0, dNu0);

if ~any(selF)
    warning('no feasible combination below R0=1; using full grid.');
    sel = selA;
    fprintf('(fallback to full grid; label as out-of-range extrapolation)\n');
else
    sel = selF;
end

if ~any(sel)
    warning('no combination below R0=1 at all: widen the grid.');
else
    idx = find(sel);
    [~, o] = sort(R0v(idx));
    idx = idx(o);
    nSim = min(numel(idx), 120);
    C41 = zeros(nSim, 1); C52 = C41; R0b = C41;
    for k = 1:nSim
        M = simu(p, 7 / dAv(idx(k)), 7 / dNv(idx(k)), ...
            pCv(idx(k)), pTv(idx(k)));
        C41(k) = M.C41;
        C52(k) = M.C52;
        R0b(k) = M.R0b;
    end

    dAlpha = dAv(idx(1:nSim));
    dNu = dNv(idx(1:nSim));
    phiCv = pCv(idx(1:nSim));
    phiTv = pTv(idx(1:nSim));
    R0a = R0v(idx(1:nSim));
    averted = B.C52 - C52;
    margin = 1 - R0a;
    cost = (dA0 - dAlpha) / (dA0 - 2) ...
        + (dNu0 - dNu) / (dNu0 - 1.5) ...
        + phiCv / 0.30 + phiTv / 0.30;
    knife = margin < 0.02;

    D = table(dAlpha, dNu, phiCv, phiTv, R0a, margin, C41, C52, ...
        averted, R0b, cost, knife, ...
        'VariableNames', {'dAlpha', 'dNu', 'phiC', 'phiT', 'R0_beta0', ...
        'R0_margin', 'C41', 'C52', 'averted', 'R0_beta1', 'cost', 'knife'});
    D = sortrows(D, 'C52', 'ascend');
    fprintf('\n=== top-10 by lowest C52 (maximum effect) ===\n');
    disp(D(1:min(10, height(D)), :));

    D2 = sortrows(D, 'cost', 'ascend');
    fprintf('\n=== top-10 by lowest cost (minimum investment) ===\n');
    disp(D2(1:min(10, height(D2)), :));
    if any(D2.knife(1:min(10, height(D2))))
        fprintf('[note] rows with knife=1 have margin < 2%%;\n');
        fprintf('       they are feasibility examples, NOT recommended plans.\n');
    end

    D3 = D(~D.knife, :);
    if isempty(D3)
        fprintf('\n[robust] no combination with margin >= 2%%\n');
    else
        D3 = sortrows(D3, 'cost', 'ascend');
        fprintf('\n=== top-10 with margin >= 2%% (recommendable) ===\n');
        disp(D3(1:min(10, height(D3)), :));
        writetable(D3, fullfile(outDir, 'Q3_combinations_robust.csv'));
    end
    writetable(D, fullfile(outDir, 'Q3_combinations_by_effect.csv'));
    writetable(D2, fullfile(outDir, 'Q3_combinations_by_cost.csv'));
    fprintf('\nNOTE: averted = %.0f - C52 is a COUNTERFACTUAL, mitigation\n', B.C52);
    fprintf('      applied from W25; it is NOT "how many more can be saved now".\n');
    fprintf('      cost = 0 at current levels and is non-negative by construction.\n');
end


%% 10. Kappa robustness
kGrid = [1 2 3 4];
R0tar = B.R0a;
resp = nan(numel(kGrid), 5);
for k = 1:numel(kGrid)
    kk = kGrid(k);
    Gk = 1 / a0 + kk * p.mu / (p.nu * (p.gamma + p.mu));
    bk = R0tar / Gk;
    pc = R0tar - bk / a0;
    if pc < 1
        ac = bk / (1 - pc) - (p.gamma + p.mu);
        if ac > 0, dac = 7 / ac; else, dac = NaN; end
    else
        dac = NaN;
    end
    if (1 - bk / a0) > 0
        nuc = bk * kk * p.mu / ((p.gamma + p.mu) * (1 - bk / a0));
        if nuc > 0, dnuc = 7 / nuc; else, dnuc = NaN; end
    else
        dnuc = NaN;
    end
    resp(k, :) = [kk, bk, pc, dac, dnuc];
end

Kr = table(resp(:,1), resp(:,2), resp(:,3), resp(:,4), resp(:,5), ...
    'VariableNames', {'kappa', 'beta0_recal', 'D_only_floor', ...
    'd_alpha_crit', 'd_nu_crit'});
fprintf('\n=== kappa robustness (R0_beta0 = %.3f) ===\n', R0tar);
disp(Kr);
writetable(Kr, fullfile(outDir, 'Q3_kappa.csv'));

kStar = NaN;
for kk = linspace(1, 10, 4000)
    Gk = 1 / a0 + kk * p.mu / (p.nu * (p.gamma + p.mu));
    bk = R0tar / Gk;
    if bk / a0 < 1
        nuc = bk * kk * p.mu / ((p.gamma + p.mu) * (1 - bk / a0));
        if nuc > 0 && 7 / nuc >= 1
            kStar = kk;
            break;
        end
    end
end
fprintf('kappa* (burial alone sufficient, d_nu_crit = 1 d): %.2f\n', kStar);

f5 = figure('Position', [100 100 880 400], 'Name', 'Fig3-5');
subplot(1, 2, 1);
bar(kGrid, Kr.d_alpha_crit, 'FaceColor', [0 0.45 0.74]); hold on;
yline(dA0, 'k--', 'LineWidth', 1.2); grid on; ylim([0 6.4]);
xlabel('\kappa'); ylabel('Critical admission delay (days)');
title('(a) Case isolation');
for k = 1:numel(kGrid)
    text(kGrid(k), Kr.d_alpha_crit(k) + 0.14, ...
        sprintf('%.2f', Kr.d_alpha_crit(k)), ...
        'HorizontalAlignment', 'center', 'FontSize', 9);
end
text(1.05, dA0 + 0.16, sprintf('current %.2f d', dA0), 'FontSize', 9);

subplot(1, 2, 2);
dn = Kr.d_nu_crit;
dnPlot = dn;
dnPlot(isnan(dn)) = 0;
bar(kGrid, dnPlot, 'FaceColor', [0.85 0.33 0.10]); hold on;
yline(dNu0, 'k--', 'LineWidth', 1.2);
yline(1.0, 'r:', 'LineWidth', 1.2); grid on; ylim([0 2.6]);
xlabel('\kappa'); ylabel('Critical burial delay (days)');
title('(b) Safe burial');
for k = 1:numel(kGrid)
    if isnan(dn(k))
        text(kGrid(k), 0.12, 'n/a', 'HorizontalAlignment', 'center', ...
            'FontSize', 9, 'Color', [0.4 0.4 0.4]);
    else
        text(kGrid(k), dn(k) + 0.07, sprintf('%.2f', dn(k)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
    end
end
text(1.05, dNu0 + 0.10, sprintf('current %.1f d', dNu0), 'FontSize', 9);
exportgraphics(f5, fullfile(outDir, 'Fig3-5_kappa.png'), 'Resolution', 300);

%% 11. Summary
fprintf('\n=== conclusions ===\n');
fprintf('1) isolation cannot remove the corpse channel: R0 floor = %.3f (b0) / %.3f (b1)\n', ...
    c0.pc, c1.pc);
fprintf('2) single-measure targets: d_alpha<=%.2f d | d_nu<=%.2f d | phiC>=%.1f%% | phiT>=%.1f%%\n', ...
    c0.dac, c0.dnuc, 100 * c0.phic, 100 * c0.phiT);
fprintf('3) per day: burial cuts R0 by %.3f, isolation by %.3f (ratio %.2f)\n', ...
    dRdN, dRdA, dRdN / dRdA);
fprintf('4) under beta1, R0 = %.3f < 1: focus shifts to rebound prevention\n', B.R0b);
fprintf('5) kappa robustness of the burial conclusion:\n');
fprintf('   kappa in [2,4]: d_nu_crit = 0.44-0.96 d, all below the 1-d floor,\n');
fprintf('                   so safe burial alone cannot push R0 below 1;\n');
fprintf('   kappa = 1    : pre-death channel already above 1, no feasible nu;\n');
fprintf('   kappa > %.2f: d_nu_crit exceeds 1 d, burial alone becomes sufficient.\n', kStar);
fprintf('6) tracing and isolation share one channel: d_eff=(1-phiT)d_a+phiT*dT,\n');
fprintf('   so (d_a=3.5,phiT=0.2) and (d_a=3.0,phiT=0) are numerically identical.\n');
fprintf('\nSaved Q3 outputs to %s\n', outDir);


%% Local functions
function R = simu(p, alpha, nu, phiC, phiT)
ae = alphaEff(p, alpha, phiT);
b0e = p.beta0 * (1 - phiC);
b1e = p.beta1 * (1 - phiC);
o = odeset('RelTol', 1e-8, 'AbsTol', 1e-6, ...
    'NonNegative', 1:7, 'MaxStep', 0.2);

t1 = linspace(0, p.tau, 25);
[ta, ya] = ode15s(@(t, y) rhs(y, b0e, ae, nu, p), t1, p.y0, o);
t2 = linspace(p.tau, p.Tend, 200);
[tb, yb] = ode15s(@(t, y) rhs(y, b1e, ae, nu, p), t2, ya(end, :).', o);
t = [ta; tb(2:end)];
y = [ya; yb(2:end, :)];

C = y(:,3) + y(:,4) + y(:,5) + y(:,7);
tw = (0:1:p.Tend)';
Cw = interp1(t, C, tw, 'linear');
newC = diff(Cw);
[R.peakNew, kk] = max(newC);
R.peakWeek = 25 + kk;
R.C41 = interp1(t, C, p.tObs, 'linear');
R.C52 = Cw(end);
R.Imax = max(y(:,3));
R.R0a = R0f(b0e, ae, p.gamma, p.mu, p.gammaQ, p.muQ, nu, p.kappa);
R.R0b = R0f(b1e, ae, p.gamma, p.mu, p.gammaQ, p.muQ, nu, p.kappa);
R.t = t;
R.y = y;
R.C = C;
end

function dydt = rhs(y, beta, alpha, nu, p)
S = y(1);
E = y(2);
I = y(3);
Ql = y(4);
D = y(6);

lam = beta * S * (I + p.kappa * D) / p.N;
dydt = [ ...
    -lam; ...
    lam - p.sigma * E; ...
    p.sigma * E - (alpha + p.gamma + p.mu) * I; ...
    alpha * I - (p.gammaQ + p.muQ) * Ql; ...
    p.gamma * I + p.gammaQ * Ql; ...
    p.mu * I + p.muQ * Ql - nu * D; ...
    p.mu * I + p.muQ * Ql];
end

function ae = alphaEff(p, alpha, phiT)
if phiT <= 0
    ae = alpha;
    return;
end
d0 = 7 / alpha;
ae = 7 / ((1 - phiT) * d0 + phiT * p.dT);
end

function r = R0f(beta, alpha, gamma, mu, gammaQ, muQ, nu, kappa)
a = alpha + gamma + mu;
b = gammaQ + muQ;
r = beta / a + (beta * kappa / nu) * (mu / a + (alpha / a) * (muQ / b));
end


function c = critAll(p, beta)
a = p.alpha + p.gamma + p.mu;
c.R0 = beta / a + beta * p.kappa * p.mu / (p.nu * (p.gamma + p.mu));
c.pc = beta * p.kappa * p.mu / (p.nu * (p.gamma + p.mu));

if c.pc < 1
    ac = beta / (1 - c.pc) - (p.gamma + p.mu);
else
    ac = NaN;
end

if isnan(ac) || ac <= 0
    c.dac = NaN;
    c.phiT = 0;
else
    c.dac = 7 / ac;
    d0 = 7 / p.alpha;
    if c.dac >= d0
        c.phiT = 0;
    else
        c.phiT = (d0 - c.dac) / (d0 - p.dT);
    end
end

if beta / a < 1
    nuc = beta * p.kappa * p.mu / ((p.gamma + p.mu) * (1 - beta / a));
    if nuc > 0
        c.dnuc = 7 / nuc;
    else
        c.dnuc = NaN;
    end
else
    c.dnuc = NaN;
end
c.phic = 1 - 1 / c.R0;
end

function S = sweepX(fun, xs)
n = numel(xs);
f = {'R0a', 'R0b', 'C41', 'C52', 'peakNew', 'Imax'};
for k = 1:numel(f)
    S.(f{k}) = nan(n, 1);
end
for i = 1:n
    M = fun(xs(i));
    for k = 1:numel(f)
        S.(f{k})(i) = M.(f{k});
    end
end
S.x = xs(:);
[S.x, o] = sort(S.x);
for k = 1:numel(f)
    S.(f{k}) = S.(f{k})(o);
end
assert(numel(S.x) == numel(S.C52), 'x and metrics length mismatch');
assert(all(S.C52 >= 1000), 'C52 too low: check y0 and parameters');
end

function printCross(name, xs, S)
idx = find(S.R0a < 1, 1);
if isempty(idx)
    fprintf('  %-22s : no crossing (min R0=%.3f)\n', name, min(S.R0a));
else
    fprintf('  %-22s : crossing at x=%.3f (R0=%.3f)\n', ...
        name, xs(idx), S.R0a(idx));
end
end


function panel(k, S, xlabTxt, ttl, B, revX, yl, noteStr)
if nargin < 6, revX = false; end
if nargin < 7, yl = []; end
if nargin < 8, noteStr = ''; end
xs = S.x(:);

subplot(2, 2, k); hold on; grid on;
y1 = (S.C52 / B.C52 - 1) * 100;
y2 = (S.peakNew / B.peakNew - 1) * 100;
h1 = plot(xs, y1, '-o', 'LineWidth', 1.6, 'MarkerSize', 4, ...
    'Color', [0 0.45 0.74], 'MarkerFaceColor', [0 0.45 0.74]);
h2 = plot(xs, y2, '-s', 'LineWidth', 1.6, 'MarkerSize', 4, ...
    'Color', [0.85 0.33 0.10], 'MarkerFaceColor', [0.85 0.33 0.10]);
yline(0, 'k:', 'LineWidth', 0.8);

i1 = find(S.R0a < 1, 1);
if ~isempty(i1)
    xline(xs(i1), 'k--', 'LineWidth', 1.1, 'Label', 'R_0=1', ...
        'LabelVerticalAlignment', 'bottom');
end
if revX
    set(gca, 'XDir', 'reverse');
end
xlim([min(xs) max(xs)]);
if ~isempty(yl)
    ylim(yl);
end
xlabel(xlabTxt);
ylabel('Change vs. baseline (%)');
title(ttl);

if ~isempty(noteStr)
    text(0.03, 0.05, noteStr, 'Units', 'normalized', ...
        'FontSize', 8.5, 'Color', [0.35 0.35 0.35], ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'left');
end
legend([h1 h2], {'C_{52}', 'Weekly peak'}, 'Location', 'best', 'Box', 'off');
hold off;
end

function [R0g, Cg] = grid2d(p, X, Y, mode)
R0g = zeros(size(X));
Cg = R0g;
for j = 1:size(X, 1)
    for i = 1:size(X, 2)
        switch mode
            case 'AN'
                M = simu(p, 7 / X(j,i), 7 / Y(j,i), 0, 0);
            case 'CN'
                M = simu(p, p.alpha, 7 / Y(j,i), X(j,i), 0);
            case 'CA'
                M = simu(p, 7 / Y(j,i), p.nu, X(j,i), 0);
        end
        R0g(j,i) = M.R0a;
        Cg(j,i) = M.C52;
    end
end
end

function heatF(X, Y, Z, R0g, xlabTxt, ylabTxt, clabTxt, fname, feasBox)
f = figure('Position', [120 120 840 640]);
contourf(X, Y, Z / 1e3, 24, 'LineStyle', 'none'); hold on;
dx = max(X(:)) - min(X(:));
dy = max(Y(:)) - min(Y(:));

if ~isempty(R0g) && any(R0g(:) < 1) && any(R0g(:) > 1)
    [c, h] = contour(X, Y, R0g, [1 1], 'k--', 'LineWidth', 2.0);
    clabel(c, h, 'FontSize', 11, 'LabelSpacing', 500);
    text(min(X(:)) + 0.03 * dx, max(Y(:)) - 0.04 * dy, ...
        'R_0=1 (dashed)', 'Color', 'w', 'FontSize', 10, ...
        'FontWeight', 'bold', 'VerticalAlignment', 'top');
elseif ~isempty(R0g) && all(R0g(:) >= 1)
    text(min(X(:)) + 0.03 * dx, max(Y(:)) - 0.04 * dy, ...
        'R_0>1 everywhere', 'Color', 'w', 'FontSize', 10, ...
        'FontWeight', 'bold', 'VerticalAlignment', 'top');
elseif ~isempty(R0g)
    text(min(X(:)) + 0.03 * dx, max(Y(:)) - 0.04 * dy, ...
        'R_0<1 everywhere', 'Color', 'w', 'FontSize', 10, ...
        'FontWeight', 'bold', 'VerticalAlignment', 'top');
end

if nargin >= 9 && ~isempty(feasBox)
    rectangle('Position', feasBox, 'EdgeColor', 'w', 'LineWidth', 2.0);
    text(feasBox(1) + 0.02 * dx, feasBox(2) + 0.06 * dy, 'feasible', ...
        'Color', 'w', 'FontSize', 9, 'FontWeight', 'bold');
end
cb = colorbar;
cb.Label.String = clabTxt;
colormap(turbo(256));
xlabel(xlabTxt);
ylabel(ylabTxt);
exportgraphics(f, [fname '.png'], 'Resolution', 300);
hold off;
end

