%% task4_border_screening.m - cross-border screening vs sustained-transmission risk
% Negative-binomial branching: a seed survives screening with prob 1-cs*eta,
% so effective seed count n_eff = n*(1-cs*eta); P(sustained) = 1 - q^{n_eff}.
% q = extinction prob of a single chain (smallest root of q = G(q)).
clear; clc;

% representative local reproduction mean m, dispersion k
m = 1.2;
ks = [0.5 1 Inf];   % over-dispersed / geometric / Poisson
scr = [0 0.3 0.5 0.7 0.9];   % screening effectiveness cs*eta

fprintf('m = %.2f\n', m);
fprintf('%-12s %10s | %18s | %18s\n','screen(cs*eta)','n_eff(KE)','Kenya n=9 P(sust)','Nigeria n=1 P(sust)');
for s = scr
    n_eff = 9*(1-s);
    % P(sustained) for the three dispersion levels
    pk = zeros(1,numel(ks));
    pn = zeros(1,numel(ks));
    for kk = 1:numel(ks)
        q = ext_prob(m, ks(kk));
        pk(kk) = 1 - q^n_eff;
        pn(kk) = 1 - q^(1*(1-s));
    end
    fprintf('%-12.1f %10.1f | %6.1f%% %5.1f%% %5.1f%% | %6.1f%% %5.1f%% %5.1f%%\n', ...
        s, n_eff, 100*pk(1), 100*pk(2), 100*pk(3), 100*pn(1), 100*pn(2), 100*pn(3));
end
fprintf('\ncolumns within each block: k=0.5, k=1, k=Inf (Poisson)\n');
fprintf('Kenya n=9 uses 9*(1-cs*eta) effective seeds; Nigeria n=1 uses (1-cs*eta).\n');
fprintf('Screening target: bring Kenya P(sust) below ~10%%.\n');

%% extinction probability (smallest root of q = G(q)) -----------------------
function q = ext_prob(m, k)
    if m <= 1, q = 1; return; end
    q = 0;
    for iter = 1:2000
        if isinf(k)
            qn = exp(m*(q-1));
        else
            qn = (1 + (m/k)*(1-q))^(-k);
        end
        if abs(qn - q) < 1e-12, q = qn; return; end
        q = qn;
    end
end
