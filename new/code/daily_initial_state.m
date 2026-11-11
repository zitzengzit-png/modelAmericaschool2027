function [y0, info] = daily_initial_state(data, cfg, p)
%DAILY_INITIAL_STATE  Initial state at 2026-06-21 for daily fitting.
%
%   [y0, info] = daily_initial_state(data, cfg, p)
%
%   C, M, I, Q, R come from state_at_day at the first date. The first day
%   has no previous day, so E and D would be zero; instead we use the first
%   week's mean daily cases/deaths as a warm start:
%       E0 = mean(new_cases(2:8)) / sigma
%       D0 = burialDelayDays * mean(new_deaths(2:8))
%   This is an initial-condition assumption, recorded in info.

[~, st] = state_at_day(data, data.daily.date(1));

idx = 2:min(8, numel(data.daily.date));
newC = mean(data.daily.newCases(idx), 'omitnan');
newD = mean(data.daily.newDeaths(idx), 'omitnan');
if ~isfinite(newC)
    newC = 0;
end
if ~isfinite(newD)
    newD = 0;
end

E0 = newC / p.sigma;
D0 = cfg.burialDelayDays * newD;
I0 = st.I;
Q0 = st.Q;
R0 = st.R;
M0 = st.M;
S0 = data.N - E0 - I0 - Q0 - R0 - M0;

if S0 <= 0
    error('daily_initial_state:negativeS', ...
        'Initial S is %.1f; check N and the initial stocks.', S0);
end

y0 = [S0; E0; I0; Q0; R0; D0; M0];

info = struct();
info.source = "first_week_warm_start";
info.E0 = E0;
info.D0 = D0;
info.newC_mean = newC;
info.newD_mean = newD;
info.state_at_first = st;
end
