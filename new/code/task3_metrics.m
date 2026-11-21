function m = task3_metrics(t, Y, dayZero)
%TASK3_METRICS  Peak, epidemic end and trajectories for one scenario.
%
%   m = task3_metrics(t, Y, dayZero)
%
%   End criterion (Task 3 section 7.3): daily new cases < 1 and
%   X = E+I+Q+D < 1 for 14 consecutive days. m.T_end is the first day of
%   that 14-day run; NaN when the 365-day window does not meet the rule.

C = Y(:, 3) + Y(:, 4) + Y(:, 5) + Y(:, 7);
M = Y(:, 7);
X = Y(:, 2) + Y(:, 3) + Y(:, 4) + Y(:, 6);

td = (0:floor(t(end))).';
Cd = interp1(t, C, td, 'linear', 'extrap');
Md = interp1(t, M, td, 'linear', 'extrap');
Xd = interp1(t, X, td, 'linear', 'extrap');

dailyNew = diff(Cd);
[m.peak, idx] = max(dailyNew);
m.peakDay = td(idx + 1);
m.peakDate = dayZero + days(m.peakDay);

ok = (dailyNew < 1) & (Xd(1:end-1) < 1);
m.T_end = NaN;
run = 0;
for k = 1:numel(ok)
    if ok(k)
        run = run + 1;
    else
        run = 0;
    end
    if run >= 14
        m.T_end = td(k - 13);
        break;
    end
end

if isfinite(m.T_end)
    m.T_endDate = dayZero + days(m.T_end);
else
    m.T_endDate = NaT;
end

m.t = td;
m.C = Cd;
m.M = Md;
m.X = Xd;
m.dailyNew = dailyNew;
m.C_end = Cd(end);
m.M_end = Md(end);
end
