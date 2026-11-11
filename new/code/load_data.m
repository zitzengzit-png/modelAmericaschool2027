function data = load_data(arg)
%LOAD_DATA  Load the active model data source.
%
%   data = load_data()          config() default: tracker, W25-W43 fit
%   data = load_data(true)      tracker (legacy boolean interface)
%   data = load_data(false)     legacy workbook W25-W41
%   data = load_data('tracker') | load_data('legacy')
%   data = load_data(cfg)       config struct
%
%   Tracker branch
%     - newest national_weekly_*.csv in ws/data/ebola_tracker
%     - fit window cfg.fitWindow (default W25-W43, 19 points)
%     - holdout cfg.holdout (default W44-W45)
%     - W25/W43/W45 anchors are asserted (cfg.strict)
%     - 8 provinces, 67 health zones, response and cross-border tables
%     - initial state from state_at(data, 25)
%
%   Legacy branch
%     - ws/data/outbreak_data.xlsx sheet 2, W25-W41, 7 provinces
%     - kept unchanged for regression tests and the old Q3/Q4 baseline

if nargin < 1 || isempty(arg)
    cfg = config();
elseif isstruct(arg)
    cfg = arg;
elseif islogical(arg) || isnumeric(arg)
    cfg = config();
    if arg
        cfg.dataSource = 'tracker';
    else
        cfg.dataSource = 'legacy';
    end
elseif ischar(arg) || isstring(arg)
    cfg = config('dataSource', char(arg));
else
    error('load_data:badArg', ...
        'Argument must be empty, logical, text or a config struct.');
end
if ~isfield(cfg, 'strict') || isempty(cfg.strict)
    cfg.strict = true;
end

switch lower(string(cfg.dataSource))
    case "tracker"
        data = load_tracker(cfg);
    case "legacy"
        data = load_legacy(cfg);
    otherwise
        error('load_data:badSource', ...
            'dataSource must be tracker or legacy (got %s).', cfg.dataSource);
end
data.cfg = cfg;
end

% =========================================================================
% Tracker branch
% =========================================================================
function data = load_tracker(cfg)
weeklyFile = require_file(cfg.trackerDir, 'national_weekly_*.csv');
provFile = require_file(cfg.trackerDir, 'province_latest_*.csv');
zoneFile = require_file(cfg.trackerDir, 'health_zone_latest_*.csv');
respFile = latest_tracker_file(cfg.trackerDir, 'response_latest_*.csv');
crossFile = latest_tracker_file(cfg.trackerDir, 'cross_border_latest_*.csv');
hcwFile = latest_tracker_file(cfg.trackerDir, 'legacy_weekly_supplement_*.csv');
rawFile = latest_tracker_file(cfg.trackerDir, 'ebola-drc-database-2*.csv');

W = readtable(weeklyFile, 'Encoding', 'UTF-8', ...
    'VariableNamingRule', 'preserve', 'TextType', 'string');
W = sortrows(W, 'week');
nW = height(W);
if nW < 10
    error('load_data:tooFewWeeks', ...
        'Only %d weekly rows in %s.', nW, weeklyFile);
end

series = struct();
series.t = (0:nW - 1)';
series.week = double(W.week);
series.weekEnd = to_datetime(W.week_end);
series.cases = double(W.cum_confirmed);
series.deaths = double(W.cum_deaths);
series.recovered = col(W, 'recovered', nan(nW, 1));
series.etcAdmitted = col(W, 'etc_admitted', nan(nW, 1));
series.etcBeds = col(W, 'etc_beds', nan(nW, 1));
series.etcOccupancy = col(W, 'etc_occupancy', nan(nW, 1));
series.contactsToFollow = col(W, 'contacts_to_follow', nan(nW, 1));
series.contactsSeen = col(W, 'contacts_seen', nan(nW, 1));
series.contactsSeenPct = col(W, 'contacts_seen_pct', nan(nW, 1));
series.vaccinatedTotal = col(W, 'vaccinated_total', nan(nW, 1));
series.newCasesRaw = col(W, 'new_confirmed', nan(nW, 1));
series.newDeathsRaw = col(W, 'new_deaths', nan(nW, 1));
series.newCasesAdj = col(W, 'new_confirmed_adj', nan(nW, 1));
series.newDeathsAdj = col(W, 'new_deaths_adj', nan(nW, 1));
series.fixedQ = nan(nW, 1);
series.fixedE = nan(nW, 1);
series.fixedD = nan(nW, 1);
series.flags = string(W.flag);
series.sourceFile = weeklyFile;

% Published anchors.
assert_anchor(series, 25, 1048, 267, cfg.strict);
assert_anchor(series, 43, 10060, 4887, cfg.strict);
assert_anchor(series, 45, 10990, 5354, cfg.strict);

fitMask = series.week >= cfg.fitWindow(1) & series.week <= cfg.fitWindow(2);
holdMask = series.week >= cfg.holdout(1) & series.week <= cfg.holdout(2);
if nnz(fitMask) < 10
    error('load_data:shortFit', ...
        'Fit window W%d-W%d has only %d points.', ...
        cfg.fitWindow(1), cfg.fitWindow(2), nnz(fitMask));
end

data = struct();
data.cfg = cfg;
data.data_source = 'ebola-tracker.org database';
data.series = series;
data.N = 38393224;              % 8 provinces, WorldPop 2026 + Nord-Ubangi est.

data.fitWindow = cfg.fitWindow;
data.holdoutWindow = cfg.holdout;
data.t = series.t(fitMask);
data.week = series.week(fitMask);
data.weekEnd = series.weekEnd(fitMask);
data.cases = series.cases(fitMask);
data.deaths = series.deaths(fitMask);
data.casesAdj = series.newCasesAdj(fitMask);
data.deathsAdj = series.newDeathsAdj(fitMask);
data.flags = series.flags(fitMask);

data.fit = struct('t', data.t, 'week', data.week, ...
    'cases', data.cases, 'deaths', data.deaths, ...
    'newCasesAdj', data.casesAdj, 'newDeathsAdj', data.deathsAdj);
data.holdout = struct('t', series.t(holdMask), 'week', series.week(holdMask), ...
    'cases', series.cases(holdMask), 'deaths', series.deaths(holdMask), ...
    'newCasesAdj', series.newCasesAdj(holdMask), ...
    'newDeathsAdj', series.newDeathsAdj(holdMask));

data.endpoint_t = max(series.t);
data.endpoint_cases = series.cases(end);
data.endpoint_deaths = series.deaths(end);

% Latest daily row (may be one or two days ahead of the last Sunday).
if ~isempty(rawFile)
    data.latestDaily = read_latest_daily(rawFile);
    if isfield(data.latestDaily, 'sitrep') && isfinite(data.latestDaily.sitrep)
        data.data_source = sprintf( ...
            'ebola-tracker.org database, latest daily %s (SitRep %d)', ...
            data.latestDaily.date, data.latestDaily.sitrep);
    end
end

% -------------------------------------------------------------------------
% Provinces (8)
% -------------------------------------------------------------------------
P = readtable(provFile, 'Encoding', 'UTF-8', ...
    'VariableNamingRule', 'preserve', 'TextType', 'string');
P.province = canonical_province(P.province);
data.province_table = P;
data.provinces = P.province;
data.province_population = double(P.population);
data.province_cases = double(P.cum_confirmed);
data.province_deaths = double(P.cum_deaths);
data.province_new = double(P.new_confirmed_24h);

if abs(sum(data.province_population) - data.N) > 1
    error('load_data:populationSum', ...
        'Province populations sum to %.0f, expected N=%.0f.', ...
        sum(data.province_population), data.N);
end

targetC = data.cases(end);
targetD = data.deaths(end);
if isfield(data, 'latestDaily')
    targetC = data.latestDaily.cases;
    targetD = data.latestDaily.deaths;
end
if abs(sum(data.province_cases) - targetC) > max(1, 1e-6 * targetC) || ...
        abs(sum(data.province_deaths) - targetD) > max(1, 1e-6 * targetD)
    warning('load_data:provinceSum', ...
        ['Province totals (%.0f / %.0f) differ from the national latest ' ...
        '(%.0f / %.0f); the province file may be a different date.'], ...
        sum(data.province_cases), sum(data.province_deaths), targetC, targetD);
end

% -------------------------------------------------------------------------
% Health zones (66 at 2026-10-25, 67 from 2026-11-08)
% -------------------------------------------------------------------------
Z = readtable(zoneFile, 'Encoding', 'UTF-8', ...
    'VariableNamingRule', 'preserve', 'TextType', 'string');
Z.province = canonical_province(Z.province);
data.zone_table = Z;
data.n_health_zones = height(Z);
data.health_zones = string(Z.health_zone);
data.zone_population = col(Z, 'population', nan(height(Z), 1));
data.zone_population_source = "health_zone_latest";
if all(~isfinite(data.zone_population))
    zsFile = fullfile(cfg.trackerDir, 'zone_summary_to_20261025.csv');
    if isfile(zsFile)
        ZS = readtable(zsFile, 'Encoding', 'UTF-8', ...
            'VariableNamingRule', 'preserve', 'TextType', 'string');
        ZS.province = canonical_province(ZS.province);
        keyZ = lower(Z.province) + "|" + lower(strtrim(string(Z.health_zone)));
        keyS = lower(ZS.province) + "|" + ...
            lower(strtrim(string(ZS.health_zone)));
        [tf, loc] = ismember(keyZ, keyS);
        data.zone_population(tf) = double(ZS.population(loc(tf)));
        data.zone_population_source = "zone_summary_to_20261025";
    end
end
data.zone_as_of = string(Z.as_of(1));
if ~ismember(data.n_health_zones, [66 67])
    warning('load_data:zoneCount', ...
        'Expected 66 or 67 health zones, found %d.', data.n_health_zones);
end

% -------------------------------------------------------------------------
% Response indicators, cross-border cases and HCW series
% -------------------------------------------------------------------------
data.response_table = table();
data.resp = struct('asOf', "", 'alertsReceived', NaN, ...
    'testPositivity', NaN, 'contactsSeenPct', NaN, ...
    'patientsPer100Beds', NaN, 'vaccinatedTotal', NaN, ...
    'travellersScreened', NaN);
if ~isempty(respFile)
    R = readtable(respFile, 'Encoding', 'UTF-8', ...
        'VariableNamingRule', 'preserve', 'TextType', 'string');
    data.response_table = R;
    data.resp.alertsReceived = metric_value(R, 'alerts_received');
    data.resp.testPositivity = metric_value(R, 'test_positivity');
    data.resp.contactsSeenPct = metric_value(R, 'contacts_seen');
    data.resp.patientsPer100Beds = metric_value(R, 'patients_per_100_beds');
    data.resp.vaccinatedTotal = metric_value(R, 'vaccinated_total');
    data.resp.travellersScreened = metric_value(R, 'travellers_screened');
    if any(strcmp(R.Properties.VariableNames, 'as_of'))
        data.resp.asOf = string(R.as_of(1));
    end
end

data.crossBorder = table();
if ~isempty(crossFile)
    data.crossBorder = readtable(crossFile, 'Encoding', 'UTF-8', ...
        'VariableNamingRule', 'preserve', 'TextType', 'string');
end

data.hcw = struct();
if ~isempty(hcwFile)
    H = readtable(hcwFile, 'Encoding', 'UTF-8', ...
        'VariableNamingRule', 'preserve', 'TextType', 'string');
    H.week = week_from_iso(H.week);
    data.hcw.table = H;
    data.hcw.week = double(H.week);
    data.hcw.cases = double(H.hcw_cases);
    data.hcw.deaths = double(H.hcw_deaths);
    data.hcw.beds = double(H.beds);
end

% -------------------------------------------------------------------------
% Initial state at the start of the fit window
% -------------------------------------------------------------------------
[y0, st0] = state_at(data, cfg.fitWindow(1));
data.y0 = y0;
data.state0 = st0;
data.C0 = st0.C;
data.M0 = st0.M;
data.Q0 = st0.Q;
data.R0 = st0.R;
data.E0 = st0.E;
data.D0 = st0.D;
data.I0 = st0.I;
data.S0 = st0.S;
data.Q0_source = st0.q_source;
data.R0_source = st0.r_source;

data.loadedFrom = struct( ...
    'weekly', weeklyFile, 'province', provFile, 'zone', zoneFile, ...
    'response', respFile, 'crossBorder', crossFile, 'hcw', hcwFile, ...
    'raw', rawFile);
end

% =========================================================================
% Legacy workbook branch (W25-W41, 7 provinces)
% =========================================================================
function data = load_legacy(cfg)
xlsx = cfg.legacyWorkbook;
if ~isfile(xlsx)
    error('load_data:noWorkbook', 'Data workbook not found: %s', xlsx);
end

weekly = readtable(xlsx, 'Sheet', 2, 'VariableNamingRule', 'preserve');
iso = string(weekly.iso_week);
mask = iso >= "2026-W25" & iso <= "2026-W41";
w = weekly(mask, :);
w = sortrows(w, 'week_end');
if height(w) ~= 17
    error('load_data:legacyWeeks', ...
        'Expected 17 weekly rows for W25--W41, got %d', height(w));
end

series = struct();
series.t = (0:16)';
series.week = (25:41)';
series.weekEnd = to_datetime(w.week_end);
series.cases = double(w.retro_cum_confirmed);
series.deaths = double(w.retro_cum_deaths);
series.recovered = nan(17, 1);
series.recovered(1) = 112;          % W25 report 6, cumulative recoveries
series.etcAdmitted = nan(17, 1);
series.etcBeds = nan(17, 1);
series.etcOccupancy = nan(17, 1);
series.contactsToFollow = nan(17, 1);
series.contactsSeen = nan(17, 1);
series.contactsSeenPct = nan(17, 1);
series.vaccinatedTotal = nan(17, 1);
series.newCasesRaw = [NaN; diff(series.cases)];
series.newDeathsRaw = [NaN; diff(series.deaths)];
series.newCasesAdj = series.newCasesRaw;
series.newDeathsAdj = series.newDeathsRaw;
series.fixedQ = nan(17, 1);
series.fixedQ(1) = 196;             % W25 confirmed in isolation (report 6)
series.fixedE = nan(17, 1);
series.fixedE(1) = 300;             % W25 scenario stock (reference report)
series.fixedD = nan(17, 1);
series.fixedD(1) = 20;              % W25 scenario stock (reference report)
series.flags = repmat("", 17, 1);
series.sourceFile = xlsx;

data = struct();
data.data_source = 'legacy workbook W25-W41 (WHO AFRO retrospective)';
data.series = series;
data.N = 36893224;                  % seven affected provinces, WorldPop 2026

data.fitWindow = [25 41];
data.holdoutWindow = [];
data.t = series.t;
data.week = series.week;
data.weekEnd = series.weekEnd;
data.cases = series.cases;
data.deaths = series.deaths;
data.casesAdj = series.newCasesAdj;
data.deathsAdj = series.newDeathsAdj;
data.flags = series.flags;
data.fit = struct('t', series.t, 'week', series.week, ...
    'cases', series.cases, 'deaths', series.deaths, ...
    'newCasesAdj', series.newCasesAdj, 'newDeathsAdj', series.newDeathsAdj);
data.holdout = struct('t', zeros(0, 1), 'week', zeros(0, 1), ...
    'cases', zeros(0, 1), 'deaths', zeros(0, 1), ...
    'newCasesAdj', zeros(0, 1), 'newDeathsAdj', zeros(0, 1));

data.endpoint_t = 18;               % W43
data.endpoint_cases = 10060;
data.endpoint_deaths = 4887;

% Health-zone snapshot (66 zones, 7 provinces) for the spatial model.
prov = readtable(xlsx, 'Sheet', 4, 'VariableNamingRule', 'preserve');
data.province_table = prov;
data.provinces = unique(string(prov.province), 'stable');
data.n_health_zones = height(prov);
data.health_zones = string(prov.health_zone);
data.zone_table = prov;
data.zone_population = double(prov.population);
data.zone_as_of = "2026-10-14";

nP = numel(data.provinces);
data.province_population = zeros(nP, 1);
data.province_cases = zeros(nP, 1);
data.province_deaths = zeros(nP, 1);
data.province_new = zeros(nP, 1);
for i = 1:nP
    idx = string(prov.province) == data.provinces(i);
    data.province_population(i) = sum(double(prov.population(idx)), 'omitnan');
    data.province_cases(i) = sum(double(prov.cum_confirmed(idx)), 'omitnan');
    data.province_deaths(i) = sum(double(prov.cum_deaths(idx)), 'omitnan');
    data.province_new(i) = sum(double(prov.new_confirmed(idx)), 'omitnan');
end

% Published anchors.
assert(data.cases(1) == 1193 && data.cases(end) == 9066, ...
    'Weekly case series does not match W25/W41 anchors.');
assert(data.deaths(1) == 535 && data.deaths(end) == 4381, ...
    'Weekly death series does not match W25/W41 anchors.');

data.response_table = table();
data.resp = struct('asOf', "", 'alertsReceived', NaN, ...
    'testPositivity', NaN, 'contactsSeenPct', NaN, ...
    'patientsPer100Beds', NaN, 'vaccinatedTotal', NaN, ...
    'travellersScreened', NaN);
data.crossBorder = table();
data.hcw = struct();

[y0, st0] = state_at(data, 25);
data.y0 = y0;
data.state0 = st0;
data.C0 = st0.C;
data.M0 = st0.M;
data.Q0 = st0.Q;
data.R0 = st0.R;
data.E0 = st0.E;
data.D0 = st0.D;
data.I0 = st0.I;
data.S0 = st0.S;
data.Q0_source = st0.q_source;
data.R0_source = st0.r_source;

data.loadedFrom = struct('workbook', xlsx);
end

% =========================================================================
% Local helpers
% =========================================================================
function f = require_file(dirPath, pattern)
f = latest_tracker_file(dirPath, pattern);
if isempty(f)
    error('load_data:missingFile', ...
        'No file matching %s in %s.', pattern, dirPath);
end
end

function v = col(T, name, default)
if any(strcmp(T.Properties.VariableNames, name))
    v = double(T.(name));
else
    v = default;
end
end

function d = to_datetime(x)
if isdatetime(x)
    d = x;
else
    d = datetime(string(x), 'InputFormat', 'yyyy-MM-dd');
end
end

function p = canonical_province(p)
p = strtrim(string(p));
p = replace(p, ["é", "è", "ê", "ë", "à", "â", "ç", "î", "ï", "ô", "û", "ù"], ...
    ["e", "e", "e", "e", "a", "a", "c", "i", "i", "o", "u", "u"]);
p = regexprep(p, '\s+', ' ');
end

function assert_anchor(series, week, cases, deaths, strict)
if ~strict
    return;
end
idx = find(series.week == week, 1);
if isempty(idx)
    error('load_data:anchorMissing', 'Week W%d missing from the series.', week);
end
if series.cases(idx) ~= cases || series.deaths(idx) ~= deaths
    error('load_data:anchorMismatch', ...
        'W%d anchors are %.0f/%.0f, expected %.0f/%.0f.', ...
        week, series.cases(idx), series.deaths(idx), cases, deaths);
end
end

function v = metric_value(T, name)
v = NaN;
if isempty(T) || ~any(strcmp(T.Properties.VariableNames, 'metric'))
    return;
end
j = find(string(T.metric) == name, 1);
if ~isempty(j)
    v = T.value(j);
end
end

function w = week_from_iso(s)
w = nan(numel(s), 1);
for k = 1:numel(s)
    t = regexp(string(s(k)), 'W(\d+)', 'tokens', 'once');
    if ~isempty(t)
        w(k) = str2double(t{1});
    end
end
end

function s = read_latest_daily(rawFile)
opts = detectImportOptions(rawFile, 'Encoding', 'UTF-8', ...
    'VariableNamingRule', 'preserve', 'TextType', 'string');
want = {'date', 'level', 'sitrep', 'cases', 'deaths', ...
    'new_cases', 'new_deaths', 'recovered', 'etc_admitted'};
opts.SelectedVariableNames = want(ismember(want, opts.VariableNames));
T = readtable(rawFile, opts);
T = T(lower(strtrim(string(T.level))) == "country", :);
T.date = datetime(string(T.date), 'InputFormat', 'yyyy-MM-dd');
T = sortrows(T, 'date');
valid = ~isnan(T.cases) & ~isnan(T.deaths);
T = T(valid, :);
a = T(end, :);

s = struct();
s.date = string(a.date, 'yyyy-MM-dd');
s.cases = a.cases;
s.deaths = a.deaths;
s.new_cases = getnum(a, 'new_cases');
s.new_deaths = getnum(a, 'new_deaths');
s.recovered = getnum(a, 'recovered');
s.etc_admitted = getnum(a, 'etc_admitted');
s.sitrep = getnum(a, 'sitrep');
end

function v = getnum(a, name)
if any(strcmp(a.Properties.VariableNames, name))
    v = a.(name);
else
    v = NaN;
end
end
