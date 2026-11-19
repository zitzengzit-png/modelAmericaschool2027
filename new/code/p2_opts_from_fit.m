function opts = p2_opts_from_fit(fit, varargin)
%P2_OPTS_FROM_FIT  Build fit options that inherit a fitted model structure.
%
%   opts = p2_opts_from_fit(fit, 'nStarts', 1, 'verbose', false)
%
%   The returned struct is accepted by fit_daily_seiqrd_core. fixedParams is
%   copied from the fit, so a baseline with rhoRep fixed at 1 stays fixed.

opts = struct();
opts.paramNames = fit.paramNames;
opts.fixedParams = fit.fixedParams;
opts.knots = fit.knots;
opts.allowRebound = fit.allowRebound;
opts.fixRhoRep = false;          % fixedParams already carries the constraint
opts.q0 = fit.qFull;
opts.nStarts = 1;
opts.verbose = false;

for k = 1:2:numel(varargin)
    name = varargin{k};
    if ~(ischar(name) || isstring(name))
        error('p2_opts_from_fit:badName', 'Option names must be text.');
    end
    opts.(char(name)) = varargin{k + 1};
end
end
