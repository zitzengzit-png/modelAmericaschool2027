function f = make_beta_fun(betaC0, u1, u2, knots)
%MAKE_BETA_FUN  Piecewise-constant daily community transmission.
%
%   f = make_beta_fun(betaC0, u1, u2, knots) returns a function handle
%   betaC(t) = betaC0*(1-u1*1(t>=knots(1)))*(1-u2*1(t>=knots(2))).

k1 = knots(1);
k2 = knots(2);
f = @(t) betaC0 .* (1 - u1 .* (t >= k1)) .* (1 - u2 .* (t >= k2));
end
