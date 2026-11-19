function Q2 = build_q2_daily_data(data, cfg)
%BUILD_Q2_DAILY_DATA  Consolidated daily observations for Question 2.
%
%   Q2 = build_q2_daily_data(data, cfg)
%
%   All model inputs are daily and aligned to the 2026-06-21..2026-11-09
%   table. Weekly data are NOT used as fit targets; they are kept separately
%   for validation.
%
%   Sources / rules:
%     C, M   national daily cumulative (raw cumulative, never new_*_adj)
%     Q      etc_admitted, with isolation-ratio fallback flag
%     R      recovered, carried forward where missing
%     Cd     community_deaths (daily, from 2026-07-13)
%     Ed     etc_deaths (daily, from 2026-07-13)
%     newC   new_confirmed (daily; diagnostic / auxiliary only)

d = data.daily;
n = numel(d.date);
T = table();
T.date = d.date;
T.t_day = d.t;
T.phase = repmat("fit", n, 1);
T.phase(d.date > cfg.fitEnd) = "holdout";
T.C = d.cases;
T.M = d.deaths;
T.Q = d.etcAdmitted;
T.R = d.recovered;
T.Cd = d.communityDeaths;
T.Ed = d.etcDeaths;
T.newC = d.newCases;
T.newM = d.newDeaths;
T.flag = d.flags;

% Source flags for the reconstructed quantities.
T.R_source = repmat("observed", n, 1);
T.R_source(~isfinite(T.R)) = "missing";
T.Q_source = repmat("etc_admitted", n, 1);
T.Q_source(~isfinite(T.Q)) = "missing";
T.Cd_source = repmat("observed", n, 1);
T.Cd_source(~isfinite(T.Cd)) = "missing";
T.Ed_source = repmat("observed", n, 1);
T.Ed_source(~isfinite(T.Ed)) = "missing";
T.newC_source = repmat("observed", n, 1);
T.newC_source(~isfinite(T.newC)) = "missing";

Q2 = struct();
Q2.daily = T;

% Weekly validation table: cumulative anchors only, not a fit target.
Wk = data.seriesWeekly;
Q2.weekly = table(Wk.week, Wk.weekEnd, Wk.cases, Wk.deaths, ...
    Wk.newCasesAdj, Wk.newDeathsAdj, ...
    'VariableNames', {'week', 'week_end', 'C', 'M', ...
    'new_cases_adj', 'new_deaths_adj'});
end
