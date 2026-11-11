%% P0: data and configuration acceptance check (daily standard)
% Run from ws/new/code:  p0_check
% Writes ws/new/outputs/p0/P0_*.csv|json
clear; clc;

cfg = config();
fprintf('=== P0 daily data check ===\n');
fprintf('data source : %s\n', cfg.dataSource);
fprintf('time unit   : %s\n', cfg.timeUnit);
fprintf('fit window  : %s .. %s\n', ...
    string(cfg.fitStart, 'yyyy-MM-dd'), string(cfg.fitEnd, 'yyyy-MM-dd'));
fprintf('holdout     : %s .. %s\n', ...
    string(cfg.holdStart, 'yyyy-MM-dd'), string(cfg.holdEnd, 'yyyy-MM-dd'));

data = load_data(cfg);

fprintf('\n--- files ---\n');
fn = fieldnames(data.loadedFrom);
for k = 1:numel(fn)
    fprintf('%-12s %s\n', fn{k}, data.loadedFrom.(fn{k}));
end

fprintf('\n--- daily series ---\n');
fprintf('source      : %s\n', data.data_source);
fprintf('days        : %s .. %s (%d rows, fit %d, holdout %d)\n', ...
    string(data.daily.date(1), 'yyyy-MM-dd'), ...
    string(data.daily.date(end), 'yyyy-MM-dd'), numel(data.daily.date), ...
    numel(data.t), numel(data.holdout.t));
fprintf('N           : %.0f\n', data.N);
fprintf('provinces   : %d\n', numel(data.provinces));
fprintf('zones       : %d (as of %s)\n', data.n_health_zones, data.zone_as_of);

% -------------------------------------------------------------------------
% 1. Published daily anchors
% -------------------------------------------------------------------------
anchorDates = [datetime(2026, 6, 21); datetime(2026, 10, 25); ...
    datetime(2026, 11, 9)];
anchorC = [1048; 10060; 11042];
anchorD = [267; 4887; 5387];
checkName = strings(0, 1);
checkStatus = strings(0, 1);
checkDetail = strings(0, 1);

for k = 1:numel(anchorDates)
    idx = find(data.daily.date == anchorDates(k), 1);
    ok = ~isempty(idx) && data.daily.cases(idx) == anchorC(k) && ...
        data.daily.deaths(idx) == anchorD(k);
    checkName(end + 1, 1) = "anchor_" + ...
        string(anchorDates(k), 'yyyy-MM-dd'); %#ok<SAGROW>
    checkStatus(end + 1, 1) = pass_fail(ok); %#ok<SAGROW>
    checkDetail(end + 1, 1) = sprintf('%.0f / %.0f (expected %.0f / %.0f)', ...
        data.daily.cases(idx), data.daily.deaths(idx), ...
        anchorC(k), anchorD(k)); %#ok<SAGROW>
end

% 2,073-case counterfactual anchor (daily interpolation).
idx2073 = find(data.daily.cases >= 2073, 1);
if idx2073 > 1
    c0 = data.daily.cases(idx2073 - 1);
    c1 = data.daily.cases(idx2073);
    d0 = data.daily.date(idx2073 - 1);
    d1 = data.daily.date(idx2073);
    frac = (2073 - c0) / (c1 - c0);
    crossDate = d0 + frac * (d1 - d0);
    fprintf('\n2,073 cases : between %s (%.0f) and %s (%.0f)\n', ...
        string(d0, 'yyyy-MM-dd'), c0, string(d1, 'yyyy-MM-dd'), c1);
    fprintf('              interpolated date %s (use %s as the anchor)\n', ...
        string(crossDate, 'yyyy-MM-dd'), string(d0, 'yyyy-MM-dd'));
end

% -------------------------------------------------------------------------
% 2. Daily state reconstruction at key dates
% -------------------------------------------------------------------------
keyDates = [datetime(2026, 6, 21); datetime(2026, 7, 13); ...
    datetime(2026, 7, 14); datetime(2026, 8, 9); datetime(2026, 10, 11); ...
    datetime(2026, 10, 25); datetime(2026, 11, 8); datetime(2026, 11, 9)];
ST = build_state_table(data, keyDates);
disp(ST);
writetable(ST, fullfile(cfg.outDir, 'P0_state_reconstruction.csv'));

ALL = build_state_table(data, data.daily.date);
writetable(ALL, fullfile(cfg.outDir, 'P0_daily_report.csv'));

consErr = max(abs(ALL.conservation_error));
caseErr = max(abs(ALL.I + ALL.Q + ALL.R + ALL.M - ALL.C));
checkName(end + 1, 1) = "conservation";
checkStatus(end + 1, 1) = pass_fail(consErr < 1e-6 * data.N);
checkDetail(end + 1, 1) = sprintf('max |S+E+I+Q+R+M-N| = %.3g', consErr);
checkName(end + 1, 1) = "case_identity";
checkStatus(end + 1, 1) = pass_fail(caseErr < 1e-6);
checkDetail(end + 1, 1) = sprintf('max |I+Q+R+M-C| = %.3g', caseErr);

% -------------------------------------------------------------------------
% 3. Weekly aggregation validation (daily -> Sunday anchors)
% -------------------------------------------------------------------------
Wk = data.seriesWeekly;
nWk = numel(Wk.week);
maxDiffC = 0;
maxDiffD = 0;
missingWeeks = 0;
for k = 1:nWk
    idx = find(data.daily.date == Wk.weekEnd(k), 1);
    if isempty(idx)
        missingWeeks = missingWeeks + 1;
        continue;
    end
    maxDiffC = max(maxDiffC, abs(data.daily.cases(idx) - Wk.cases(k)));
    maxDiffD = max(maxDiffD, abs(data.daily.deaths(idx) - Wk.deaths(k)));
end
fprintf('\nweekly validation: %d anchors, missing %d, max |dC| %.0f, max |dD| %.0f\n', ...
    nWk, missingWeeks, maxDiffC, maxDiffD);
checkName(end + 1, 1) = "weekly_aggregation";
checkStatus(end + 1, 1) = pass_fail(missingWeeks == 0 && ...
    maxDiffC == 0 && maxDiffD == 0);
checkDetail(end + 1, 1) = sprintf('%d anchors, max diff %.0f/%.0f', ...
    nWk, maxDiffC, maxDiffD);

% -------------------------------------------------------------------------
% 4. Provinces and zones
% -------------------------------------------------------------------------
P = data.province_table;
fprintf('\n--- provinces (as of %s) ---\n', string(P.as_of(1)));
disp(P(:, {'province', 'population', 'cum_confirmed', 'share_pct', ...
    'cum_deaths', 'new_confirmed_30d', 'zones_affected'}));
fprintf('province sums: %.0f cases / %.0f deaths | population %.0f\n', ...
    sum(P.cum_confirmed), sum(P.cum_deaths), sum(P.population));

checkName(end + 1, 1) = "province_population_sum"; %#ok<SAGROW>
checkStatus(end + 1, 1) = pass_fail(abs(sum(P.population) - data.N) < 1); %#ok<SAGROW>
checkDetail(end + 1, 1) = sprintf('sum %.0f vs N %.0f', ...
    sum(P.population), data.N); %#ok<SAGROW>

Z = data.zone_table;
Z.population = data.zone_population;
Z = sortrows(Z, 'cum_confirmed', 'descend');
fprintf('\n--- top 5 health zones ---\n');
disp(Z(1:min(5, height(Z)), {'province', 'health_zone', ...
    'cum_confirmed', 'cum_deaths', 'population'}));
fprintf('zone cases sum %.0f, deaths sum %.0f (unassigned deaths stay at province level)\n', ...
    sum(Z.cum_confirmed), sum(Z.cum_deaths));

checkName(end + 1, 1) = "zone_count"; %#ok<SAGROW>
checkStatus(end + 1, 1) = pass_fail(ismember(data.n_health_zones, [66 67])); %#ok<SAGROW>
checkDetail(end + 1, 1) = sprintf('%d zones, %d with population', ...
    data.n_health_zones, sum(isfinite(data.zone_population))); %#ok<SAGROW>

% -------------------------------------------------------------------------
% 5. Response, cross-border and HCW series
% -------------------------------------------------------------------------
fprintf('\n--- response indicators (as of %s) ---\n', data.resp.asOf);
disp(data.response_table);

if ~isempty(data.crossBorder)
    fprintf('--- cross-border ---\n');
    disp(data.crossBorder);
    checkName(end + 1, 1) = "cross_border_rows"; %#ok<SAGROW>
    checkStatus(end + 1, 1) = pass_fail(height(data.crossBorder) >= 2); %#ok<SAGROW>
    checkDetail(end + 1, 1) = sprintf('%d countries', ...
        height(data.crossBorder)); %#ok<SAGROW>
end

if isfield(data.hcw, 'week') && ~isempty(data.hcw.week)
    fprintf('HCW series  : W%d-W%d, cases %d -> %d, deaths %d -> %d\n', ...
        data.hcw.week(1), data.hcw.week(end), data.hcw.cases(1), ...
        data.hcw.cases(end), data.hcw.deaths(1), data.hcw.deaths(end));
end

% -------------------------------------------------------------------------
% 6. Legacy branch regression (weekly workbook must still load)
% -------------------------------------------------------------------------
fprintf('\n--- legacy branch regression ---\n');
L = load_data(false);
legacyOk = L.cases(1) == 1193 && L.deaths(1) == 535 && ...
    L.cases(end) == 9066 && L.deaths(end) == 4381 && ...
    abs(L.Q0 - 196) < 1e-9 && abs(L.I0 - 350) < 1e-9 && ...
    abs(L.R0 - 112) < 1e-9 && abs(L.E0 - 300) < 1e-9 && ...
    abs(L.D0 - 20) < 1e-9;
fprintf('W25/W41 anchors : %.0f/%.0f -> %.0f/%.0f\n', ...
    L.cases(1), L.deaths(1), L.cases(end), L.deaths(end));
fprintf('W25 state       : S %.0f E %.0f I %.0f Q %.0f R %.0f D %.0f M %.0f\n', ...
    L.S0, L.E0, L.I0, L.Q0, L.R0, L.D0, L.M0);
checkName(end + 1, 1) = "legacy_regression"; %#ok<SAGROW>
checkStatus(end + 1, 1) = pass_fail(legacyOk); %#ok<SAGROW>
checkDetail(end + 1, 1) = "W25 1193/535, W41 9066/4381, Q0=196, I0=350"; %#ok<SAGROW>

% -------------------------------------------------------------------------
% 7. Coverage and special days
% -------------------------------------------------------------------------
nDays = numel(data.daily.date);
checkName(end + 1, 1) = "daily_coverage"; %#ok<SAGROW>
checkStatus(end + 1, 1) = pass_fail(nDays >= 140); %#ok<SAGROW>
checkDetail(end + 1, 1) = sprintf('%d days, %s..%s', nDays, ...
    string(data.daily.date(1), 'yyyy-MM-dd'), ...
    string(data.daily.date(end), 'yyyy-MM-dd')); %#ok<SAGROW>

checkName(end + 1, 1) = "holdout_days"; %#ok<SAGROW>
checkStatus(end + 1, 1) = pass_fail(numel(data.holdout.t) >= 14); %#ok<SAGROW>
checkDetail(end + 1, 1) = sprintf('%d days', numel(data.holdout.t)); %#ok<SAGROW>

special = find(contains(data.daily.flags, ...
    ["special_report", "negative_revision", "missing_day_locf"], ...
    'IgnoreCase', true));
fprintf('\n--- special days ---\n');
fprintf('count: %d / %d\n', numel(special), nDays);
for k = special'
    fprintf('%s  %s\n', string(data.daily.date(k), 'yyyy-MM-dd'), ...
        data.daily.flags(k));
end

% -------------------------------------------------------------------------
% 8. Checks table and JSON summary
% -------------------------------------------------------------------------
CHK = table(checkName, checkStatus, checkDetail, ...
    'VariableNames', {'check', 'status', 'detail'});
fprintf('\n--- checks ---\n');
disp(CHK);
writetable(CHK, fullfile(cfg.outDir, 'P0_checks.csv'));

summary = struct();
summary.generated_utc = string(datetime('now', 'TimeZone', 'UTC'), ...
    'yyyy-MM-dd''T''HH:mm:ss');
summary.config = cfg;
summary.data_source = data.data_source;
summary.time_unit = cfg.timeUnit;
summary.loaded_from = data.loadedFrom;
summary.fit_start = string(cfg.fitStart, 'yyyy-MM-dd');
summary.fit_end = string(cfg.fitEnd, 'yyyy-MM-dd');
summary.hold_start = string(cfg.holdStart, 'yyyy-MM-dd');
summary.hold_end = string(cfg.holdEnd, 'yyyy-MM-dd');
summary.n_days = nDays;
summary.n_weekly = nWk;
summary.weekly_validation = struct( ...
    'missing_weeks', missingWeeks, ...
    'max_diff_cases', maxDiffC, ...
    'max_diff_deaths', maxDiffD);
summary.N = data.N;
summary.n_provinces = numel(data.provinces);
summary.n_zones = data.n_health_zones;
summary.latest_daily = data.latestDaily;
summary.initial_state = data.state0;
summary.response = data.resp;
summary.checks = CHK;
summary.all_pass = all(CHK.status == "PASS");

fid = fopen(fullfile(cfg.outDir, 'P0_summary.json'), 'w');
fprintf(fid, '%s', jsonencode(summary, 'PrettyPrint', true));
fclose(fid);

fprintf('\nall checks: %s\n', pass_fail(summary.all_pass));
fprintf(['wrote P0_checks.csv, P0_state_reconstruction.csv, ' ...
    'P0_daily_report.csv, P0_summary.json to %s\n'], cfg.outDir);
if ~summary.all_pass
    warning('p0_check:failed', 'One or more P0 checks failed.');
end

% =========================================================================
% Local functions
% =========================================================================
function T = build_state_table(data, dates)
n = numel(dates);
date = dates(:);
tDay = zeros(n, 1);
C = zeros(n, 1); M = zeros(n, 1); Q = zeros(n, 1); R = zeros(n, 1);
I = zeros(n, 1); E = zeros(n, 1); D = zeros(n, 1); S = zeros(n, 1);
qSource = strings(n, 1); rSource = strings(n, 1);
eSource = strings(n, 1); dSource = strings(n, 1);
consErr = zeros(n, 1);
flags = strings(n, 1);

for k = 1:n
    [~, st] = state_at(data, dates(k));
    date(k) = st.date;
    tDay(k) = st.t_day;
    C(k) = st.C; M(k) = st.M; Q(k) = st.Q; R(k) = st.R;
    I(k) = st.I; E(k) = st.E; D(k) = st.D; S(k) = st.S;
    qSource(k) = st.q_source;
    rSource(k) = st.r_source;
    eSource(k) = st.e_source;
    dSource(k) = st.d_source;
    consErr(k) = st.conservation_error;
    flags(k) = st.flags;
end

T = table(date, tDay, C, M, Q, R, I, E, D, S, qSource, rSource, ...
    eSource, dSource, consErr, flags, ...
    'VariableNames', {'date', 't_day', 'C', 'M', 'Q', 'R', 'I', 'E', ...
    'D', 'S', 'q_source', 'r_source', 'e_source', 'd_source', ...
    'conservation_error', 'flag'});
end

function s = pass_fail(ok)
if ok
    s = "PASS";
else
    s = "FAIL";
end
end
