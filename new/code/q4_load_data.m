function D = q4_load_data(cfg, opts)
%Q4_LOAD_DATA  Load 8-province data, adjacency, gravity P and Q2 parameters.
%
%   D = q4_load_data(cfg)
%   D = q4_load_data(cfg, struct('mShare',0.015,'gamma',1.5))
%
%   Data are read directly from ws/new/data/ebola_tracker.  P is a
%   column-stochastic stay-share proxy, not observed OD.

if nargin < 2 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'mShare', 0.015);
opts = set_default(opts, 'gamma', 1.5);

provNames = {'Ituri', 'Nord-Kivu', 'Haut-Uele', 'Tshopo', ...
    'Bas-Uele', 'Nord-Ubangi', 'Sud-Kivu', 'Sud-Ubangi'}';
nP = numel(provNames);

prov = readtable(fullfile(cfg.trackerDir, 'province_latest_20261111.csv'), ...
    'Encoding', 'UTF-8', 'PreserveVariableNames', true);
daily = readtable(fullfile(cfg.trackerDir, 'province_daily_20261111.csv'), ...
    'Encoding', 'UTF-8', 'PreserveVariableNames', true);

N = zeros(nP, 1);
for i = 1:nP
    N(i) = prov.population(strcmp(string(prov.province), provNames{i}));
end

% Province cumulative at fixed dates.
getC = @(provName, day) get_val(daily, provName, day, 'cum_confirmed');
getM = @(provName, day) get_val(daily, provName, day, 'cum_deaths');
C0 = nan(nP, 1); M0 = nan(nP, 1);
C10 = nan(nP, 1); M10 = nan(nP, 1);
C11 = nan(nP, 1); M11 = nan(nP, 1);
C1018 = nan(nP, 1); M1018 = nan(nP, 1);
for i = 1:nP
    C0(i) = getC(provNames{i}, 0);
    M0(i) = getM(provNames{i}, 0);
    C10(i) = getC(provNames{i}, 126);
    M10(i) = getM(provNames{i}, 126);
    C11(i) = getC(provNames{i}, 141);
    M11(i) = getM(provNames{i}, 141);
    C1018(i) = getC(provNames{i}, 119);
    M1018(i) = getM(provNames{i}, 119);
end

% Geographic adjacency and capital distances.
A = zeros(nP);
edges = [1 2; 1 3; 1 4; 2 4; 2 7; 3 4; 3 5; 4 5; 5 6; 6 8];
for k = 1:size(edges, 1)
    A(edges(k, 1), edges(k, 2)) = 1;
    A(edges(k, 2), edges(k, 1)) = 1;
end
lat = [1.55941; -1.67409; 2.77391; 0.515; 2.78582; ...
    4.27900; -2.49077; 3.25651];
lon = [30.25224; 29.22845; 27.61603; 25.191; 24.72997; ...
    21.00284; 28.84281; 19.77234];
distKm = zeros(nP);
for i = 1:nP
    for j = i+1:nP
        dphi = deg2rad(lat(j) - lat(i));
        dlmb = deg2rad(lon(j) - lon(i));
        h = sin(dphi/2)^2 + cos(deg2rad(lat(i))) * ...
            cos(deg2rad(lat(j))) * sin(dlmb/2)^2;
        h = min(1, h);
        distKm(i, j) = 2 * 6371 * atan2(sqrt(h), sqrt(1-h));
        distKm(j, i) = distKm(i, j);
    end
end

% Gravity stay-share matrix, column-stochastic.
W = zeros(nP);
for i = 1:nP
    for j = 1:nP
        if i ~= j && A(i, j) > 0
            W(i, j) = N(i) * N(j) * (distKm(i, j) / 1000)^(-opts.gamma);
        end
    end
end
colW = sum(W, 1);
B = zeros(nP);
for j = 1:nP
    if colW(j) > 0
        B(:, j) = W(:, j) / colW(j);
    end
end
P = zeros(nP);
mEff = zeros(nP, 1);
for j = 1:nP
    if colW(j) > 0
        mEff(j) = opts.mShare;
        P(:, j) = mEff(j) * B(:, j);
        P(j, j) = 1 - mEff(j);
    else
        P(j, j) = 1;
    end
end
assert(all(abs(sum(P, 1) - 1) < 1e-9), 'P columns must sum to 1');

% Q2 9/20 primary parameters (best tau fixed fit).
Ptab = readtable(fullfile(cfg.q2OutDir, ...
    'Q2_besttau_fixed_parameters.csv'), ...
    'Encoding', 'UTF-8', 'PreserveVariableNames', true);
getp = @(name) Ptab.estimate(find(strcmp(string(Ptab.parameter), name), 1));
p = struct();
p.betaC0 = getp('betaC0');
p.u1 = getp('u1');
p.u2 = getp('u2');
p.alpha = getp('alpha0');
p.mu = getp('mu');
p.muQ = p.mu;
p.sigma = getp('sigma');
p.gamma = getp('gamma');
p.gammaQ = getp('gammaQ');
p.nu = getp('nu');
p.rhoH0 = getp('rhoH0');
p.rhoF0 = getp('rhoF0');
p.rhoM = getp('rhoM');
p.tKnots = days([datetime(2026, 8, 17); datetime(2026, 9, 20)] - cfg.dayZero)';
p.tKnots = sort(p.tKnots);
p.betaMult = ones(nP, 1);
p.w = ones(nP);
p.N = N;

D = struct();
D.provNames = provNames;
D.nP = nP;
D.N = N;
D.A = A;
D.distKm = distKm;
D.lat = lat;
D.lon = lon;
D.P = P;
D.mShare = opts.mShare;
D.mEff = mEff;
D.p = p;
D.C0 = C0; D.M0 = M0;
D.C10 = C10; D.M10 = M10;
D.C11 = C11; D.M11 = M11;
D.C1018 = C1018; D.M1018 = M1018;
D.daily = daily;
D.latest = prov;
end

% -------------------------------------------------------------------------
function v = get_val(daily, provName, day, field)
rows = daily(string(daily.province) == string(provName), :);
idx = find(rows.t_day == day, 1);
if isempty(idx)
    v = NaN;
else
    v = rows.(field)(idx);
end
end

function s = set_default(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
