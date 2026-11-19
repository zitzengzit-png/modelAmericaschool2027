function f = make_beta_fun_multi(betaC0, uVec, knots)
%MAKE_BETA_FUN_MULTI  Piecewise-constant betaC(t) with any number of knots.
%
%   f = make_beta_fun_multi(betaC0, uVec, knots)
%
%   betaC(t) = betaC0 * prod_i (1 - uVec(i) * 1(t >= knots(i)))
%
%   uVec and knots are vectors of equal length. A negative uVec(i) is a
%   rebound/relaxation at that knot (used by the P2 model comparison).
%   The returned handle accepts a scalar or a vector of day indices and
%   returns a column vector for vector input.

uVec  = uVec(:);
knots = knots(:);
if numel(uVec) ~= numel(knots)
    error('make_beta_fun_multi:sizeMismatch', ...
        'uVec has %d entries but knots has %d.', numel(uVec), numel(knots));
end

f = @(t) betaC0 .* prod(1 - uVec.' .* ...
    (reshape(t, [], 1) >= knots.'), 2);
end
