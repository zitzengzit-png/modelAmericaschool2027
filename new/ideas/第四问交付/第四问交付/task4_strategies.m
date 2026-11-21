%% task4_strategies.m - spatial strategy scenario comparison
% Baseline (shared Q2, beta_mult=1) vs travel restriction / regional
% coordination / ring vaccination / combination. Run 6/21 -> 11/9.
% Reports end totals, window increments, and the frozen R_net at 11/9.
clear; clc;

%% ----- 1. setup (shared geometry, gravity P, Q2 params, anchor init) ------
[provNames, N, P0, p, y0] = task4_common();
nP = numel(provNames);
% ring-vaccination mechanism: protection ramps up after campaign start.
%   eps = max effective protection (coverage x timely x efficacy)
%   start = campaign start day, tau = ramp-up time (days)
p.ring = struct('eps',0,'start',Inf,'tau',14,'prov',zeros(nP,1));

%% ----- 2. strategy scenarios ----------------------------------------------
scen = {
  'shared Q2 reference',   struct('P',P0,'bm',ones(nP,1),'bc',p.beta_c0,'alpha',p.alpha0);
  'travel 50%',            struct('P',restrict(P0,0.5),'bm',ones(nP,1),'bc',p.beta_c0,'alpha',p.alpha0);
  'travel 90%',            struct('P',restrict(P0,0.9),'bm',ones(nP,1),'bc',p.beta_c0,'alpha',p.alpha0);
  'coord.: beta -15%, alpha +20%', struct('P',P0,'bm',ones(nP,1),'bc',p.beta_c0*0.85,'alpha',p.alpha0*1.2);
  'regional reduction proxy 30%', struct('P',P0,'bm',ring(ones(nP,1),0.3),'bc',p.beta_c0,'alpha',p.alpha0);
  'regional reduction proxy 50%', struct('P',P0,'bm',ring(ones(nP,1),0.5),'bc',p.beta_c0,'alpha',p.alpha0);
  'ring mechanism eps=0.5', struct('P',P0,'bm',ones(nP,1),'bc',p.beta_c0,'alpha',p.alpha0, ...
      'ring', struct('eps',0.5,'start',66,'tau',14,'prov',[1;1;0;0;0;0;0;0]));
  'combined (30% proxy)',  struct('P',restrict(P0,0.5),'bm',ring(ones(nP,1),0.3),'bc',p.beta_c0*0.85,'alpha',p.alpha0*1.2);
};

%% ----- 3. run & report ----------------------------------------------------
start_cases = sum(y0(:,3) + y0(:,4) + y0(:,5) + y0(:,7));
start_deaths = sum(y0(:,7));
fprintf('Window: 2026-06-21 to 2026-11-09. Scenario changes active from day 0.\n');
fprintf('Initial model totals: %.0f onsets, %.0f deaths.\n', start_cases, start_deaths);
fprintf('%-34s %12s %12s %12s %12s %12s %12s\n', ...
    'scenario','onsets@11/9','deaths@11/9','onset delta','death delta','R_net@11/9','onset change');
base_delta = NaN;
results = cell(size(scen,1),8);
for s = 1:size(scen,1)
    name = scen{s,1}; cfg = scen{s,2};
    [tot_cases, tot_deaths, R_net, provincesAboveOne, activeProvinces] = run_scen(cfg, p, y0, N, nP);
    onset_delta = tot_cases - start_cases;
    death_delta = tot_deaths - start_deaths;
    if s==1, base_delta = onset_delta; end
    change = (onset_delta/base_delta - 1)*100;
    fprintf('%-34s %12.0f %12.0f %12.0f %12.0f %12.3f %+11.1f%%\n', ...
        name, tot_cases, tot_deaths, onset_delta, death_delta, R_net, change);
    results(s,:) = {name,tot_cases,tot_deaths,onset_delta,death_delta,R_net,provincesAboveOne,activeProvinces};
end
resultTable = cell2table(results,'VariableNames', ...
    {'Scenario','CumulativeOnsets','CumulativeDeaths','WindowOnsets','WindowDeaths','Rnet','LocalAboveOne','ExpectedOnsetsLast7dAtLeastOne'});
setappdata(0,'task4_result',resultTable);

%% ----- run one scenario ----------------------------------------------------
function [tot_cases, tot_deaths, R_net, provincesAboveOne, activeProvinces] = run_scen(cfg, p, y0, N, nP)
    p.beta_mult = cfg.bm; p.alpha = cfg.alpha; p.beta_c0 = cfg.bc;
    if isfield(cfg,'ring'), p.ring = cfg.ring; else, p.ring.eps = 0; end
    [t,Y] = task4_integrate(@(tt,y) rhs(tt,y,p,cfg.P,N,nP), [0 141], y0(:), p, ...
                  odeset('RelTol',1e-6,'AbsTol',1e-6));
    S = Y(:,1:nP);
    C = Y(:,2*nP+1:3*nP)+Y(:,3*nP+1:4*nP)+Y(:,4*nP+1:5*nP)+Y(:,6*nP+1:7*nP);
    M = Y(:,6*nP+1:7*nP);
    tot_cases  = sum(interp1(t, C, 141));
    tot_deaths = sum(interp1(t, M, 141));

    % R_net (late phase)
    beta_c = p.beta_c0*(1-p.u1)*(1-p.u2);
    beta_h = p.rhoH*beta_c; beta_f = p.rhoF*beta_c;
    s = S(end,:)./N';
    a = p.alpha+p.gamma+p.mu; b = p.gammaQ+p.muQ;
    ring_late = 1 - p.ring.eps * p.ring.prov;   % ramp ~ 1 at t=141
    K = zeros(nP);
    for i=1:nP
        K(i,i) = s(i)*p.beta_mult(i)*ring_late(i)*( beta_c/a + p.alpha*beta_h/(a*b) ...
                  + (beta_f/p.nu)*(p.mu/a + p.alpha*p.muQ/(a*b)) );
        for j=1:nP
            if j~=i
                K(i,j) = s(i)*(beta_c*p.beta_mult(j)*ring_late(j)*p.w(i,j)*cfg.P(i,j))/a;
            end
        end
    end
    R_net = max(abs(eig(K)));
    provincesAboveOne = sum(diag(K)>1);
    lastWeek = C(end,:) - C(t==134,:);
    activeProvinces = sum(lastWeek>=1);
    % Expected onset counts are a descriptive footprint, not transmission chains.
    assert(all(abs(sum(cfg.P,1)-1)<1e-10));
    assert(min(Y,[],'all')>-1e-6);
    liveAndDead = Y(:,1:nP)+Y(:,nP+1:2*nP)+Y(:,2*nP+1:3*nP) ...
        +Y(:,3*nP+1:4*nP)+Y(:,4*nP+1:5*nP)+Y(:,6*nP+1:7*nP);
    assert(max(abs(liveAndDead-N'),[],'all')<1e-5);
end

%% ----- strategy modifiers ---------------------------------------------------
function P2 = restrict(P, theta)
    % scale off-diagonal by (1-theta), add back to diagonal (keep col sum = 1)
    P2 = P;
    n = size(P,1);
    for j=1:n
        off = 1 - P(j,j);
        P2(j,j) = 1 - (1-theta)*off;
        for i=1:n
            if i~=j, P2(i,j) = (1-theta)*P(i,j); end
        end
    end
end

function bm = ring(bm, eff)
    bm(1) = 1 - eff;   % Ituri
    bm(2) = 1 - eff;   % Nord-Kivu
end

%% ----- ODE right-hand side -------------------------------------------------
function dy = rhs(t,y,p,P,N,nP)
    y = reshape(y,nP,7);
    S=y(:,1);E=y(:,2);I=y(:,3);Q=y(:,4);R=y(:,5);Dd=y(:,6);M=y(:,7); %#ok<NASGU>
    bc = p.beta_c0*(1-p.u1*(t>=p.t1))*(1-p.u2*(t>=p.t2));
    bh = p.rhoH*bc; bf = p.rhoF*bc;
    ramp = (t > p.ring.start) * (1 - exp(-max(0,t-p.ring.start)/p.ring.tau));
    ring_mult = 1 - p.ring.eps * p.ring.prov * ramp;   % time-dependent protection
    Lambda = zeros(nP,1);
    for i=1:nP
        mi = p.beta_mult(i) * ring_mult(i);
        local = mi*(bc*I(i)+bh*Q(i)+bf*Dd(i));
        cross = 0;
        for j=1:nP
            if j~=i
                mj = p.beta_mult(j) * ring_mult(j);
                cross = cross + p.w(i,j)*P(i,j)*bc*mj*I(j);
            end
        end
        Lambda(i) = (S(i)/N(i))*(local+cross);
    end
    dy = zeros(nP,7);
    dy(:,1)=-Lambda; dy(:,2)=Lambda-p.sigma*E;
    dy(:,3)=p.sigma*E-(p.alpha+p.gamma+p.mu).*I;
    dy(:,4)=p.alpha*I-(p.gammaQ+p.muQ).*Q;
    dy(:,5)=p.gamma*I+p.gammaQ.*Q;
    dy(:,6)=p.mu*I+p.muQ.*Q-p.nu*Dd;
    dy(:,7)=p.mu*I+p.muQ.*Q;
    dy=dy(:);
end
