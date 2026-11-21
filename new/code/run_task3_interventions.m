%% run_task3_interventions.m
% Task 3: eight interventions, 14 scenarios, two start dates.
% Baseline is the Q2 9/20 daily fit (rho_rep = 1).
% Output: ws/new/outputs/task3/
clear; clc; close all;

cfg = config();
outDir = cfg.task3OutDir;
figDir = fullfile(outDir, 'T3_figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

data = load_data(cfg);
p = task3_params(cfg, data);
[y0, initInfo] = daily_initial_state(data, cfg, p); %#ok<ASGLU>
scens = task3_scenarios();

fprintf('=== Task 3: eight interventions ===\n');
fprintf('N = %.0f, C0 = 1048, M0 = 267\n', p.N);
fprintf('y0: S=%.1f E=%.2f I=%.2f Q=%.2f R=%.2f D=%.2f M=%.1f\n', y0);
fprintf('betaC0=%.5f u1=%.5f u2=%.5f alpha0=%.5f mu=%.5f\n', ...
    p.betaC0, p.u1, p.u2, p.alpha0, p.mu);

starts = [23 126];
startLabels = ["2026-07-14", "2026-10-25"];
startCases = [2073 10060];

% No-intervention baseline (same trajectory for both start dates).
baseSc = scens(1);
[baseT, baseY] = task3_integrate(p, baseSc, starts(1), y0);
baseM = task3_metrics(baseT, baseY, cfg.dayZero);

rowCells = {};
trajCells = {};
maxCons = 0;
minState = inf;
cumOk = true;

for s = 1:numel(starts)
    ts = starts(s);
    for k = 1:numel(scens)
        sc = scens(k);
        if sc.id == "B0"
            t = baseT; Y = baseY; m = baseM;
        else
            [t, Y] = task3_integrate(p, sc, ts, y0);
            m = task3_metrics(t, Y, cfg.dayZero);
        end

        maxCons = max(maxCons, max(abs(sum(Y(:, [1:5 7]), 2) - p.N)));
        minState = min(minState, min(Y, [], 'all'));
        cumOk = cumOk && all(diff(m.C) >= -1e-6);

        RC = 100 * (baseM.C_end - m.C_end) / baseM.C_end;
        RM = 100 * (baseM.M_end - m.M_end) / baseM.M_end;
        if isfinite(m.T_end) && isfinite(baseM.T_end)
            dT = baseM.T_end - m.T_end;
        else
            dT = NaN;
        end

        if isfinite(m.T_end)
            endStatus = "ended";
        else
            endStatus = "not_ended";
        end
        rowCells{end+1} = table(sc.id, sc.label, startLabels(s), ts, ...
            startCases(s), m.C_end, m.M_end, m.peak, m.peakDay, ...
            m.peakDate, m.T_end, m.T_endDate, endStatus, RC, RM, dT, ...
            'VariableNames', {'scenario', 'label', 'startDate', 'tStart', ...
            'C_at_start', 'C_end', 'M_end', 'peakDaily', 'peakDay', ...
            'peakDate', 'T_end', 'T_endDate', 'endStatus', ...
            'R_C_pct', 'R_M_pct', 'deltaT'}); %#ok<AGROW>

        n = numel(m.t);
        trajCells{end+1} = table(repmat(string(sc.id), n, 1), ...
            repmat(startLabels(s), n, 1), m.t, ...
            cfg.dayZero + days(m.t), m.C, m.M, ...
            [m.dailyNew; NaN], m.X, ...
            'VariableNames', {'scenario', 'startDate', 't_day', 'date', ...
            'C', 'M', 'dailyNew', 'X'}); %#ok<AGROW>
    end
end

rows = vertcat(rowCells{:});
traj = vertcat(trajCells{:});

writetable(rows, fullfile(outDir, 'T3_scenarios.csv'));
writetable(traj, fullfile(outDir, 'T3_trajectories.csv'));

% Baseline parameters and sensitivity ranges.
baseNames = ["betaC0"; "u1"; "u2"; "alpha0"; "mu"; "sigma"; ...
    "gamma"; "gammaQ"; "nu0"; "rhoH0"; "rhoF0"; ...
    "alpha1"; "etaCT"; "nu1"; "etaHIC"; "vmax"; "epsV"; "dV"; ...
    "cMBP"; "etaMBP"; "cRDV"; "etaRDV"; "omegaPEP"; "pPEP"; ...
    "epsPEP"; "emax"; "etaCEc"; "etaCEf"];
baseVals = [p.betaC0; p.u1; p.u2; p.alpha0; p.mu; p.sigma; ...
    p.gamma; p.gammaQ; p.nu0; p.rhoH0; p.rhoF0; ...
    p.iso.alpha1; p.ct.eta; p.burial.nu1; p.hic.eta; ...
    p.vax.vmax; p.vax.eps; p.vax.delay; ...
    p.mbp.c; p.mbp.eta; p.rdv.c; p.rdv.eta; ...
    p.pep.omega; p.pep.p; p.pep.eps; ...
    p.ce.emax; p.ce.etaC; p.ce.etaF];
baseUnits = ["day^-1"; "-"; "-"; "day^-1"; "day^-1"; "day^-1"; ...
    "day^-1"; "day^-1"; "day^-1"; "-"; "-"; ...
    "day^-1"; "-"; "day^-1"; "-"; "-"; "-"; "day"; ...
    "-"; "-"; "-"; "-"; "-"; "-"; "-"; "-"; "-"; "-"];
baselineT = table(baseNames, baseVals, baseUnits, ...
    'VariableNames', {'parameter', 'value', 'unit'});
writetable(baselineT, fullfile(outDir, 'T3_baseline.csv'));
writetable(p.paramRanges, fullfile(outDir, 'T3_ranges.csv'));

% Follow-up resource table (relative only).
q = [0.78; 0.90; 0.95];
phiCT = (1 - p.ct.eta * q) ./ (1 - p.ct.eta * p.ct.q0);
relativeStaff = q / p.ct.q0;
resourceT = table(q, phiCT, relativeStaff, 100 * (1 - phiCT), ...
    'VariableNames', {'followUp', 'phiCT', 'relativeStaff', ...
    'betaC_reduction_pct'});
writetable(resourceT, fullfile(outDir, 'T3_resource.csv'));

% Checks.
C141 = interp1(baseM.t, baseM.C, 141);
relErr = 100 * (C141 - 11042) / 11042;
st = ["PASS"; "PASS"; "PASS"; "PASS"; "INFO"];
if maxCons >= 1e-2, st(1) = "FAIL"; end
if minState < -1e-6, st(2) = "FAIL"; end
if ~cumOk, st(3) = "FAIL"; end
if height(rows) ~= 28, st(4) = "FAIL"; end
detail = strings(5, 1);
detail(1) = sprintf('max |S+E+I+Q+R+M-N| = %.3g', maxCons);
detail(2) = sprintf('min state = %.3g', minState);
detail(3) = sprintf('all C series nondecreasing: %d', cumOk);
detail(4) = sprintf('rows = %d (14 scenarios x 2 starts)', height(rows));
detail(5) = sprintf('B0 C(141)=%.1f vs observed 11042 (%.2f%%)', ...
    C141, relErr);
checks = table( ...
    ["conservation"; "nonnegative"; "cumulative_monotone"; ...
     "scenario_rows"; "baseline_anchor_1109"], ...
    st, detail, 'VariableNames', {'check', 'status', 'detail'});
writetable(checks, fullfile(outDir, 'T3_checks.csv'));

% Console table.
fprintf('\n%-5s %-30s %-11s %10s %10s %10s %10s\n', ...
    'id', 'scenario', 'start', 'C_end', 'M_end', 'R_C(%)', 'R_M(%)');
for i = 1:height(rows)
    fprintf('%-5s %-30s %-11s %10.0f %10.0f %10.2f %10.2f\n', ...
        char(rows.scenario(i)), char(rows.label(i)), ...
        char(rows.startDate(i)), rows.C_end(i), rows.M_end(i), ...
        rows.R_C_pct(i), rows.R_M_pct(i));
end

% Summary JSON.
summary = struct();
summary.generated_utc = string(datetime('now', 'TimeZone', 'UTC'), ...
    'yyyy-MM-dd''T''HH:mm:ss''Z''');
summary.baseline = struct('betaC0', p.betaC0, 'u1', p.u1, ...
    'u2', p.u2, 'alpha0', p.alpha0, 'mu', p.mu);
summary.starts = cellstr(startLabels);
summary.startCases = startCases;
summary.nScenarios = numel(scens);
summary.baseline_C_end = baseM.C_end;
summary.baseline_M_end = baseM.M_end;
summary.baseline_peak = baseM.peak;
summary.baseline_peakDay = baseM.peakDay;
summary.baseline_T_end = baseM.T_end;
summary.notes = ['Interventions are scenario multipliers, not estimated ' ...
    'causal effects. Baseline is the Q2 9/20 fit with u2=-0.5, i.e. a ' ...
    'late rebound extrapolated to day 365.'];
write_json(fullfile(outDir, 'T3_summary.json'), summary);

% Figure 1: single interventions at the current stage.
ids = ["B0", "S1", "S2", "S3", "S4", "S5", "S6a", "S6b", "S7", "S8"];
fig = figure('Color', 'w', 'Position', [80 80 1000 640]);
hold on;
for i = 1:numel(ids)
    sel = traj(traj.scenario == ids(i) & ...
        traj.startDate == "2026-10-25", :);
    plot(sel.t_day, sel.C, 'LineWidth', 1.2);
end
xlabel('day from 2026-06-21');
ylabel('cumulative cases');
title('Task 3: single interventions (start 2026-10-25)');
legend(cellstr(ids), 'Location', 'northwest');
legend boxoff; grid on; box off;
exportgraphics(fig, fullfile(figDir, 'T3_single_current.png'), ...
    'Resolution', 200);

% Figure 2: combination scenarios, early vs current start.
ids = ["A", "B", "C", "D"];
styles = {'-', '--'};
cols = lines(4);
fig = figure('Color', 'w', 'Position', [80 80 1000 640]);
hold on;
leg = strings(0);
for i = 1:numel(ids)
    for s = 1:numel(starts)
        sel = traj(traj.scenario == ids(i) & ...
            traj.startDate == startLabels(s), :);
        plot(sel.t_day, sel.C, styles{s}, 'LineWidth', 1.2, ...
            'Color', cols(i, :));
        leg(end+1) = ids(i) + " " + startLabels(s); %#ok<AGROW>
    end
end
xlabel('day from 2026-06-21');
ylabel('cumulative cases');
title('Task 3: combinations, early (solid) vs current (dashed)');
legend(cellstr(leg), 'Location', 'northwest');
legend boxoff; grid on; box off;
exportgraphics(fig, fullfile(figDir, 'T3_combinations_timing.png'), ...
    'Resolution', 200);

% Figure 3: cases averted at the current start.
sel = rows(rows.startDate == "2026-10-25" & rows.scenario ~= "B0", :);
fig = figure('Color', 'w', 'Position', [80 80 1000 520]);
bar(sel.R_C_pct);
set(gca, 'XTick', 1:height(sel), 'XTickLabel', cellstr(sel.scenario));
xtickangle(45);
ylabel('cumulative cases averted vs B0 (%)');
title('Task 3: cases averted (start 2026-10-25)');
grid on; box off;
exportgraphics(fig, fullfile(figDir, 'T3_cases_averted.png'), ...
    'Resolution', 200);

fprintf('\nTask 3 outputs written to %s\n', outDir);

% -------------------------------------------------------------------------
function write_json(file, s)
fid = fopen(file, 'w');
fprintf(fid, '%s', jsonencode(s, 'PrettyPrint', true));
fclose(fid);
end

