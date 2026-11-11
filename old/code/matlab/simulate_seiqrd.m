function out = simulate_seiqrd(p, t, y0, betaFun, alphaFun, nuFun)
%SIMULATE_SEIQRD  Integrate the seven-state SEIQRD model.
%   out = simulate_seiqrd(p, t) uses p.y0 and baseline time-varying beta.
%   betaFun/alphaFun/nuFun are scalar function handles of time (weeks).

if nargin < 3 || isempty(y0)
    y0 = p.y0;
end
if nargin < 4 || isempty(betaFun)
    betaFun = @(tt) p.beta0 .* (tt < p.tau) + p.beta1 .* (tt >= p.tau);
end
if nargin < 5 || isempty(alphaFun)
    alphaFun = @(tt) p.alpha;
end
if nargin < 6 || isempty(nuFun)
    nuFun = @(tt) p.nu;
end

t = t(:);
y0 = y0(:);
opts = odeset('RelTol', 1e-8, 'AbsTol', 1e-10, ...
    'NonNegative', 1:7, 'MaxStep', 0.25);

[T, Y] = ode15s(@(tt, y) rhs(tt, y, p, betaFun, alphaFun, nuFun), ...
    t, y0, opts);

C = Y(:,3) + Y(:,4) + Y(:,5) + Y(:,7);
M = Y(:,7);
weekly = diff(C);
if isempty(weekly)
    peak = NaN; peakWeek = NaN;
else
    [peak, idx] = max(weekly);
    peakWeek = T(idx + 1) + 25;
end

betas = arrayfun(betaFun, T);
R0t = arrayfun(@(b) r0_seiqrd(b, p), betas);
Rt = R0t .* Y(:,1) / p.N;

out = struct('t', T, 'y', Y, 'cases', C, 'deaths', M, ...
    'weekly', weekly, 'rt', Rt, 'beta', betas, ...
    'r0Early', r0_seiqrd(betaFun(T(1)), p), ...
    'r0Late', r0_seiqrd(betaFun(T(end)), p), ...
    'peak', peak, 'peakWeek', peakWeek, 'params', p);
end

function dydt = rhs(tt, y, p, betaFun, alphaFun, nuFun)
S = y(1); E = y(2); I = y(3); Q = y(4); D = y(6);

beta = betaFun(tt);
alpha = alphaFun(tt);
nu = nuFun(tt);
lam = beta * S * (I + p.kappa * D) / p.N;

dydt = [ ...
    -lam; ...
    lam - p.sigma * E; ...
    p.sigma * E - (alpha + p.gamma + p.mu) * I; ...
    alpha * I - (p.gammaQ + p.muQ) * Q; ...
    p.gamma * I + p.gammaQ * Q; ...
    p.mu * I + p.muQ * Q - nu * D; ...
    p.mu * I + p.muQ * Q];
end
