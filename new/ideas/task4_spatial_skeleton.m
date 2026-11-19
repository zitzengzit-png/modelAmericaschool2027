%% task4_spatial_skeleton.m
% Task 4 skeleton: 8-province SEIQRD metapopulation.
% Gravity matrix + H_ij mapping + placeholder params + ODE + holdout check.
%
% Placeholder params come from the old report (weekly values / 7 -> daily).
% Replace them with Task-2 fitted values once available.
%
% Init modes:
%   'origin' : ODE t=0 = outbreak 2026-05-15; seed Ituri, run forward.
%   'anchor' : ODE t=0 = 2026-06-21 (data t_day=0); initialize from observed
%              (C, M) state, run forward to 11-09. (default)

clear; clc; close all;

%% ----- 1. Load province data ---------------------------------------------
dataDir = fullfile('data','ebola_tracker');
prov  = readtable(fullfile(dataDir,'province_latest_20261111.csv'));
daily = readtable(fullfile(dataDir,'province_daily_20261111.csv'));

provNames = {'Ituri','Nord-Kivu','Haut-Uele','Tshopo','Bas-Uele',...
             'Nord-Ubangi','Sud-Kivu','Sud-Ubangi'}';
nP = numel(provNames);

N = zeros(nP,1);
for i = 1:nP
    N(i) = prov.population(strcmp(prov.province, provNames{i}));
end

% ---- simulation mode ------------------------------------------------------
init_mode = 'anchor';   % 'origin' = seed at outbreak 5/15; 'anchor' = start from 6/21 data
if strcmp(init_mode,'origin')
    t0_offset = 37;     % days from 5/15 (ODE t=0) to 6/21 (t_day=0)
else
    t0_offset = 0;      % ODE t=0 = 6/21 (t_day=0)
end

%% ----- 2. Adjacency & distance -------------------------------------------
% Geographic adjacency (bordering provinces), 8 provinces, 10 edges.
% Old report sec 6.4 also added 4 non-bordering "response corridors"
% (Nord-Kivu--Haut-Uele, Tshopo--Sud-Kivu, Tshopo--Sud-Ubangi,
%  Bas-Uele--Sud-Ubangi). Keep them as a sensitivity if movement along
% those links matters; default here is geographic adjacency only.
A = zeros(nP);
edges = [1 2; 1 3; 1 4; 2 4; 2 7; 3 4; 3 5; 4 5; 5 6; 6 8];
for k = 1:size(edges,1)
    A(edges(k,1), edges(k,2)) = 1;
    A(edges(k,2), edges(k,1)) = 1;
end
% Capital coordinates (lat, lon in decimal degrees; negative lat = south).
% Order matches provNames: Ituri, Nord-Kivu, Haut-Uele, Tshopo, Bas-Uele,
% Nord-Ubangi, Sud-Kivu, Sud-Ubangi. Source: UN DRC admin map / GeoNames.
lat = [1.55941; -1.67409; 2.77391; 0.515; 2.78582; 4.27900; -2.49077; 3.25651];
lon = [30.25224; 29.22845; 27.61603; 25.191; 24.72997; 21.00284; 28.84281; 19.77234];

% Haversine great-circle distance (km), Earth radius R = 6371.
R_earth = 6371;
latr = deg2rad(lat);  lonr = deg2rad(lon);
distKm = zeros(nP);
for i = 1:nP
    for j = i+1:nP
        dphi = latr(j) - latr(i);
        dlmb = lonr(j) - lonr(i);
        h = sin(dphi/2)^2 + cos(latr(i))*cos(latr(j))*sin(dlmb/2)^2;
        h = min(1, h);   % guard against floating-point overshoot
        distKm(i,j) = 2 * R_earth * atan2(sqrt(h), sqrt(1-h));
        distKm(j,i) = distKm(i,j);
    end
end

% Distance input for the gravity model (doc 4.2.1):
%   d = A       -> adjacency proxy (all links = 1), gamma has no effect
%   d = distKm  -> distance proxy (capital great-circle km), gamma matters
d = distKm;   % distance proxy

%% ----- 3. Gravity matrix (doc 4.2.1) -------------------------------------
cfg.gamma   = 1.5;      % distance decay exponent; scan {1, 1.5, 2}
cfg.m_share = 0.015;    % out-of-province stay share; scan {0.005,0.015,0.03}

W = zeros(nP);
for i = 1:nP
    for j = 1:nP
        if i~=j && A(i,j)>0
            W(i,j) = N(i) * N(j) * d(i,j)^(-cfg.gamma);
        end
    end
end
B = W ./ max(sum(W,1), eps);          % conditional share, column-normalized
B(:, sum(W,1)==0) = 0;

P = zeros(nP);
for j = 1:nP
    P(:,j) = cfg.m_share * B(:,j);
    P(j,j)  = 1 - cfg.m_share;
end
assert(all(abs(sum(P,1)-1) < 1e-9), 'P columns must sum to 1');

%% ----- 4. Placeholder parameters (daily = weekly / 7) ---------------------
p.alpha  = 1.244/7;
p.mu     = 0.235/7;
p.muQ    = p.mu;
p.sigma  = 0.70/7;
p.gamma  = 0.21/7;
p.gammaQ = 0.21/7;
p.nu     = 3.5/7;
p.rhoH   = 0.4;            % beta_h = rhoH * beta_c (placeholder; Task 2 re-estimates)
p.rhoF   = 3.0;            % beta_f = rhoF * beta_c (literature kappa)
p.w      = ones(nP);       % effective contact weight, baseline 1
p.beta_mult = ones(nP,1);  % province multiplier (shrinkage hook, TODO)

% Calibrate beta_c so the three-channel R0 matches the old two-channel fit
% (R0 = 1.356 pre-W32, 0.885 post-W32). The old beta0=1.298 was fitted with
% NO hospital channel (Q non-infectious); reusing it as beta_c would add the
% hospital term on top and push R0 to ~2.2, blowing up the model. Instead we
% rescale beta_c so total R0 is unchanged (the epidemic data is the same).
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
coef = 1/a + p.alpha*p.rhoH/(a*b) + (p.rhoF/p.nu)*(p.mu/a + p.alpha*p.muQ/(a*b));
R0_pre  = 1.356;           % old report basic reproduction number (pre-W32)
R0_post = 0.885;           % old report post-W32 effective reproduction number
p.beta0 = R0_pre  / coef;  % community beta_c, pre-W32 (daily)
p.beta1 = R0_post / coef;  % community beta_c, post-W32 (daily)
p.t_beta = t0_offset + 49; % W32 (8/9) = t_day 49 (49 days after 6/21)

fprintf('Calibrated beta_c: pre=%.4f, post=%.4f (daily)\n', p.beta0, p.beta1);
fprintf('Channel share of R0 (pre-W32): community=%.0f%%, hospital=%.0f%%, funeral=%.0f%%\n', ...
    100*(p.beta0/a)/R0_pre, ...
    100*(p.alpha*p.rhoH*p.beta0/(a*b))/R0_pre, ...
    100*((p.rhoF*p.beta0/p.nu)*(p.mu/a + p.alpha*p.muQ/(a*b)))/R0_pre);

%% ----- 5. Time axis & initial state --------------------------------------
tEnd = t0_offset + 141;   % run to 11/9 (t_day 141)

y0 = zeros(nP,7);         % [S E I Q R D M]
if strcmp(init_mode,'origin')
    y0(:,1) = N;
    iIturi = find(strcmp(provNames,'Ituri'));
    seed = 5;             % initial infectious in Ituri; TODO calibrate
    y0(iIturi,1) = N(iIturi) - seed;
    y0(iIturi,3) = seed;
else
    y0 = anchor_state(daily, provNames, N, p, nP);
end

%% ----- 6. Integrate ODE ---------------------------------------------------
opts = odeset('RelTol',1e-6,'AbsTol',1e-6);
[t, Y] = ode45(@(t,y) rhs_spatial(t,y,p,P,N,nP), [0 tEnd], y0(:), opts);

% State vector is state-major: [S(1..8) E(1..8) I(1..8) Q(1..8) R(1..8) D(1..8) M(1..8)]
S  = Y(:,1:nP);
E  = Y(:,nP+1:2*nP);
I  = Y(:,2*nP+1:3*nP);
Q  = Y(:,3*nP+1:4*nP);
R  = Y(:,4*nP+1:5*nP);
Dd = Y(:,5*nP+1:6*nP);
M  = Y(:,6*nP+1:7*nP);
C = I + Q + R + M;                       % cumulative onset (model caliber)

%% ----- 7. Observed anchors & holdout from data ----------------------------
t10_25 = t0_offset + 126;   % ODE t for 10/25
t11_09 = t0_offset + 141;   % ODE t for 11/9
t10_18 = t0_offset + 119;   % for flat baseline (prev 7 days)

obs_hold = nan(nP,1);  base_hold = nan(nP,1);
for i = 1:nP
    r = daily(strcmp(daily.province, provNames{i}), :);
    c1025 = getCum(r, 126);   % t_day for 2026-10-25
    c1109 = getCum(r, 141);   % t_day for 2026-11-09
    c1018 = getCum(r, 119);   % t_day for 2026-10-18
    if ~isnan(c1025) && ~isnan(c1109), obs_hold(i)  = c1109 - c1025; end
    if ~isnan(c1025) && ~isnan(c1018), base_hold(i) = (c1025 - c1018) * 15/7; end
end

C_fit_end  = interp1(t, C, t10_25);   % 1 x nP row
C_hold_end = interp1(t, C, t11_09);   % 1 x nP row
pred_hold  = (C_hold_end - C_fit_end).';   % nP x 1 column, match obs/base

%% ----- 8. Report ----------------------------------------------------------
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
% Compare both methods on the same provinces with usable observations.
valid = isfinite(obs_hold) & isfinite(base_hold) & isfinite(pred_hold);
mae_model = mean(abs(pred_hold(valid) - obs_hold(valid)));
mae_base  = mean(abs(base_hold(valid) - obs_hold(valid)));
fprintf('\nComparable provinces: %d of %d\n', nnz(valid), nP);
fprintf('\nMAE: model = %.2f | flat baseline = %.2f\n', mae_model, mae_base);

%% ----- 9. R_net (current phase, beta1) ------------------------------------
beta_c = p.beta1; beta_h = p.rhoH*beta_c; beta_f = p.rhoF*beta_c;
s = S(end,:)./N';
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
K = zeros(nP);
for i = 1:nP
    K(i,i) = s(i)*( beta_c/a + p.alpha*beta_h/(a*b) ...
              + (beta_f/p.nu)*(p.mu/a + p.alpha*p.muQ/(a*b)) );
    for j = 1:nP
        if j~=i
            K(i,j) = s(i) * (beta_c * p.w(i,j) * P(i,j)) / a;   % H_ij / a_j
        end
    end
end
R_net = max(abs(eig(K)));
fprintf('\nR_net (post-W32 phase) = %.3f\n', R_net);

%% ----- helper: cumulative confirmed on a date -----------------------------
function c = getCum(rows, tDay)
    idx = find(rows.t_day == tDay, 1);
    if isempty(idx), c = NaN; else, c = rows.cum_confirmed(idx); end
end

%% ----- helper: reconstruct 6/21 state from observed (C, M) -----------------
function y0 = anchor_state(daily, provNames, N, p, nP)
    a = p.alpha + p.gamma + p.mu;
    iso_ratio = 0.4;       % isolation ratio (doc 3.6)
    y0 = zeros(nP,7);
    for i = 1:nP
        r = daily(strcmp(daily.province, provNames{i}), :);
        C0  = getVal(r, 0, 'cum_confirmed');
        M0  = getVal(r, 0, 'cum_deaths');
        % daily new at t_day=0 is NaN (no prior day); use week-1 average
        inc  = meanVal(r, 1:7, 'new_confirmed');
        dinc = meanVal(r, 1:7, 'new_deaths');
        if isnan(C0),  C0 = 0; end
        if isnan(M0),  M0 = 0; end
        if isnan(inc), inc = 0; end
        if isnan(dinc), dinc = 0; end

        active = inc / a;                       % I+Q ~ incidence / removal rate
        active = min(active, max(C0 - M0, 0));
        Q0 = iso_ratio * active;
        I0 = active - Q0;
        E0 = min(inc / p.sigma, N(i) - C0);     % latent pool ~ incidence/sigma
        R0 = max(C0 - M0 - active, 0);          % recovered residual
        D0 = min(dinc * (2/7), M0);             % unburied = daily deaths x 2d delay
        S0 = N(i) - E0 - I0 - Q0 - R0 - M0;
        y0(i,:) = [S0 E0 I0 Q0 R0 D0 M0];
    end
end

%% ----- helper: read a field at a t_day -------------------------------------
function v = getVal(rows, tDay, field)
    idx = find(rows.t_day == tDay, 1);
    if isempty(idx), v = NaN; else, v = rows.(field)(idx); end
end

%% ----- helper: mean of a field over t_days (skip NaN) ----------------------
function v = meanVal(rows, tDays, field)
    vals = NaN(numel(tDays),1);
    for k = 1:numel(tDays)
        vals(k) = getVal(rows, tDays(k), field);
    end
    vals = vals(~isnan(vals));
    if isempty(vals), v = NaN; else, v = mean(vals); end
end

%% ----- ODE right-hand side -------------------------------------------------
function dy = rhs_spatial(t, y, p, P, N, nP)
    y = reshape(y, nP, 7);
    S = y(:,1); E = y(:,2); I = y(:,3); Q = y(:,4);
    R = y(:,5); Dd = y(:,6); M = y(:,7);  %#ok<NASGU>

    beta_c = p.beta0*(t < p.t_beta) + p.beta1*(t >= p.t_beta);
    beta_h = p.rhoH * beta_c;
    beta_f = p.rhoF * beta_c;

    Lambda = zeros(nP,1);
    for i = 1:nP
        local = p.beta_mult(i)*(beta_c*I(i) + beta_h*Q(i) + beta_f*Dd(i));
        cross = 0;
        for j = 1:nP
            if j~=i
                % H_ij = beta_c * w_ij * P_ij   (doc 4.2.1/4.2.2 mapping)
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
