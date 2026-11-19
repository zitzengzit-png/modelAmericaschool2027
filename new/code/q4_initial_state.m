function y0 = q4_initial_state(D, p, startDay)
%Q4_INITIAL_STATE  Build 8x7 SEIQRD initial state at startDay (t_day).
%
%   Missing C0/M0 at 2026-06-21 are treated as 0 and flagged as
%   "unreported assumption"; they are not true zero-case observations.

nP = D.nP;
y0 = zeros(nP, 7);
a = p.alpha + p.gamma + p.mu;

for i = 1:nP
    if startDay == 0
        C0 = D.C0(i);
        M0 = D.M0(i);
        idx = 2:8;
    else
        rows = D.daily(string(D.daily.province) == D.provNames{i}, :);
        C0 = local_get(rows, startDay, 'cum_confirmed');
        M0 = local_get(rows, startDay, 'cum_deaths');
        idx = max(1, startDay - 6):startDay;
    end
    if ~isfinite(C0), C0 = 0; end
    if ~isfinite(M0), M0 = 0; end

    rows = D.daily(string(D.daily.province) == D.provNames{i}, :);
    inc = local_mean(rows, idx, 'new_confirmed');
    dinc = local_mean(rows, idx, 'new_deaths');
    if ~isfinite(inc), inc = 0; end
    if ~isfinite(dinc), dinc = 0; end

    active = min(inc / a, max(C0 - M0, 0));
    Q0 = 0.4 * active;
    I0 = active - Q0;
    E0 = min(inc / p.sigma, D.N(i) - C0);
    R0 = max(C0 - M0 - active, 0);
    D0 = min(2 * dinc, M0);       % 2-day burial delay, daily deaths
    S0 = D.N(i) - E0 - I0 - Q0 - R0 - M0;
    if S0 <= 0
        S0 = max(D.N(i) - C0, 0);
        E0 = 0; I0 = 0; Q0 = 0; R0 = 0; D0 = 0;
    end
    y0(i, :) = [S0, E0, I0, Q0, R0, D0, M0];
end
end

function v = local_get(rows, day, field)
idx = find(rows.t_day == day, 1);
if isempty(idx), v = NaN; else, v = rows.(field)(idx); end
end

function v = local_mean(rows, days, field)
vals = nan(numel(days), 1);
for k = 1:numel(days)
    vals(k) = local_get(rows, days(k), field);
end
vals = vals(isfinite(vals));
if isempty(vals), v = 0; else, v = mean(vals); end
end
