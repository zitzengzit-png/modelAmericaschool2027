function [Rnet, Rlocal, K] = q4_rnet(D, p, P, S, tEnd)
%Q4_RNET  Next-generation matrix for the 8-province metapopulation.
%
%   [Rnet,Rlocal,K] = q4_rnet(D,p,P,S,tEnd)
%   Rlocal(i)=K(i,i); off-diagonal K_ij uses beta_mult(j).

nP = D.nP;
betaFun = make_beta_fun_multi(p.betaC0, [p.u1; p.u2], p.tKnots);
bc = betaFun(tEnd);
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
s = S(:) ./ D.N;

K = zeros(nP);
for i = 1:nP
    K(i,i) = s(i) * p.betaMult(i) * ( ...
        bc/a + p.alpha*(p.rhoH0*bc)/(a*b) + ...
        (p.rhoF0*bc/p.nu) * (p.mu/a + p.alpha*p.muQ/(a*b)) );
    for j = 1:nP
        if j ~= i
            K(i,j) = s(i) * p.betaMult(j) * bc * p.w(i,j) * P(i,j) / a;
        end
    end
end
Rnet = max(abs(eig(K)));
Rlocal = diag(K);
end
