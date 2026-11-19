%% task4_scan_m.m - scan m_share vs Nord-Kivu share
clear; clc;
dataDir = fullfile('data','ebola_tracker');
prov = readtable(fullfile(dataDir,'province_latest_20261111.csv'));
daily = readtable(fullfile(dataDir,'province_daily_20261111.csv'));
provNames = {'Ituri','Nord-Kivu','Haut-Uele','Tshopo','Bas-Uele','Nord-Ubangi','Sud-Kivu','Sud-Ubangi'}';
nP = numel(provNames);
N = zeros(nP,1);
for i=1:nP, N(i)=prov.population(strcmp(prov.province,provNames{i})); end

A = zeros(nP);
edges = [1 2; 1 3; 1 4; 2 4; 2 7; 3 4; 3 5; 4 5; 5 6; 6 8];
for k=1:size(edges,1), A(edges(k,1),edges(k,2))=1; A(edges(k,2),edges(k,1))=1; end
lat = [1.55941;-1.67409;2.77391;0.515;2.78582;4.27900;-2.49077;3.25651];
lon = [30.25224;29.22845;27.61603;25.191;24.72997;21.00284;28.84281;19.77234];
distKm = zeros(nP);
for i=1:nP, for j=i+1:nP
    h = sin(deg2rad(lat(j)-lat(i))/2)^2 + cos(deg2rad(lat(i)))*cos(deg2rad(lat(j)))*sin(deg2rad(lon(j)-lon(i))/2)^2;
    h = min(1,h);
    distKm(i,j)=2*6371*atan2(sqrt(h),sqrt(1-h)); distKm(j,i)=distKm(i,j);
end; end

p.alpha=1.244/7; p.mu=0.235/7; p.muQ=p.mu; p.sigma=0.70/7; p.gamma=0.21/7; p.gammaQ=0.21/7; p.nu=3.5/7;
p.rhoH=0.4; p.rhoF=3.0; p.w=ones(nP);
a=p.alpha+p.gamma+p.mu; b=p.gammaQ+p.muQ;
coef=1/a+p.alpha*p.rhoH/(a*b)+(p.rhoF/p.nu)*(p.mu/a+p.alpha*p.muQ/(a*b));
p.beta0=1.356/coef; p.beta1=0.885/coef; p.t_beta=49;
p.beta_mult=ones(nP,1);

y0 = anchor_state(daily, provNames, N, p, nP);
fprintf('anchor C0: Ituri=%.0f NK=%.0f\n', y0(1,3)+y0(1,4)+y0(1,5)+y0(1,7), y0(2,3)+y0(2,4)+y0(2,5)+y0(2,7));

gamma=1.5; m_share=0.015;
W=zeros(nP);
for i=1:nP, for j=1:nP
    if i~=j && A(i,j)>0, W(i,j)=N(i)*N(j)*distKm(i,j)^(-gamma); end
end; end
B=W./max(sum(W,1),eps); B(:,sum(W,1)==0)=0;
P=zeros(nP);
for j=1:nP, P(:,j)=m_share*B(:,j); P(j,j)=1-m_share; end

fprintf('\n%-12s %10s %10s %10s %10s\n','beta_mult(NK)','Ituri','NordKivu','NK/Ituri%','HautUele');
for bm = [1 1.5 2 2.5 3 4]
    p.beta_mult = ones(nP,1); p.beta_mult(2) = bm;   % Nord-Kivu = index 2
    [t,Y]=ode45(@(tt,y) rhs(tt,y,p,P,N,nP), [0 141], y0(:), odeset('RelTol',1e-6,'AbsTol',1e-6));
    C = Y(:,2*nP+1:3*nP)+Y(:,3*nP+1:4*nP)+Y(:,4*nP+1:5*nP)+Y(:,6*nP+1:7*nP);
    c = interp1(t,C,126);
    fprintf('%-12.1f %10.0f %10.0f %10.1f %10.0f\n', bm, c(1), c(2), 100*c(2)/c(1), c(3));
end
fprintf('\nObserved @10/25: Ituri=7684 NordKivu=2737 (36%%) HautUele=496\n');

function y0 = anchor_state(daily, provNames, N, p, nP)
    a = p.alpha + p.gamma + p.mu;
    iso_ratio = 0.4;
    y0 = zeros(nP,7);
    for i = 1:nP
        r = daily(strcmp(daily.province, provNames{i}), :);
        C0 = getVal(r,0,'cum_confirmed'); M0 = getVal(r,0,'cum_deaths');
        inc = meanVal(r,1:7,'new_confirmed'); dinc = meanVal(r,1:7,'new_deaths');
        if isnan(C0), C0=0; end; if isnan(M0), M0=0; end
        if isnan(inc), inc=0; end; if isnan(dinc), dinc=0; end
        active = min(inc/a, max(C0-M0,0));
        Q0 = iso_ratio*active; I0 = active-Q0;
        E0 = min(inc/p.sigma, N(i)-C0);
        R0 = max(C0-M0-active, 0);
        D0 = min(dinc*(2/7), M0);
        S0 = N(i)-E0-I0-Q0-R0-M0;
        y0(i,:) = [S0 E0 I0 Q0 R0 D0 M0];
    end
end

function v = getVal(rows, tDay, field)
    idx = find(rows.t_day==tDay, 1);
    if isempty(idx), v=NaN; else, v=rows.(field)(idx); end
end

function v = meanVal(rows, tDays, field)
    vals = NaN(numel(tDays),1);
    for k=1:numel(tDays), vals(k)=getVal(rows,tDays(k),field); end
    vals = vals(~isnan(vals));
    if isempty(vals), v=NaN; else, v=mean(vals); end
end

function dy = rhs(t,y,p,P,N,nP)
    y = reshape(y,nP,7);
    S=y(:,1);E=y(:,2);I=y(:,3);Q=y(:,4);R=y(:,5);Dd=y(:,6);M=y(:,7); %#ok<NASGU>
    bc = p.beta0*(t<p.t_beta)+p.beta1*(t>=p.t_beta);
    bh = p.rhoH*bc; bf = p.rhoF*bc;
    Lambda = zeros(nP,1);
    for i=1:nP
        local = p.beta_mult(i)*(bc*I(i)+bh*Q(i)+bf*Dd(i));
        cross = 0;
        for j=1:nP
            if j~=i, cross = cross + p.w(i,j)*P(i,j)*bc*p.beta_mult(j)*I(j); end
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
