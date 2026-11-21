function [t, Y] = task3_integrate(p, sc, ts, y0)
%TASK3_INTEGRATE  Integrate Task 3 between beta knots and control jumps.
%
%   [t, Y] = task3_integrate(p, sc, ts, y0)
%
%   Breakpoints: beta knots t1/t2, intervention start ts, vaccine delay
%   ts+7 and PEP delay ts+1. The state is continuous across breakpoints.

tEnd = p.tEnd;
breaks = unique([0, tEnd, p.t1, p.t2, ts, ts + 1, ts + 7]);
breaks = breaks(breaks >= 0 & breaks <= tEnd);

opts = odeset('RelTol', 1e-7, 'AbsTol', 1e-9, ...
    'NonNegative', 1:7, 'MaxStep', 0.5);

t = [];
Y = [];
state = y0(:);

for k = 1:numel(breaks) - 1
    a = breaks(k);
    b = breaks(k + 1);
    grid = unique([a, ceil(a):floor(b), b]);
    [tk, Yk] = ode15s(@(tt, yy) task3_rhs(tt, yy, p, sc, ts), ...
        grid, state, opts);
    if k > 1
        tk = tk(2:end);
        Yk = Yk(2:end, :);
    end
    t = [t; tk]; %#ok<AGROW>
    Y = [Y; Yk]; %#ok<AGROW>
    state = Yk(end, :).';
end
end
