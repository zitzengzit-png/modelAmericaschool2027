function [T, mae] = task4_holdout_table()
%TASK4_HOLDOUT_TABLE  Holdout model comparison (delivery caliber).
% Compares: flat baseline vs shared-Q2 (beta_mult=1) vs two province-multiplier
% models (constant multiplier vs multiplier fading after 8/17).
% All use Q2 9/20 params, same anchor (6/21 from 6/22-28 data), same data.
% Returns the province table and a MAE struct.

%% ----- setup (shared geometry, gravity P, Q2 params, anchor init) ----------
[provNames, N, P, p, y0, daily] = task4_common();
nP = numel(provNames);

% observed 10/25 cumulative + holdout net + flat baseline
C_obs = nan(nP,1); obs_hold = nan(nP,1); base_hold = nan(nP,1);
for i=1:nP
    r = daily(strcmp(daily.province, provNames{i}), :);
    c1 = getVal(r,126,'cum_confirmed'); c2 = getVal(r,141,'cum_confirmed'); c3 = getVal(r,119,'cum_confirmed');
    C_obs(i) = c1;
    if ~isnan(c1)&&~isnan(c2), obs_hold(i)=c2-c1; end
    if ~isnan(c1)&&~isnan(c3), base_hold(i)=(c1-c3)*15/7; end
end

cfg.P=P; cfg.N=N; cfg.nP=nP; cfg.y0=y0; cfg.C_obs=C_obs; cfg.lambda=0.2;
lb=[0.5 0.5 0.5 0.5 0.5 0.5 0.5 0.5]; ub=[2.5 2.5 2.5 2.5 2.0 2.0 2.0 2.0];

%% ----- 1. shared Q2 (beta_mult = 1) ----------------------------------------
p.beta_mult = ones(nP,1); p.fade = 0;
hold_shared = run_holdout(p, cfg);

%% ----- 2. constant beta_mult (calibrated, always-on) -----------------------
opts = optimoptions('lsqnonlin','Display','off','MaxFunctionEvaluations',3000);
x_const = lsqnonlin(@(bm) resid(bm, p, cfg, 0), ones(1,nP), lb, ub, opts);
p.beta_mult = x_const(:); p.fade = 0;
hold_const = run_holdout(p, cfg);

%% ----- 3. fading beta_mult (calibrated, fades after 8/17) ------------------
x_fade = lsqnonlin(@(bm) resid(bm, p, cfg, 1), ones(1,nP), lb, ub, opts);
p.beta_mult = x_fade(:); p.fade = 1;
hold_fade = run_holdout(p, cfg);

%% ----- report table --------------------------------------------------------
fprintf('\n=== Holdout net increase 10/26-11/9 (per province) ===\n');
fprintf('%-14s %8s %10s %10s %12s %12s\n','province','obs','flat-base','sharedQ2','const-mult','fade-mult');
for i=1:nP
    fprintf('%-14s %8.0f %10.2f %10.1f %12.1f %12.1f\n', ...
        provNames{i}, obs_hold(i), base_hold(i), hold_shared(i), hold_const(i), hold_fade(i));
end

% MAE
valid = all(isfinite([obs_hold,base_hold,hold_shared,hold_const,hold_fade]),2);
maeFun = @(h) mean(abs(h(valid) - obs_hold(valid)));
fprintf('\n%-14s %8s %10.2f %10.2f %12.2f %12.2f\n','MAE', '', ...
    maeFun(base_hold), maeFun(hold_shared), maeFun(hold_const), maeFun(hold_fade));

fprintf('\nCalibrated beta_mult:\n');
fprintf('  constant: %s\n', sprintf('%.2f ', x_const));
fprintf('  fading:   %s\n', sprintf('%.2f ', x_fade));

T = table(provNames, obs_hold, base_hold, hold_shared, hold_const, ...
    hold_fade, 'VariableNames', {'province', 'obs_hold', 'flat_base', ...
    'sharedQ2', 'constMult', 'fadeMult'});
mae = struct('flat', maeFun(base_hold), 'shared', maeFun(hold_shared), ...
    'const', maeFun(hold_const), 'fade', maeFun(hold_fade));
end

%% ----- run model, return holdout net increase ------------------------------
function hold = run_holdout(p, cfg)
    [t,Y] = task4_integrate(@(tt,y) rhs(tt,y,p,cfg.P,cfg.N,cfg.nP), [0 141], cfg.y0(:), p, ...
                  odeset('RelTol',1e-6,'AbsTol',1e-6));
    C = Y(:,2*cfg.nP+1:3*cfg.nP)+Y(:,3*cfg.nP+1:4*cfg.nP)+Y(:,4*cfg.nP+1:5*cfg.nP)+Y(:,6*cfg.nP+1:7*cfg.nP);
    C_fit  = interp1(t, C, 126);
    C_hold = interp1(t, C, 141);
    hold = (C_hold - C_fit).';
end

%% ----- calibration residual -------------------------------------------------
function r = resid(bm, p, cfg, fade)
    p.beta_mult = bm(:); p.fade = fade;
    [t,Y] = task4_integrate(@(tt,y) rhs(tt,y,p,cfg.P,cfg.N,cfg.nP), [0 141], cfg.y0(:), p, ...
                  odeset('RelTol',1e-6,'AbsTol',1e-6));
    C = Y(:,2*cfg.nP+1:3*cfg.nP)+Y(:,3*cfg.nP+1:4*cfg.nP)+Y(:,4*cfg.nP+1:5*cfg.nP)+Y(:,6*cfg.nP+1:7*cfg.nP);
    C_fit = interp1(t, C, 126);
    valid = isfinite(cfg.C_obs);
    fit = log(C_fit(valid).' + 1) - log(cfg.C_obs(valid) + 1);
    reg = sqrt(cfg.lambda) * (bm(:) - 1);
    r = [fit; reg];
end

%% ----- helpers ------------------------------------------------------------
function v = getVal(rows, tDay, field)
    idx = find(rows.t_day==tDay, 1);
    if isempty(idx), v=NaN; else, v=rows.(field)(idx); end
end

function dy = rhs(t,y,p,P,N,nP)
    y = reshape(y,nP,7);
    S=y(:,1);E=y(:,2);I=y(:,3);Q=y(:,4);R=y(:,5);Dd=y(:,6);M=y(:,7); %#ok<NASGU>
    bc = p.beta_c0*(1-p.u1*(t>=p.t1))*(1-p.u2*(t>=p.t2));
    bh = p.rhoH*bc; bf = p.rhoF*bc;
    Lambda = zeros(nP,1);
    for i=1:nP
        if p.fade
            mi = p.beta_mult(i)*(t < p.t1) + (t >= p.t1);
        else
            mi = p.beta_mult(i);
        end
        local = mi*(bc*I(i)+bh*Q(i)+bf*Dd(i));
        cross = 0;
        for j=1:nP
            if j~=i
                if p.fade, mj = p.beta_mult(j)*(t < p.t1) + (t >= p.t1);
                else, mj = p.beta_mult(j); end
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
