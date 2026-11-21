function out = task4_spatial_skeleton()
%TASK4_SPATIAL_SKELETON  Task 4 delivery: 8-province SEIQRD metapopulation.
% Gravity matrix + H_ij mapping + Q2 9/20 params + ODE + holdout check.
% Init: anchor at 2026-06-21, run forward to 11-09.
% Returns a province table plus R_net and holdout MAE.

%% ----- 1. Shared setup (geometry, gravity P, Q2 params, anchor init) ------
[provNames, N, P, p, y0, daily] = task4_common();
nP = numel(provNames);

% R0 channel decomposition (report only)
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
R0 = p.beta_c0/a + p.alpha*(p.rhoH*p.beta_c0)/(a*b) ...
   + (p.rhoF*p.beta_c0/p.nu)*(p.mu/a + p.alpha*p.muQ/(a*b));
fprintf('R0 = %.3f  (community %.0f%%, hospital %.0f%%, funeral %.0f%%)\n', R0, ...
    100*(p.beta_c0/a)/R0, ...
    100*(p.alpha*p.rhoH*p.beta_c0/(a*b))/R0, ...
    100*((p.rhoF*p.beta_c0/p.nu)*(p.mu/a + p.alpha*p.muQ/(a*b)))/R0);

%% ----- 2. Integrate ODE ----------------------------------------------------
tEnd = 141;   % run to 11/9 (t_day 141)
opts = odeset('RelTol',1e-6,'AbsTol',1e-6);
[t, Y] = task4_integrate(@(t,y) rhs_spatial(t,y,p,P,N,nP), [0 tEnd], y0(:), p, opts);

% State vector is state-major: [S(1..8) E(1..8) I(1..8) Q(1..8) R(1..8) D(1..8) M(1..8)]
S  = Y(:,1:nP);
E  = Y(:,nP+1:2*nP);
I  = Y(:,2*nP+1:3*nP);
Q  = Y(:,3*nP+1:4*nP);
R  = Y(:,4*nP+1:5*nP);
Dd = Y(:,5*nP+1:6*nP);
M  = Y(:,6*nP+1:7*nP);
C = I + Q + R + M;                       % cumulative onset (model caliber)

% Conservation and corpse-stock checks (use all extracted states).
liveAndDead = S + E + I + Q + R + M;
assert(max(abs(liveAndDead - repmat(N', size(Y,1), 1)), [], 'all') < 1e-5, ...
    'task4_spatial_skeleton: conservation violated');
assert(min(Dd, [], 'all') >= -1e-6 && max(Dd - M, [], 'all') <= 1e-6, ...
    'task4_spatial_skeleton: D must stay in [0, M]');

%% ----- 3. Observed anchors & holdout from data -----------------------------
t10_25 = 126;   % ODE t for 10/25
t11_09 = 141;   % ODE t for 11/9
t10_18 = 119;   % for flat baseline (prev 7 days)

obs_hold = nan(nP,1);  base_hold = nan(nP,1); obs_1025 = nan(nP,1);
for i = 1:nP
    r = daily(strcmp(daily.province, provNames{i}), :);
    c1025 = getCum(r, t10_25);
    c1109 = getCum(r, t11_09);
    c1018 = getCum(r, t10_18);
    obs_1025(i) = c1025;
    if ~isnan(c1025) && ~isnan(c1109), obs_hold(i)  = c1109 - c1025; end
    if ~isnan(c1025) && ~isnan(c1018), base_hold(i) = (c1025 - c1018) * 15/7; end
end

C_fit_end  = interp1(t, C, t10_25);   % 1 x nP row
C_hold_end = interp1(t, C, t11_09);   % 1 x nP row
pred_hold  = (C_hold_end - C_fit_end).';   % nP x 1 column, match obs/base

%% ----- 4. Report -----------------------------------------------------------
fprintf('=== Cumulative cases @ 10/25 (model, onset caliber) ===\n');
[~,rank] = sort(C_fit_end,'descend');
for r = 1:nP
    fprintf('  %d. %-12s %.0f\n', r, provNames{rank(r)}, C_fit_end(rank(r)));
end

fprintf('\n=== Holdout net increase (10/26-11/9) ===\n');
fprintf('%-14s %8s %10s %10s\n','province','obs','flat-base','model');
for i = 1:nP
    fprintf('%-14s %8.0f %10.2f %10.1f\n', ...
        provNames{i}, obs_hold(i), base_hold(i), pred_hold(i));
end
valid = isfinite(obs_hold) & isfinite(base_hold) & isfinite(pred_hold);
mae_model = mean(abs(pred_hold(valid) - obs_hold(valid)));
mae_base  = mean(abs(base_hold(valid) - obs_hold(valid)));
fprintf('\nComparable provinces: %d of %d\n', nnz(valid), nP);
fprintf('\nMAE: model = %.2f | flat baseline = %.2f\n', mae_model, mae_base);

%% ----- 5. R_net & R_local (late phase, after t2) ---------------------------
beta_c = p.beta_c0 * (1 - p.u1) * (1 - p.u2);   % late-phase beta_c
beta_h = p.rhoH*beta_c; beta_f = p.rhoF*beta_c;
s = S(end,:)./N';
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
K = zeros(nP);
for i = 1:nP
    K(i,i) = s(i) * p.beta_mult(i) * ( beta_c/a + p.alpha*beta_h/(a*b) ...
              + (beta_f/p.nu)*(p.mu/a + p.alpha*p.muQ/(a*b)) );
    for j = 1:nP
        if j~=i
            K(i,j) = s(i) * (beta_c * p.beta_mult(j) * p.w(i,j) * P(i,j)) / a;
        end
    end
end
R_net = max(abs(eig(K)));
R_local = diag(K);
fprintf('\nR_net (late phase) = %.3f\n', R_net);
fprintf('R_local: %s\n', sprintf('%.2f ', R_local));

provTable = table(provNames, obs_1025, C_fit_end(:), obs_hold, ...
    base_hold, pred_hold, R_local(:), ...
    'VariableNames', {'province', 'C_obs_1025', 'C_model_1025', ...
    'obs_hold', 'flat_hold', 'model_hold', 'R_local'});
out = struct();
out.province_table = provTable;
out.R_net = R_net;
out.R_local = R_local;
out.holdout_mae_model = mae_model;
out.holdout_mae_flat = mae_base;
end

%% ----- helper: cumulative confirmed on a date ------------------------------
function c = getCum(rows, tDay)
    idx = find(rows.t_day == tDay, 1);
    if isempty(idx), c = NaN; else, c = rows.cum_confirmed(idx); end
end

%% ----- ODE right-hand side -------------------------------------------------
function dy = rhs_spatial(t, y, p, P, N, nP)
    y = reshape(y, nP, 7);
    S = y(:,1); E = y(:,2); I = y(:,3); Q = y(:,4);
    R = y(:,5); Dd = y(:,6); M = y(:,7);  %#ok<NASGU>

    beta_c = p.beta_c0 * (1 - p.u1*(t >= p.t1)) * (1 - p.u2*(t >= p.t2));
    beta_h = p.rhoH * beta_c;
    beta_f = p.rhoF * beta_c;

    Lambda = zeros(nP,1);
    for i = 1:nP
        local = p.beta_mult(i)*(beta_c*I(i) + beta_h*Q(i) + beta_f*Dd(i));
        cross = 0;
        for j = 1:nP
            if j~=i
                cross = cross + p.w(i,j)*P(i,j)*beta_c*p.beta_mult(j)*I(j);
            end
        end
        Lambda(i) = (S(i)/N(i)) * (local + cross);
    end

    dy = zeros(nP,7);
    dy(:,1) = -Lambda;
    dy(:,2) =  Lambda - p.sigma*E;
    dy(:,3) =  p.sigma*E - (p.alpha + p.gamma + p.mu).*I;
    dy(:,4) =  p.alpha*I - (p.gammaQ + p.muQ).*Q;
    dy(:,5) =  p.gamma*I + p.gammaQ.*Q;
    dy(:,6) =  p.mu*I + p.muQ.*Q - p.nu*Dd;
    dy(:,7) =  p.mu*I + p.muQ.*Q;
    dy = dy(:);
end
