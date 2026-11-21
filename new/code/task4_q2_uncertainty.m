%% task4_q2_uncertainty.m - Q2 parameter uncertainty vs R_net threshold conclusion
% Vary rhoH (hospital/community) and rhoF (funeral/community) over their
% scenario ranges; check whether the strategy conclusion (coordination brings
% R_net<1, travel/ring do not) is robust. Frozen-parameter, s_i = S_i/N_i ~ 1.
clear; clc;

%% ----- shared setup: geometry, gravity P, Q2 params ------------------------
[~, N, P, p, ~] = task4_common();
nP = numel(N);
alpha = p.alpha; mu = p.mu; muQ = p.muQ; nu = p.nu;
gamma_r = p.gamma; gammaQ = p.gammaQ;
beta_c_late = p.beta_c0*(1-p.u1)*(1-p.u2);   % late phase (after both knots)
a = alpha + gamma_r + mu; b = gammaQ + muQ;

rhoHs = [0.3 0.4 0.5];
rhoFs = [2.86 3.0 3.83];

%% ----- scan R_net across rhoH/rhoF for each strategy -----------------------
fprintf('R_net across rhoH/rhoF ranges (frozen params, S/N~1):\n');
fprintf('%-22s %10s %10s\n','scenario','R_net min','R_net max');
scen = {'baseline','travel 90%','coordination','ring 50%','combination'};
for sc = 1:numel(scen)
    vals = [];
    for rh = rhoHs
        for rf = rhoFs
            bc = beta_c_late;  bh = rh*bc;  bf = rf*bc;
            % strategy modifiers
            if sc==2   % travel: off-diagonal x 0.1
                Pt = restrict(P, 0.9);
            elseif sc==3   % coordination: beta x 0.85, alpha x 1.2
                bc = bc*0.85; bh = rh*bc; bf = rf*bc; aa = alpha*1.2;
            elseif sc==4   % ring: Ituri+NK beta_mult 0.5
                bm = ones(nP,1); bm(1)=0.5; bm(2)=0.5;
            elseif sc==5   % combination
                Pt = restrict(P,0.5); bc = bc*0.85; bh = rh*bc; bf = rf*bc; aa = alpha*1.2;
                bm = ones(nP,1); bm(1)=0.7; bm(2)=0.7;
            end
            if sc==1 || sc==4
                aa = alpha; bm = ones(nP,1); Pt = P;
                if sc==4, bm(1)=0.5; bm(2)=0.5; end
            end
            R = rnet(Pt, bc, rh, rf, aa, mu, muQ, nu, gamma_r, gammaQ, bm, N, nP);
            vals(end+1) = R; %#ok<AGROW>
        end
    end
    fprintf('%-22s %10.4f %10.4f\n', scen{sc}, min(vals), max(vals));
end
fprintf('\nConclusion robust if coordination max < 1 and travel/ring min > 1.\n');

%% R_net (frozen parameters) -------------------------------------------------
function R = rnet(P, bc, rh, rf, alpha, mu, muQ, nu, gamma_r, gammaQ, bm, N, nP)
    a = alpha+gamma_r+mu; b = gammaQ+muQ;
    s = ones(1,nP);   % S/N ~ 1
    K = zeros(nP);
    for i=1:nP
        K(i,i) = s(i)*bm(i)*( bc/a + alpha*(rh*bc)/(a*b) + (rf*bc/nu)*(mu/a + alpha*muQ/(a*b)) );
        for j=1:nP
            if j~=i, K(i,j) = s(i)*(bc*bm(j)*P(i,j))/a; end
        end
    end
    R = max(abs(eig(K)));
end

function P2 = restrict(P, theta)
    P2 = P; n = size(P,1);
    for j=1:n
        off = 1-P(j,j);
        P2(j,j) = 1-(1-theta)*off;
        for i=1:n
            if i~=j, P2(i,j) = (1-theta)*P(i,j); end
        end
    end
end
