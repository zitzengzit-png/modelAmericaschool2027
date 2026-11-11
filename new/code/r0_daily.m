function [R0, Rc, Rh, Rf] = r0_daily(p, betaC)
%R0_DAILY  Channel decomposition of R0 for the daily three-route model.
%
%   [R0,Rc,Rh,Rf] = r0_daily(p, betaC)
%
%   R0 = betaC/a + alpha*betaH/(a*b)
%        + (betaF/nu)*(mu/a + alpha*muQ/(a*b))
%   with betaH = rhoH0*betaC, betaF = rhoF0*betaC.
%   betaC may be a scalar or an array.

a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;

Rc = betaC ./ a;
Rh = p.alpha .* p.rhoH0 .* betaC ./ (a .* b);
Rf = (p.rhoF0 .* betaC ./ p.nu) .* ...
    (p.mu ./ a + p.alpha .* p.muQ ./ (a .* b));

R0 = Rc + Rh + Rf;
end
