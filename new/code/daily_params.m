function p = daily_params(cfg, data)
%DAILY_PARAMS  Fixed and initial parameters for the daily three-route model.
%
%   p = daily_params(cfg, data)
%
%   The model is
%     dS/dt = -S/N*(betaC*I + betaH*Q + betaF*D)
%     ...
%   with betaH = rhoH0*betaC and betaF = rhoF0*betaC. The six fitted
%   parameters are betaC0, u1, u2, alpha0, mu and rhoRep.

p = struct();
p.N = data.N;

% Fixed epidemiological rates (day^-1).
p.sigma  = cfg.sigma;
p.gamma  = cfg.gamma;
p.gammaQ = cfg.gammaQ;
p.mu     = cfg.mu;
p.muQ    = cfg.mu;
p.alpha  = cfg.alpha;
p.nu     = cfg.nu;

% Three-route ratios and reporting.
p.rhoH0  = cfg.rhoH0;
p.rhoF0  = cfg.rhoF0;
p.rhoM   = cfg.rhoM;

% Fitted/initial values.
p.betaC0 = cfg.betaC0;
p.u1     = cfg.u1;
p.u2     = cfg.u2;
p.rhoRep = cfg.rhoRep;

% Knots as day indices from cfg.dayZero. uVec is overwritten by the fit
% core for multi-knot variants; the default is the two-knot P1 model.
p.knots = days(cfg.betaKnots(:) - cfg.dayZero);
p.knots = sort(p.knots(:));
uVec = [cfg.u1; cfg.u2];
if isfield(cfg, 'u3')
    uVec = [uVec; cfg.u3];
end
p.uVec = uVec(1:numel(p.knots));
p.u1 = p.uVec(1);
p.u2 = p.uVec(2);
if numel(p.uVec) >= 3
    p.u3 = p.uVec(3);
end

p.burialDelayDays = cfg.burialDelayDays;
end
