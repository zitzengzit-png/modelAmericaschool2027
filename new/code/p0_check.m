%% P0: data and configuration acceptance check
% Run from ws/src/matlab:  p0_check
% Writes ws/outputs/matlab/P0_*.csv|json
clear; clc;

cfg = config();
fprintf('=== P0 data check ===\n');
fprintf('data source : %s\n', cfg.dataSource);
fprintf('fit window  : W%d-W%d\n', cfg.fitWindow(1), cfg.fitWindow(2));
fprintf('holdout     : W%d-W%d\n', cfg.holdout(1), cfg.holdout(2));

data = load_data(cfg);

fprintf('\n--- files ---\n');
fn = fieldnames(data.loadedFrom);
for k = 1:numel(fn)
    fprintf('%-12s %s\n', fn{k}, data.loadedFrom.(fn{k}));
end

fprintf('\n--- series ---\n');
fprintf('source      : %s\n', data.data_source);
fprintf('weeks       : W%d-W%d (%d points, fit %d, holdout %d)\n', ...
    data.series.week(1), data.series.week(end), numel(data.series.week), ...
    numel(data.t), numel(data.holdout.t));
fprintf('N           : %.0f\n', data.N);
fprintf('provinces   : %d\n', numel(data.provinces));
fprintf('zones       : %d (as of %s)\n', data.n_health_zones, data.zone_as_of);
if isfield(data, 'latestDaily')
    fprintf('latest daily: %s  %.0f cases / %.0f deaths (SitRep %d)\n', ...
        data.latestDaily.date, data.latestDaily.cases, ...
        data.latestDaily.deaths, data.latestDaily.sitrep);
end

% -------------------------------------------------------------------------
% 1. Published anchors and fit/holdout split
% -------------------------------------------------------------------------
anchors = [25 1048 267; 43 10060 4887; 45 10990 5354];
checkName = strings(0, 1);
checkStatus = strings(0, 1);
checkDetail = strings(0, 1);
for k = 1:size(anchors, 1)
    w = anchors(k, 1);
    idx = find(data.series.week == w, 1);
    ok = ~isempty(idx) && data.series.cases(idx) == anchors(k, 2) && ...
        data.series.deaths(idx) == anchors(k, 3);
    checkName(end + 1, 1) = "anchor_W" + w; %#ok<SAGROW>
    checkStatus(end + 1, 1) = pass_fail(ok); %#ok<SAGROW>
    checkDetail(end + 1, 1) = sprintf('%.0f / %.0f (expected %.0f / %.0f)', ...
        data.series.cases(idx), data.series.deaths(idx), ...
        anchors(k, 2), anchors(k, 3)); %#ok<SAGROW>
end

% 2,073-case counterfactual anchor.
idx2073 = find(data.series.cases >= 2073, 1);
if idx2073 > 1
    c0 = data.series.cases(idx2073 - 1);
    c1 = data.series.cases(idx2073);
    d0 = data.series.weekEnd(idx2073 - 1);
    d1 = data.series.weekEnd(idx2073);
    frac = (2073 - c0) / (c1 - c0);
    crossDate = d0 + frac * (d1 - d0);
    fprintf('\n2,073 cases : between W%d (%.0f, %s) and W%d (%.0f, %s)\n', ...
        data.series.week(idx2073 - 1), c0, string(d0, 'yyyy-MM-dd'), ...
        data.series.week(idx2073), c1, string(d1, 'yyyy-MM-dd'));
    fprintf('              interpolated date %s (use W%d as the anchor)\n', ...
        string(crossDate, 'yyyy-MM-dd'), data.series.week(idx2073 - 1));
end

% -------------------------------------------------------------------------
% 2. State reconstruction at key weeks
% -------------------------------------------------------------------------
weeks = [25 28 32 34 41 43 45];
ST = build_state_table(data, weeks);
disp(ST);
writetable(ST, fullfile(cfg.outDir, 'P0_state_reconstruction.csv'));

allWeeks = data.series.week;
ALL = build_state_table(data, allWeeks);
writetable(ALL, fullfile(cfg.outDir, 'P0_data_report.csv'));

consErr = max(abs(ST.conservation_error));
caseErr = max(abs(ST.I + ST.Q + ST.R + ST.M - ST.C));
checkName(end + 1, 1) = "conservation";
checkStatus(end + 1, 1) = pass_fail(consErr < 1e-6 * data.N);
checkDetail(end + 1, 1) = sprintf('max |S+E+I+Q+R+M-N| = %.3g', consErr);
checkName(end + 1, 1) = "case_identity";
checkStatus(end + 1, 1) = pass_fail(caseErr < 1e-6);
checkDetail(end + 1, 1) = sprintf('max |I+Q+R+M-C| = %.3g', caseErr);

% -------------------------------------------------------------------------
% 3. Provinces and zones
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
% 4. Response, cross-border and HCW series
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
% 5. Legacy branch regression (old workbook must still load)
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
% 5b. Data anomalies that Task 2 must disclose
% -------------------------------------------------------------------------
fprintf('\n--- data anomalies ---\n');
i25 = find(data.series.week == 25, 1);
if ~isfinite(data.series.recovered(i25))
    fprintf('W25 recovered is blank: R is assumed 0 (r_source=assumed_zero).\n');
end
i45 = find(data.series.week == 45, 1);
if isfinite(data.series.etcAdmitted(i45))
    latestEtc = NaN;
    if isfield(data, 'latestDaily') && isfield(data.latestDaily, 'etc_admitted')
        latestEtc = data.latestDaily.etc_admitted;
    end
    if latestEtc > 0
        gap = abs(data.series.etcAdmitted(i45) - latestEtc) / latestEtc;
    else
        gap = 0;
    end
    if gap > 0.2
        fprintf(['W45 etc_admitted = %.0f vs latest daily %.0f ' ...
            '(%.0f%% gap): reporting change, flag for P2.\n'], ...
            data.series.etcAdmitted(i45), latestEtc, 100 * gap);
    end
end
flagged = find(contains(data.series.flags, ...
    ["adjusted", "no_report", "catch-up", "harmonisation"], ...
    'IgnoreCase', true));
if isempty(flagged)
    fprintf('No special weekly flags in %s.\n', data.series.sourceFile);
else
    for k = flagged'
        fprintf('W%d flag: %s\n', data.series.week(k), data.series.flags(k));
    end
end
i30 = find(data.series.week == 30, 1);
if ~isempty(i30) && isfinite(data.series.newCasesRaw(i30)) && ...
        isfinite(data.series.newCasesAdj(i30)) && ...
        data.series.newCasesRaw(i30) ~= data.series.newCasesAdj(i30)
    fprintf('W30 raw new cases %.0f vs adjusted %.0f (catch-up row excluded).\n', ...
        data.series.newCasesRaw(i30), data.series.newCasesAdj(i30));
end
fprintf('zone population: %d / %d known (source %s)\n', ...
    sum(isfinite(data.zone_population)), data.n_health_zones, ...
    data.zone_population_source);

checkName(end + 1, 1) = "holdout_points"; %#ok<SAGROW>
checkStatus(end + 1, 1) = pass_fail(numel(data.holdout.t) == 2); %#ok<SAGROW>
checkDetail(end + 1, 1) = sprintf('W%d-W%d', ...
    data.holdout.week(1), data.holdout.week(end)); %#ok<SAGROW>

checkName(end + 1, 1) = "zone_population"; %#ok<SAGROW>
checkStatus(end + 1, 1) = pass_fail(any(isfinite(data.zone_population))); %#ok<SAGROW>
checkDetail(end + 1, 1) = sprintf('%d / %d zones with population', ...
    sum(isfinite(data.zone_population)), data.n_health_zones); %#ok<SAGROW>

% -------------------------------------------------------------------------
% 6. Checks table and JSON summary
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
summary.loaded_from = data.loadedFrom;
summary.fit_window = cfg.fitWindow;
summary.holdout = cfg.holdout;
summary.N = data.N;
summary.n_provinces = numel(data.provinces);
summary.n_zones = data.n_health_zones;
summary.latest_daily = getfield_or(data, 'latestDaily', struct());
summary.initial_state = data.state0;
summary.response = data.resp;
summary.checks = CHK;
summary.all_pass = all(CHK.status == "PASS");

fid = fopen(fullfile(cfg.outDir, 'P0_summary.json'), 'w');
fprintf(fid, '%s', jsonencode(summary, 'PrettyPrint', true));
fclose(fid);

fprintf('\nall checks: %s\n', pass_fail(summary.all_pass));
fprintf(['wrote P0_checks.csv, P0_state_reconstruction.csv, ' ...
    'P0_data_report.csv, P0_summary.json to %s\n'], cfg.outDir);
if ~summary.all_pass
    warning('p0_check:failed', 'One or more P0 checks failed.');
end

% =========================================================================
% Local functions
% =========================================================================
function T = build_state_table(data, weeks)
n = numel(weeks);
week = zeros(n, 1);
weekEnd = strings(n, 1);
C = zeros(n, 1); M = zeros(n, 1); Q = zeros(n, 1); R = zeros(n, 1);
I = zeros(n, 1); E = zeros(n, 1); D = zeros(n, 1); S = zeros(n, 1);
qSource = strings(n, 1); rSource = strings(n, 1);
consErr = zeros(n, 1);

for k = 1:n
    [~, st] = state_at(data, weeks(k));
    week(k) = st.week;
    if isfield(st, 'week_end')
        weekEnd(k) = string(st.week_end, 'yyyy-MM-dd');
    end
    C(k) = st.C; M(k) = st.M; Q(k) = st.Q; R(k) = st.R;
    I(k) = st.I; E(k) = st.E; D(k) = st.D; S(k) = st.S;
    qSource(k) = st.q_source;
    rSource(k) = st.r_source;
    consErr(k) = st.conservation_error;
end

T = table(week, weekEnd, C, M, Q, R, I, E, D, S, qSource, rSource, ...
    consErr, 'VariableNames', {'week', 'week_end', 'C', 'M', 'Q', 'R', ...
    'I', 'E', 'D', 'S', 'q_source', 'r_source', 'conservation_error'});
end

function s = pass_fail(ok)
if ok
    s = "PASS";
else
    s = "FAIL";
end
end

function v = getfield_or(s, name, default)
if isfield(s, name)
    v = s.(name);
else
    v = default;
end
end
