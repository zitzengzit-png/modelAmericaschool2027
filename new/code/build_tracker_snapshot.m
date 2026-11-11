function snap = build_tracker_snapshot(rawFile, outDir, tag, opts)
%BUILD_TRACKER_SNAPSHOT  Derive model-ready CSVs from the raw tracker database.
%
%   snap = build_tracker_snapshot(rawFile, outDir, tag)
%   snap = build_tracker_snapshot(rawFile, outDir, tag, opts)
%
%   Outputs (written to outDir)
%     national_weekly_<tag>.csv
%     province_latest_<tag>.csv
%     health_zone_latest_<tag>.csv
%     response_latest_<tag>.csv
%     snapshot_metadata_<tag>.json
%
%   Rules (validated against national_weekly_20261108.csv: zero difference)
%     - weekly anchor = latest valid country row on or before each Sunday
%     - new_* = difference from the previous weekly anchor
%     - new_*_adj = sum of daily new_* in the week, excluding rows whose
%       note contains catch-up or harmonisation
%     - only complete Sundays up to the latest data are written

if nargin < 3 || isempty(tag)
    tag = char(datetime('now', 'Format', 'yyyyMMdd'));
end
if nargin < 4 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'startSunday', datetime(2026, 6, 21));
opts = set_default(opts, 'startWeek', 25);
opts = set_default(opts, 'populationFile', '');
opts = set_default(opts, 'zonePopulationFile', ...
    fullfile(fileparts(rawFile), 'zone_summary_to_20261025.csv'));

if ~isfile(rawFile)
    error('build_tracker_snapshot:noFile', 'Raw database not found: %s', rawFile);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% -------------------------------------------------------------------------
% Read and normalise
% -------------------------------------------------------------------------
T = readtable(rawFile, 'Encoding', 'UTF-8', ...
    'VariableNamingRule', 'preserve', 'TextType', 'string');
T.date = parse_date(T.date);
T.level = lower(strtrim(string(T.level)));
T.note = fill_string(T.note);
T.province = fill_string(T.province);
T.zone = fill_string(T.zone);

country = T(T.level == "country", :);
country = sortrows(country, 'date');
valid = ~isnan(country.cases) & ~isnan(country.deaths);
if ~any(valid)
    error('build_tracker_snapshot:noCountry', ...
        'No country rows with both cases and deaths in %s', rawFile);
end
maxDate = max(country.date(valid));
lastSunday = maxDate - days(weekday(maxDate) - 1);   % weekday: Sunday = 1
sundays = (opts.startSunday:days(7):lastSunday)';
if isempty(sundays)
    error('build_tracker_snapshot:noWeeks', ...
        'No complete Sunday between %s and %s', ...
        string(opts.startSunday), string(lastSunday));
end

% -------------------------------------------------------------------------
% Weekly national anchors
% -------------------------------------------------------------------------
n = numel(sundays);
week = (opts.startWeek:opts.startWeek + n - 1)';
weekEnd = strings(n, 1);
sourceDate = strings(n, 1);
sitrep = nan(n, 1);
cumC = nan(n, 1);
cumD = nan(n, 1);
newC = nan(n, 1);
newD = nan(n, 1);
adjC = nan(n, 1);
adjD = nan(n, 1);
recovered = nan(n, 1);
etcAdmitted = nan(n, 1);
etcBeds = nan(n, 1);
etcOccupancy = nan(n, 1);
contactsToFollow = nan(n, 1);
contactsSeen = nan(n, 1);
contactsSeenPct = nan(n, 1);
vaccinatedTotal = nan(n, 1);
flag = strings(n, 1);
prev = [];

for k = 1:n
    s = sundays(k);
    cand = country(valid & country.date <= s, :);
    if isempty(cand)
        error('build_tracker_snapshot:noAnchor', ...
            'No valid country row on or before %s', string(s));
    end
    a = cand(end, :);

    weekEnd(k) = string(s, 'yyyy-MM-dd');
    sourceDate(k) = string(a.date, 'yyyy-MM-dd');
    sitrep(k) = a.sitrep;
    cumC(k) = a.cases;
    cumD(k) = a.deaths;
    if isempty(prev)
        newC(k) = NaN;
        newD(k) = NaN;
    else
        newC(k) = a.cases - prev.cases;
        newD(k) = a.deaths - prev.deaths;
    end

    wk = country(country.date > s - days(7) & country.date <= s, :);
    excluded = contains(wk.note, "catch-up") | contains(wk.note, "harmonisation");
    adjC(k) = sum(wk.new_cases(~excluded), 'omitnan');
    adjD(k) = sum(wk.new_deaths(~excluded), 'omitnan');

    recovered(k) = a.recovered;
    etcAdmitted(k) = a.etc_admitted;
    etcBeds(k) = a.etc_beds;
    etcOccupancy(k) = a.etc_occupancy;
    contactsToFollow(k) = a.contacts_to_follow;
    contactsSeen(k) = a.contacts_seen;
    contactsSeenPct(k) = a.contacts_seen_pct;
    vaccinatedTotal(k) = a.vaccinated_total;

    if a.date == s
        flag(k) = "week_end_exact";
    else
        flag(k) = "latest_valid_before_week_end";
    end
    if any(excluded)
        flag(k) = flag(k) + ";adjusted_excludes_catchup_harmonisation";
    end
    if isempty(wk)
        flag(k) = flag(k) + ";no_report_in_week";
    end
    prev = a;
end

cfr = 100 * cumD ./ cumC;
isoWeek = string(sundays, 'yyyy') + "-W" + string(week);

W = table(week, weekEnd, isoWeek, sourceDate, sitrep, cumC, cumD, cfr, ...
    newC, newD, adjC, adjD, recovered, etcAdmitted, etcBeds, etcOccupancy, ...
    contactsToFollow, contactsSeen, contactsSeenPct, vaccinatedTotal, flag, ...
    'VariableNames', {'week', 'week_end', 'iso_week', 'source_date', ...
    'sitrep', 'cum_confirmed', 'cum_deaths', 'cfr', 'new_confirmed', ...
    'new_deaths', 'new_confirmed_adj', 'new_deaths_adj', 'recovered', ...
    'etc_admitted', 'etc_beds', 'etc_occupancy', 'contacts_to_follow', ...
    'contacts_seen', 'contacts_seen_pct', 'vaccinated_total', 'flag'});

writetable(W, fullfile(outDir, sprintf('national_weekly_%s.csv', tag)), ...
    'Encoding', 'UTF-8');

% -------------------------------------------------------------------------
% Latest zone snapshot
% -------------------------------------------------------------------------
zone = T(T.level == "zone", :);
if isempty(zone)
    error('build_tracker_snapshot:noZone', 'No zone rows in %s', rawFile);
end
zDate = max(zone.date);
ZL = zone(zone.date == zDate, :);
ZL.province = canonical_province(ZL.province);
ZL.zone = strtrim(string(ZL.zone));

zonePop = nan(height(ZL), 1);
if ~isempty(opts.zonePopulationFile) && isfile(opts.zonePopulationFile)
    ZP = readtable(opts.zonePopulationFile, 'Encoding', 'UTF-8', ...
        'VariableNamingRule', 'preserve', 'TextType', 'string');
    ZP.province = canonical_province(ZP.province);
    keyL = lower(ZL.province) + "|" + lower(strtrim(ZL.zone));
    keyP = lower(ZP.province) + "|" + lower(strtrim(string(ZP.health_zone)));
    [tf, loc] = ismember(keyL, keyP);
    zonePop(tf) = ZP.population(loc(tf));
end

ZLout = table(ZL.province, ZL.zone, ZL.cases, ZL.new_cases, ...
    ZL.deaths, ZL.new_deaths, 100 * ZL.deaths ./ ZL.cases, zonePop, ...
    repmat(string(zDate, 'yyyy-MM-dd'), height(ZL), 1), ZL.sitrep, ...
    'VariableNames', {'province', 'health_zone', 'cum_confirmed', ...
    'new_confirmed_24h', 'cum_deaths', 'new_deaths_24h', 'cfr', ...
    'population', 'as_of', 'sitrep'});
writetable(ZLout, ...
    fullfile(outDir, sprintf('health_zone_latest_%s.csv', tag)), ...
    'Encoding', 'UTF-8');

% -------------------------------------------------------------------------
% Latest province snapshot
% -------------------------------------------------------------------------
CANON = ["Bas-Uele"; "Haut-Uele"; "Ituri"; "Nord-Kivu"; ...
    "Nord-Ubangi"; "Sud-Kivu"; "Sud-Ubangi"; "Tshopo"];
nP = numel(CANON);
POP = [2032860; 3361576; 6556455; 9095202; ...
    1500000; 7879065; 3808453; 4159613];
POP_SRC = ["WorldPop2026_7prov"; "WorldPop2026_7prov"; ...
    "WorldPop2026_7prov"; "WorldPop2026_7prov"; "estimate_1.5M"; ...
    "WorldPop2026_7prov"; "WorldPop2026_7prov"; "WorldPop2026_7prov"];
Z_TOTAL = [11; 13; 36; 34; 11; 34; 16; 23];

if ~isempty(opts.populationFile) && isfile(opts.populationFile)
    P0 = readtable(opts.populationFile, 'Encoding', 'UTF-8', ...
        'VariableNamingRule', 'preserve', 'TextType', 'string');
    P0.province = canonical_province(P0.province);
    hasZones = any(strcmp(P0.Properties.VariableNames, 'zones_total'));
    for k = 1:nP
        idx = find(P0.province == CANON(k), 1);
        if isempty(idx)
            continue;
        end
        POP(k) = P0.population(idx);
        POP_SRC(k) = string(P0.population_source(idx));
        if hasZones
            Z_TOTAL(k) = P0.zones_total(idx);
        end
    end
end

prov = T(T.level == "province", :);
prov.province = canonical_province(prov.province);
prov = sortrows(prov, 'date');
pDate = max(prov.date);
PL = prov(prov.date == pDate, :);
PL.province = canonical_province(PL.province);

cumP = nan(nP, 1);
deathsP = nan(nP, 1);
new24 = nan(nP, 1);
newD24 = nan(nP, 1);
sitrepP = nan(nP, 1);
new30 = nan(nP, 1);
newD30 = nan(nP, 1);
zAff = zeros(nP, 1);

for k = 1:nP
    idx = find(PL.province == CANON(k), 1, 'last');
    if isempty(idx)
        warning('build_tracker_snapshot:missingProvince', ...
            'Province not reported on %s: %s', string(pDate), CANON(k));
        continue;
    end
    cumP(k) = PL.cases(idx);
    deathsP(k) = PL.deaths(idx);
    new24(k) = PL.new_cases(idx);
    newD24(k) = PL.new_deaths(idx);
    sitrepP(k) = PL.sitrep(idx);

    sub = prov(prov.province == CANON(k) & prov.date <= pDate - days(30) ...
        & ~isnan(prov.cases), :);
    if ~isempty(sub)
        baseRow = sub(end, :);
        new30(k) = cumP(k) - baseRow.cases;
        newD30(k) = deathsP(k) - baseRow.deaths;
    else
        sub2 = prov(prov.province == CANON(k) & prov.date > pDate - days(30) ...
            & prov.date <= pDate, :);
        new30(k) = sum(sub2.new_cases, 'omitnan');
        newD30(k) = sum(sub2.new_deaths, 'omitnan');
    end

    zAff(k) = sum(ZL.province == CANON(k) & ZL.cases > 0);
end

PLout = table(CANON, POP, POP_SRC, cumP, 100 * cumP / sum(cumP, 'omitnan'), ...
    new24, new30, deathsP, newD24, newD30, 100 * deathsP ./ cumP, ...
    zAff, Z_TOTAL, repmat(string(pDate, 'yyyy-MM-dd'), nP, 1), sitrepP, ...
    'VariableNames', {'province', 'population', 'population_source', ...
    'cum_confirmed', 'share_pct', 'new_confirmed_24h', ...
    'new_confirmed_30d', 'cum_deaths', 'new_deaths_24h', ...
    'new_deaths_30d', 'cfr', 'zones_affected', 'zones_total', ...
    'as_of', 'sitrep'});
writetable(PLout, ...
    fullfile(outDir, sprintf('province_latest_%s.csv', tag)), ...
    'Encoding', 'UTF-8');

% -------------------------------------------------------------------------
% Latest response indicators
%   preferred: headline numbers scraped from the data page (opts.responseTable)
%   fallback : last 7 bulletins in the raw database
% -------------------------------------------------------------------------
prevResp = latest_tracker_file(outDir, 'response_latest_*.csv');
RP = table();
if ~isempty(prevResp)
    RP = readtable(prevResp, 'Encoding', 'UTF-8', ...
        'VariableNamingRule', 'preserve', 'TextType', 'string');
end

if isfield(opts, 'responseTable') && ~isempty(opts.responseTable)
    R = opts.responseTable;
    if ~any(strcmp(R.Properties.VariableNames, 'source'))
        R.source = repmat("data page", height(R), 1);
    end
else
    recent = country(valid & country.date > maxDate - days(7), :);
    alerts = sum(recent.alerts_received, 'omitnan');

    labPos = sum(recent.lab_positives, 'omitnan');
    labSam = sum(recent.lab_samples, 'omitnan');
    labSamDays = sum(isfinite(recent.lab_samples));
    if labSam > 0 && labPos / labSam < 1 && labSamDays >= 3
        positivity = 100 * labPos / labSam;
    else
        positivity = carried_metric(RP, "test_positivity");
    end

    seenNum = sum(recent.contacts_seen, 'omitnan');
    seenDen = sum(recent.contacts_to_follow, 'omitnan');
    if seenDen > 0
        seenPct = 100 * seenNum / seenDen;
    else
        seenPct = carried_metric(RP, "contacts_seen");
    end

    bedRatio = 100 * recent.etc_admitted ./ recent.etc_beds;
    bedRatio = bedRatio(isfinite(bedRatio));
    if isempty(bedRatio)
        per100Beds = carried_metric(RP, "patients_per_100_beds");
    else
        per100Beds = median(bedRatio);
    end

    % Cumulative vaccination: latest non-missing value per province, then sum.
    vacc = 0;
    for k = 1:nP
        sub = prov(prov.province == CANON(k) & ~isnan(prov.vaccinated_total), :);
        if ~isempty(sub)
            vacc = vacc + sub.vaccinated_total(end);
        end
    end
    if ~(vacc > 0)
        vacc = carried_metric(RP, "vaccinated_total");
    end

    trav = carried_metric(RP, "travellers_screened");

    metric = ["alerts_received"; "test_positivity"; "contacts_seen"; ...
        "patients_per_100_beds"; "vaccinated_total"; "travellers_screened"];
    value = [alerts; positivity; seenPct; per100Beds; vacc; trav];
    unit = ["alerts"; "%"; "%"; "patients/100 beds"; "people"; "people"];
    period = ["last 7 bulletins"; "last 7 bulletins"; "last 7 bulletins"; ...
        "latest"; "cumulative"; "last bulletin"];
    as_of = repmat(string(maxDate, 'yyyy-MM-dd'), numel(metric), 1);
    source = ["database"; "database"; "database"; "database"; ...
        "database"; "carried forward"];
    R = table(metric, value, unit, period, as_of, source, ...
        'VariableNames', {'metric', 'value', 'unit', 'period', 'as_of', 'source'});
end

writetable(R, fullfile(outDir, sprintf('response_latest_%s.csv', tag)), ...
    'Encoding', 'UTF-8');

% -------------------------------------------------------------------------
% Latest daily row and metadata
% -------------------------------------------------------------------------
lastIdx = find(valid, 1, 'last');
a = country(lastIdx, :);
latestDaily = struct( ...
    'date', string(a.date, 'yyyy-MM-dd'), ...
    'cases', a.cases, 'deaths', a.deaths, ...
    'new_cases', a.new_cases, 'new_deaths', a.new_deaths, ...
    'recovered', a.recovered, 'etc_admitted', a.etc_admitted, ...
    'sitrep', a.sitrep);

meta = struct();
meta.tag = tag;
meta.raw_file = rawFile;
meta.built_utc = string(datetime('now', 'TimeZone', 'UTC'), ...
    'yyyy-MM-dd''T''HH:mm:ss');
meta.max_date = string(maxDate, 'yyyy-MM-dd');
meta.rows_total = height(T);
meta.rows_country = height(country);
meta.rows_province = height(prov);
meta.rows_zone = height(zone);
meta.weekly_rows = height(W);
meta.week_range = [week(1) week(end)];
meta.latest_daily = latestDaily;
meta.rules = struct( ...
    'weekly_anchor', 'latest valid country row on or before Sunday', ...
    'new', 'difference from previous weekly anchor', ...
    'adjusted', 'sum of daily new_* excluding catch-up/harmonisation', ...
    'zones', 'latest date with zone rows', ...
    'province_population', 'WorldPop 2026; Nord-Ubangi 1.5M estimate');

fid = fopen(fullfile(outDir, sprintf('snapshot_metadata_%s.json', tag)), 'w');
fprintf(fid, '%s', jsonencode(meta, 'PrettyPrint', true));
fclose(fid);

snap = struct('tag', tag, 'nationalWeekly', W, 'provinceLatest', PLout, ...
    'zoneLatest', ZLout, 'responseLatest', R, 'meta', meta);
end

% -------------------------------------------------------------------------
% Local functions
% -------------------------------------------------------------------------
function s = set_default(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end

function d = parse_date(x)
if isdatetime(x)
    d = x;
elseif isstring(x) || ischar(x)
    d = datetime(string(x), 'InputFormat', 'yyyy-MM-dd');
elseif iscell(x)
    d = datetime(string(x), 'InputFormat', 'yyyy-MM-dd');
else
    error('build_tracker_snapshot:badDate', 'Cannot parse date column.');
end
d = dateshift(d, 'start', 'day');
end

function p = canonical_province(p)
p = strtrim(string(p));
p = replace(p, ["é", "è", "ê", "ë", "à", "â", "ç", "î", "ï", "ô", "û", "ù"], ...
    ["e", "e", "e", "e", "a", "a", "c", "i", "i", "o", "u", "u"]);
p = regexprep(p, '\s+', ' ');
end

function s = fill_string(s)
s = string(s);
s(ismissing(s)) = "";
end

function v = carried_metric(T, name)
v = NaN;
if isempty(T) || ~any(strcmp(T.Properties.VariableNames, 'metric'))
    return;
end
j = find(string(T.metric) == name, 1);
if ~isempty(j)
    v = T.value(j);
end
end


