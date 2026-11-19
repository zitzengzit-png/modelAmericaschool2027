function fit = fit_daily_seiqrd(data, cfg, opts)
%FIT_DAILY_SEIQRD  Backward-compatible wrapper for the generalized fit core.
%
%   fit = fit_daily_seiqrd(data, cfg)
%   fit = fit_daily_seiqrd(data, cfg, opts)
%
%   The implementation lives in fit_daily_seiqrd_core.m. Default behaviour is
%   the P1 six-parameter daily fit:
%       q = [betaC0, u1, u2, alpha0, mu, rhoRep]
%   with betaH = rhoH0*betaC and betaF = rhoF0*betaC.

if nargin < 3 || isempty(opts)
    opts = struct();
end
fit = fit_daily_seiqrd_core(data, cfg, opts);
end
