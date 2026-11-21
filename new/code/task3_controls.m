function c = task3_controls(t, sc, ts, p)
%TASK3_CONTROLS  Intervention multipliers at time t (days from 2026-06-21).
%
%   c = task3_controls(t, sc, ts, p)
%
%   Returns alpha, nu, muQ and the multipliers applied to betaC, betaH,
%   betaF and to the force of infection (phiV, phiPEP). t may be scalar or
%   a vector; all outputs have the same size.

t = t(:);
c = struct();
c.alpha  = p.alpha0 * ones(size(t));
c.nu     = p.nu0    * ones(size(t));
c.muQ    = p.muQ    * ones(size(t));
c.bcMult = ones(size(t));
c.bhMult = ones(size(t));
c.bfMult = ones(size(t));
c.phiV   = ones(size(t));
c.phiPEP = ones(size(t));

g = @(r) (t >= ts) .* (1 - exp(-r .* max(0, t - ts)));

% 1. Isolation: I -> Q
if sc.iso
    c.alpha = p.alpha0 + (p.iso.alpha1 - p.alpha0) * g(p.iso.r);
end

% 3. Safe burial: D removal
if sc.burial
    c.nu = p.nu0 + (p.burial.nu1 - p.nu0) * g(p.burial.r);
end

% 2. Contact tracing (and the q(t) used by PEP)
q = p.ct.q0 * ones(size(t));
if sc.ct
    q(t >= ts) = sc.qTarget;
    c.bcMult = c.bcMult .* ...
        ((1 - p.ct.eta * q) ./ (1 - p.ct.eta * p.ct.q0));
end

% 8. Community education: community and funeral channels
if sc.ce
    ec = p.ce.emax * g(p.ce.rC);
    ef = p.ce.emax * g(p.ce.rF);
    c.bcMult = c.bcMult .* (1 - p.ce.etaC * ec);
    c.bfMult = c.bfMult .* (1 - p.ce.etaF * ef);
end

% 4. Hospital infection control: hospital channel
if sc.hic
    c.bhMult = c.bhMult .* (1 - p.hic.eta * g(p.hic.r));
end

% 5. Vaccination: susceptible risk multiplier
if sc.vax
    c.phiV = 1 - p.vax.eps * p.vax.vmax * (t >= ts + p.vax.delay);
end

% 7. PEP: only traceable exposed contacts
if sc.pep
    pPEP = p.pep.p * (t >= ts + p.pep.delay);
    c.phiPEP = 1 - p.pep.eps * p.pep.omega * q .* pPEP;
end

% 6. Treatment: Q death rate (MBP134 or remdesivir)
if sc.mbp
    c.muQ = c.muQ .* (1 - p.mbp.eta * p.mbp.c * (t >= ts));
elseif sc.rdv
    c.muQ = c.muQ .* (1 - p.rdv.eta * p.rdv.c * (t >= ts));
end
end
