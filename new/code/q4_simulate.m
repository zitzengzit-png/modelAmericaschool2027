function out = q4_simulate(D, p, P, y0, tspan)
%Q4_SIMULATE  Integrate the 8-province SEIQRD metapopulation.
%
%   out = q4_simulate(D, p, P, y0, tspan)
%
%   State layout is province-major per state:
%   [S(1..nP) E(1..nP) ... M(1..nP)].

nP = D.nP;
y0 = y0(:);
tspan = tspan(:);
betaFun = make_beta_fun_multi(p.betaC0, [p.u1; p.u2], p.tKnots);

opts = odeset('RelTol', 1e-6, 'AbsTol', 1e-8, ...
    'NonNegative', 1:(7*nP), 'MaxStep', 1);

[T, Y] = ode15s(@(t, y) rhs(t, y, D, p, P, betaFun), ...
    tspan, y0, opts);

S = Y(:, 1:nP);
E = Y(:, nP+1:2*nP);
I = Y(:, 2*nP+1:3*nP);
Q = Y(:, 3*nP+1:4*nP);
R = Y(:, 4*nP+1:5*nP);
Dd = Y(:, 5*nP+1:6*nP);
M = Y(:, 6*nP+1:7*nP);
C = I + Q + R + M;

out = struct('t', T, 'Y', Y, 'S', S, 'E', E, 'I', I, 'Q', Q, ...
    'R', R, 'D', Dd, 'M', M, 'C', C, 'betaFun', betaFun);
end

% -------------------------------------------------------------------------
function dy = rhs(t, y, D, p, P, betaFun)
nP = D.nP;
y = reshape(y, nP, 7);
S = y(:,1); E = y(:,2); I = y(:,3); Q = y(:,4);
R = y(:,5); Dd = y(:,6); M = y(:,7); %#ok<NASGU>

bc = betaFun(t);
bh = p.rhoH0 * bc;
bf = p.rhoF0 * bc;
N = D.N;
w = p.w;

Lambda = zeros(nP, 1);
for i = 1:nP
    local = p.betaMult(i) * (bc*I(i) + bh*Q(i) + bf*Dd(i));
    cross = 0;
    for j = 1:nP
        if j ~= i
            cross = cross + w(i,j) * P(i,j) * bc * p.betaMult(j) * I(j);
        end
    end
    Lambda(i) = S(i) / N(i) * (local + cross);
end

dy = zeros(nP, 7);
dy(:,1) = -Lambda;
dy(:,2) = Lambda - p.sigma * E;
dy(:,3) = p.sigma * E - (p.alpha + p.gamma + p.mu) .* I;
dy(:,4) = p.alpha * I - (p.gammaQ + p.muQ) .* Q;
dy(:,5) = p.gamma * I + p.gammaQ * Q;
dy(:,6) = p.mu * I + p.muQ * Q - p.nu * Dd;
dy(:,7) = p.mu * I + p.muQ * Q;
dy = dy(:);
end
