function [I0,Q0] = task4_initial_active(inc, available, p)
% Quasi-steady initialization from daily onset rate.
% I lasts 1/a; the fraction alpha/a also spends 1/b in Q.
% This is a reconstruction assumption, not an observed state.
    a = p.alpha + p.gamma + p.mu;
    b = p.gammaQ + p.muQ;
    I0 = max(inc,0) / a;
    Q0 = p.alpha * I0 / b;
    scale = min(1, max(available,0) / max(I0 + Q0, eps));
    I0 = I0 * scale;
    Q0 = Q0 * scale;
end
