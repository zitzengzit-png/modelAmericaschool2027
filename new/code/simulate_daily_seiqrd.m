function out = simulate_daily_seiqrd(p, t, y0, betaFun)
%SIMULATE_DAILY_SEIQRD  Integrate the daily three-route SEIQRD model.
%
%   out = simulate_daily_seiqrd(p, t, y0)
%   out = simulate_daily_seiqrd(p, t, y0, betaFun)
%
%   States: [S;E;I;Q;R;D;M]
%   betaH(t) = p.rhoH0*betaC(t), betaF(t) = p.rhoF0*betaC(t)
%   C = I+Q+R+M, M = cumulative deaths.

if nargin < 4 || isempty(betaFun)
    betaFun = make_beta_fun(p.betaC0, p.u1, p.u2, p.knots);
end

t = t(:);
y0 = y0(:);
opts = odeset('RelTol', 1e-6, 'AbsTol', 1e-8, ...
    'NonNegative', 1:7, 'MaxStep', 1);

[T, Y] = ode15s(@(tt, y) rhs(tt, y, p, betaFun), t, y0, opts);

C = Y(:, 3) + Y(:, 4) + Y(:, 5) + Y(:, 7);
M = Y(:, 7);

out = struct('t', T, 'y', Y, 'C', C, 'M', M, 'betaFun', betaFun);
end

% -------------------------------------------------------------------------
function dydt = rhs(t, y, p, betaFun)
S = y(1);
E = y(2);
I = y(3);
Q = y(4);
R = y(5);
D = y(6);
M = y(7);

bc = betaFun(t);
bh = p.rhoH0 * bc;
bf = p.rhoF0 * bc;

lam = S / p.N * (bc * I + bh * Q + bf * D);

dydt = [ ...
    -lam; ...
    lam - p.sigma * E; ...
    p.sigma * E - (p.alpha + p.gamma + p.mu) * I; ...
    p.alpha * I - (p.gammaQ + p.muQ) * Q; ...
    p.gamma * I + p.gammaQ * Q; ...
    p.mu * I + p.muQ * Q - p.nu * D; ...
    p.mu * I + p.muQ * Q];
end
