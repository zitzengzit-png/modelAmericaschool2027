function [provNames, N, P, p, y0, daily] = task4_common()
%TASK4_COMMON  Shared Task-4 setup: 8-province geometry, gravity mobility
% matrix, Q2 9/20 daily parameters, and the 6/21 anchor initial state.
% Single source of truth so parameters cannot drift between the spatial
% scripts (skeleton / strategies / holdout / q2-uncertainty).

dataDir = fullfile(fileparts(mfilename('fullpath')), 'data', 'ebola_tracker');
prov  = readtable(fullfile(dataDir, 'province_latest_20261111.csv'));
daily = readtable(fullfile(dataDir, 'province_daily_20261111.csv'));

provNames = {'Ituri','Nord-Kivu','Haut-Uele','Tshopo','Bas-Uele', ...
             'Nord-Ubangi','Sud-Kivu','Sud-Ubangi'}';
nP = numel(provNames);
N = zeros(nP, 1);
for i = 1:nP
    N(i) = prov.population(strcmp(prov.province, provNames{i}));
end

% Geographic adjacency (10 bordering edges) and capital coordinates.
A = zeros(nP);
edges = [1 2; 1 3; 1 4; 2 4; 2 7; 3 4; 3 5; 4 5; 5 6; 6 8];
for k = 1:size(edges,1)
    A(edges(k,1), edges(k,2)) = 1; A(edges(k,2), edges(k,1)) = 1;
end
lat = [1.55941; -1.67409; 2.77391; 0.515; 2.78582; 4.27900; -2.49077; 3.25651];
lon = [30.25224; 29.22845; 27.61603; 25.191; 24.72997; 21.00284; 28.84281; 19.77234];
distKm = zeros(nP);
for i = 1:nP
    for j = i+1:nP
        dphi = deg2rad(lat(j)-lat(i)); dlmb = deg2rad(lon(j)-lon(i));
        h = sin(dphi/2)^2 + cos(deg2rad(lat(i)))*cos(deg2rad(lat(j)))*sin(dlmb/2)^2;
        h = min(1, h);
        distKm(i,j) = 2*6371*atan2(sqrt(h), sqrt(1-h));
        distKm(j,i) = distKm(i,j);
    end
end

% Gravity mobility matrix P (column-normalized; out-of-province stay share m).
gamma = 1.5; m_share = 0.015;
if isappdata(0, 'task4_flow')      % sensitivity driver override
    flow = getappdata(0, 'task4_flow');
    m_share = flow(1); gamma = flow(2);
end
W = zeros(nP);
for i = 1:nP
    for j = 1:nP
        if i~=j && A(i,j)>0, W(i,j) = N(i)*N(j)*distKm(i,j)^(-gamma); end
    end
end
B = W ./ max(sum(W,1), eps); B(:, sum(W,1)==0) = 0;
P = zeros(nP);
for j = 1:nP
    P(:,j) = m_share*B(:,j); P(j,j) = 1 - m_share;
end

% Q2 9/20 daily parameters (解读文档/第四问建模数据修正.md §2.4).
p.beta_c0 = 0.11251;
p.u1 = 0.48919;  p.u2 = -0.50000;
p.t1 = 57;  p.t2 = 91;              % knots at 2026-08-17 / 09-20 (t_day)
p.alpha = 0.16979;  p.alpha0 = p.alpha;
p.mu = 0.03488;  p.muQ = p.mu;
p.sigma = 0.10;
p.gamma = 0.03;  p.gammaQ = 0.03;
p.nu = 0.50;
p.rhoH = 0.40;  p.rhoF = 3.00;
p.w = ones(nP);
p.beta_mult = ones(nP, 1);

y0 = anchor_state(daily, provNames, N, p, nP);
end

%% ----- reconstruct 6/21 state from observed (C, M) -------------------------
function y0 = anchor_state(daily, provNames, N, p, nP)
y0 = zeros(nP, 7);
for i = 1:nP
    r = daily(strcmp(daily.province, provNames{i}), :);
    C0 = getVal(r, 0, 'cum_confirmed'); M0 = getVal(r, 0, 'cum_deaths');
    inc  = meanVal(r, 1:7, 'new_confirmed'); dinc = meanVal(r, 1:7, 'new_deaths');
    if isnan(C0), C0 = 0; end
    if isnan(M0), M0 = 0; end
    if isnan(inc), inc = 0; end
    if isnan(dinc), dinc = 0; end
    [I0,Q0] = task4_initial_active(inc, C0-M0, p);
    active = I0 + Q0;
    E0 = min(inc/p.sigma, N(i) - C0);
    R0 = max(C0 - M0 - active, 0);
    D0 = min(2*dinc, M0);
    S0 = N(i) - E0 - I0 - Q0 - R0 - M0;
    y0(i,:) = [S0 E0 I0 Q0 R0 D0 M0];
end
end

%% ----- helpers --------------------------------------------------------------
function v = getVal(rows, tDay, field)
idx = find(rows.t_day == tDay, 1);
if isempty(idx), v = NaN; else, v = rows.(field)(idx); end
end

function v = meanVal(rows, tDays, field)
vals = NaN(numel(tDays), 1);
for k = 1:numel(tDays), vals(k) = getVal(rows, tDays(k), field); end
vals = vals(~isnan(vals));
if isempty(vals), v = NaN; else, v = mean(vals); end
end
