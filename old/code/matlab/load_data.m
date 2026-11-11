function data = load_data(useTracker)
%LOAD_DATA  Load the active legacy workbook, or the optional tracker source.
%   data = load_data()      uses the legacy W25-W41 workbook (default).
%   data = load_data(true)  uses ebola-tracker W25-W45.
%
% The tracker files are auxiliary; the active model uses the old workbook.
%   ws/data/outbreak_data.xlsx is an ASCII-named copy of the final workbook.
%   Sheet indices are used so that the MATLAB source stays ASCII-only.
%
%   Sheet 2 = weekly retrospective series (W20--W41)
%   Sheet 4 = health-zone snapshot (66 zones, 7 provinces)
%   The Problem A endpoint (25--26 Oct 2026: 10,060 cases, 4,887 deaths)
%   is kept as a holdout rather than interpolated into invented weeks.

root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % ws

% -------------------------------------------------------------------------
% Data-source switch.
% false = legacy workbook W25-W41 (current active model, 7 provinces)
% true  = ebola-tracker.org W25-W45 (new data, 8 provinces/67 zones)
% -------------------------------------------------------------------------
if nargin < 1 || isempty(useTracker)
    useTracker = false;
end

% -------------------------------------------------------------------------
% Optional source: ebola-tracker.org database, as of 2026-11-08.
% The old workbook remains the active source when useTracker is false.
% -------------------------------------------------------------------------
trackerDir = fullfile(root, 'data', 'ebola_tracker');
weeklyCsv = fullfile(trackerDir, 'national_weekly_20261108.csv');
provCsv = fullfile(trackerDir, 'province_latest_20261108.csv');

if useTracker && isfile(weeklyCsv)
    weekly = readtable(weeklyCsv, 'Encoding', 'UTF-8', ...
        'VariableNamingRule', 'preserve');
    weekly = sortrows(weekly, 'week');
    assert(height(weekly) == 21, 'Expected 21 weekly rows W25-W45.');

    data.t = (0:height(weekly) - 1)';
    data.week = double(weekly.week);
    data.cases = double(weekly.cum_confirmed);
    data.deaths = double(weekly.cum_deaths);
    data.cfr = double(weekly.cfr);
    data.recovered = double(weekly.recovered);
    data.etc_admitted = double(weekly.etc_admitted);
    data.contacts_seen_pct = double(weekly.contacts_seen_pct);
    data.vaccinated_total = double(weekly.vaccinated_total);
    data.weekly_cases_raw = double(weekly.new_confirmed);
    data.weekly_deaths_raw = double(weekly.new_deaths);
    data.weekly_cases_adj = double(weekly.new_confirmed_adj);
    data.weekly_deaths_adj = double(weekly.new_deaths_adj);
    data.source_date = string(weekly.source_date);
    data.flags = string(weekly.flag);
    data.data_source = 'ebola-tracker.org database, SitRep 178, as of 2026-11-08';

    if isdatetime(weekly.week_end)
        data.week_end = weekly.week_end;
    else
        data.week_end = datetime(string(weekly.week_end), ...
            'InputFormat', 'yyyy-MM-dd');
    end

    data.endpoint_t = height(weekly) - 1;
    data.endpoint_cases = data.cases(end);
    data.endpoint_deaths = data.deaths(end);

    % W25 initial state. Q0 is the confirmed-in-isolation value from report 6;
    % R0 is the tracker's country-level recovered count at 2026-06-21.
    data.C0 = data.cases(1);
    data.M0 = data.deaths(1);
    data.Q0 = 196;
    data.R0 = 360;
    data.E0 = 300;
    data.D0 = 20;
    data.I0 = data.C0 - data.Q0 - data.R0 - data.M0;

    if isfile(provCsv)
        prov = readtable(provCsv, 'Encoding', 'UTF-8', ...
            'VariableNamingRule', 'preserve');
        data.province_table = prov;
        data.provinces = unique(string(prov.province), 'stable');
        data.n_health_zones = 67;
        data.province_population = double(prov.population);
        data.province_cases = double(prov.cum_confirmed);
        data.province_deaths = double(prov.cum_deaths);
        data.province_new = double(prov.new_confirmed_24h);
        data.N = sum(data.province_population, 'omitnan');
    else
        data.province_table = table();
        data.provinces = strings(0, 1);
        data.n_health_zones = 67;
        data.province_population = zeros(0, 1);
        data.province_cases = zeros(0, 1);
        data.province_deaths = zeros(0, 1);
        data.province_new = zeros(0, 1);
        data.N = 38393224;
    end

    data.S0 = data.N - data.C0 - data.E0;
    data.y0 = [data.S0; data.E0; data.I0; data.Q0; ...
        data.R0; data.D0; data.M0];

    assert(data.cases(1) == 1048 && data.cases(end) == 10990, ...
        'Tracker weekly case anchors do not match W25/W45.');
    assert(data.deaths(1) == 267 && data.deaths(end) == 5354, ...
        'Tracker weekly death anchors do not match W25/W45.');
    return;
end

% -------------------------------------------------------------------------
% Active source: legacy workbook snapshot (W25-W41).
% -------------------------------------------------------------------------
xlsx = fullfile(root, 'data', 'outbreak_data.xlsx');
if ~isfile(xlsx)
    error('Data workbook not found: %s', xlsx);
end

weekly = readtable(xlsx, 'Sheet', 2, 'VariableNamingRule', 'preserve');
iso = string(weekly.iso_week);
mask = iso >= "2026-W25" & iso <= "2026-W41";
w = weekly(mask, :);
w = sortrows(w, 'week_end');

if height(w) ~= 17
    error('Expected 17 weekly rows for W25--W41, got %d', height(w));
end

data.t = (0:16)';
data.week = (25:41)';
data.cases = double(w.retro_cum_confirmed);
data.deaths = double(w.retro_cum_deaths);
data.week_end = w.week_end;
data.N = 36893224;                 % seven affected provinces, WorldPop 2026
data.endpoint_t = 18;              % W43; W42 is not a complete report week
data.endpoint_cases = 10060;
data.endpoint_deaths = 4887;

% Initial state at W25 (sheet 08 / report 6).
data.C0 = 1193;
data.M0 = 535;
data.Q0 = 196;
data.R0 = 112;
data.E0 = 300;
data.D0 = 20;
data.I0 = data.C0 - data.Q0 - data.R0 - data.M0;
data.S0 = data.N - data.C0 - data.E0;
data.y0 = [data.S0; data.E0; data.I0; data.Q0; data.R0; data.D0; data.M0];
data.data_source = 'legacy workbook W25-W41 (WHO AFRO retrospective)';

% Health-zone snapshot (66 zones, 7 provinces) for the spatial model.
prov = readtable(xlsx, 'Sheet', 4, 'VariableNamingRule', 'preserve');
data.province_table = prov;
data.provinces = unique(string(prov.province), 'stable');
data.n_health_zones = height(prov);

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

% Basic integrity checks against the published series.
assert(data.cases(1) == 1193 && data.cases(end) == 9066, ...
    'Weekly case series does not match W25/W41 anchors.');
assert(data.deaths(1) == 535 && data.deaths(end) == 4381, ...
    'Weekly death series does not match W25/W41 anchors.');
end
