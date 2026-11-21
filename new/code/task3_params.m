function p = task3_params(cfg, data)
%TASK3_PARAMS  Baseline (Q2 9/20) and intervention parameters for Task 3.
%
%   p = task3_params(cfg, data)
%
%   Baseline follows ws/docs/第三问建模.md section 0.2: the Q2 9/20 daily
%   fit with rho_rep=1:
%       betaC0=0.11251, u1=0.48919, u2=-0.50,
%       alpha0=0.16979, mu=0.03488.
%   Intervention values follow section 2 (main scenario values).

p = struct();
p.N = data.N;

% ---- Baseline (Q2 9/20, rho_rep = 1) ---------------------------------------
p.betaC0 = 0.112512897763716;
p.u1     = 0.489194309176865;
p.u2     = -0.499999999999215;
p.alpha0 = 0.169786629921235;
p.mu     = 0.0348823701373093;
p.muQ    = p.mu;
p.sigma  = 0.10;
p.gamma  = 0.03;
p.gammaQ = 0.03;
p.nu0    = 0.50;
p.rhoH0  = 0.40;
p.rhoF0  = 3.00;
p.t1     = days(datetime(2026, 8, 17) - cfg.dayZero);
p.t2     = days(datetime(2026, 9, 20) - cfg.dayZero);
p.tEnd   = 365;

% ---- 1. Isolation: target 4.1 d total exit from I --------------------------
p.iso.alpha1 = 1/4.1 - p.gamma - p.mu;
p.iso.r      = log(2) / 27.1;

% ---- 2. Contact tracing -----------------------------------------------------
p.ct.q0  = 0.78;
p.ct.eta = 0.50;

% ---- 3. Safe burial: 2 d -> 1 d --------------------------------------------
p.burial.nu1 = 1.00;
p.burial.r   = log(2) / 21.2;

% ---- 4. Hospital infection control -----------------------------------------
p.hic.eta = 0.71;
p.hic.r   = log(2) / 11.1;

% ---- 5. Vaccination ---------------------------------------------------------
p.vax.vmax  = 0.80;
p.vax.eps   = 0.80;
p.vax.delay = 7;

% ---- 6. MBP134 / remdesivir -------------------------------------------------
p.mbp.c   = 0.80;
p.mbp.eta = 0.50;
p.rdv.c   = 0.80;
p.rdv.eta = 0.00;

% ---- 7. Obeldesivir PEP -----------------------------------------------------
p.pep.omega = 0.43;
p.pep.p     = 0.80;
p.pep.eps   = 0.50;
p.pep.delay = 1;

% ---- 8. Community education -------------------------------------------------
p.ce.emax = 0.80;
p.ce.etaC = 0.05;
p.ce.etaF = 0.20;
p.ce.rC   = log(2) / 12.5;
p.ce.rF   = log(2) / 10.3;

% ---- Sensitivity ranges (section 8 of the Task 3 document) -----------------
p.paramRanges = table( ...
    ["alpha1"; "etaCT"; "nu1"; "etaHIC"; "vmax"; "epsV"; "dV"; ...
     "cMBP"; "etaMBP"; "etaRDV"; "omegaPEP"; "pPEP"; "epsPEP"; ...
     "emax"; "etaCEc"; "etaCEf"; "rhoH0"; "rhoF0"], ...
    [p.iso.alpha1; p.ct.eta; p.burial.nu1; p.hic.eta; p.vax.vmax; ...
     p.vax.eps; p.vax.delay; p.mbp.c; p.mbp.eta; p.rdv.eta; ...
     p.pep.omega; p.pep.p; p.pep.eps; p.ce.emax; p.ce.etaC; ...
     p.ce.etaF; p.rhoH0; p.rhoF0], ...
    ["0.135-0.435"; "0.30-0.70"; "0.70-2.00"; "0.50-0.90"; ...
     "0.60-0.90"; "0.50-1.00"; "3-10"; "0.60-1.00"; "0.20-0.80"; ...
     "0-0.20"; "0.30-0.60"; "0.50-0.90"; "0.20-0.80"; "0.50-0.90"; ...
     "0-0.15"; "0.10-0.30"; "0.30-0.50"; "2.86-3.83"], ...
    'VariableNames', {'parameter', 'main', 'range'});
end
