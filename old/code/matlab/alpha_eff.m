function ae = alpha_eff(alpha, phiT, dTraced)
%ALPHA_EFF  Effective admission rate when a fraction phiT is traced.
if nargin < 3
    dTraced = 1.0;
end
if phiT <= 0
    ae = alpha;
    return;
end
if phiT < 0 || phiT > 1
    error('phiT must lie in [0, 1]');
end
d0 = 7 / alpha;
dEff = (1 - phiT) * d0 + phiT * dTraced;
ae = 7 / dEff;
end
