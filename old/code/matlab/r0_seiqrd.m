function value = r0_seiqrd(beta, p)
%R0_SEIQRD  Next-generation-matrix R0 for the SEIQRD model.
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
pre = beta / a;
post = beta * p.kappa / p.nu * ...
    (p.mu / a + (p.alpha / a) * (p.muQ / b));
value = pre + post;
end
