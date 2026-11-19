%% Task 1 checks: legacy R0 regression and closed-form vs spectral radius
% Run from ws/new/code: task1_checks
% Writes ws/new/outputs/task1/T1_*.csv
clear; clc;

cfg = config();
outDir = cfg.task1OutDir;

%% 1. Legacy two-channel regression (old W25-W41 fit)
oldFile = fullfile(cfg.oldRoot, 'outputs', 'matlab', ...
    'fit_parameters_matlab.csv');
Told = readtable(oldFile, 'Encoding', 'UTF-8', ...
    'PreserveVariableNames', true);
getold = @(name) Told.estimate(find(strcmp(Told.parameter, name), 1));

pOld = struct();
pOld.alpha = getold('alpha');
pOld.mu = getold('mu');
pOld.muQ = pOld.mu;
pOld.gamma = getold('gamma');
pOld.gammaQ = getold('gammaQ');
pOld.nu = getold('nu');
pOld.kappa = getold('kappa');
pOld.sigma = getold('sigma');
beta0 = getold('beta0');
beta1 = getold('beta1');
refOld = [getold('R0_early'); getold('R0_late')];

r0Old = @(beta) old_r0(beta, pOld);
r0OldVals = [r0Old(beta0); r0Old(beta1)];
r0OldSpec = [spectral_old(beta0, pOld); spectral_old(beta1, pOld)];

%% 2. New three-channel model: closed form vs numerical spectral radius
pFile = fullfile(cfg.p1OutDir, 'P1_parameters.csv');
P = readtable(pFile, 'Encoding', 'UTF-8', ...
    'PreserveVariableNames', true);
getp = @(name) P.estimate(find(strcmp(P.parameter, name), 1));

pNew = struct();
pNew.betaC0 = getp('betaC0');
pNew.u1 = getp('u1');
pNew.u2 = getp('u2');
pNew.alpha = getp('alpha0');
pNew.mu = getp('mu');
pNew.muQ = pNew.mu;
pNew.gamma = getp('gamma');
pNew.gammaQ = getp('gammaQ');
pNew.nu = getp('nu');
pNew.sigma = getp('sigma');
pNew.rhoH0 = getp('rhoH0');
pNew.rhoF0 = getp('rhoF0');
pNew.rhoRep = getp('rhoRep');

betaEarly = pNew.betaC0;
betaLate = pNew.betaC0 * (1 - pNew.u1) * (1 - pNew.u2);
r0New = @(beta) new_r0(beta, pNew);
r0NewVals = [r0New(betaEarly); r0New(betaLate)];
r0NewSpec = [spectral_new(betaEarly, pNew); ...
    spectral_new(betaLate, pNew)];

%% 3. Checks table
tol = 1e-9;
check = strings(0, 1);
status = strings(0, 1);
detail = strings(0, 1);

check(end + 1) = "legacy_R0_output";
ok = max(abs(r0OldVals - refOld)) < tol;
status(end + 1) = pass_fail(ok);
detail(end + 1) = sprintf('formula %.9f/%.9f vs CSV %.9f/%.9f', ...
    r0OldVals(1), r0OldVals(2), refOld(1), refOld(2));

check(end + 1) = "legacy_R0_spectral";
ok = max(abs(r0OldSpec - r0OldVals)) < tol;
status(end + 1) = pass_fail(ok);
detail(end + 1) = sprintf('spectral %.9f/%.9f vs formula %.9f/%.9f', ...
    r0OldSpec(1), r0OldSpec(2), r0OldVals(1), r0OldVals(2));

check(end + 1) = "new_R0_spectral_early";
ok = abs(r0NewSpec(1) - r0NewVals(1)) < tol;
status(end + 1) = pass_fail(ok);
detail(end + 1) = sprintf('spectral %.9f vs formula %.9f', ...
    r0NewSpec(1), r0NewVals(1));

check(end + 1) = "new_R0_spectral_late";
ok = abs(r0NewSpec(2) - r0NewVals(2)) < tol;
status(end + 1) = pass_fail(ok);
detail(end + 1) = sprintf('spectral %.9f vs formula %.9f', ...
    r0NewSpec(2), r0NewVals(2));

[~, Rc, Rh, Rf] = r0_daily(pNew, betaEarly);
ok = all([Rc Rh Rf] >= 0);
check(end + 1) = "three_channels_nonnegative";
status(end + 1) = pass_fail(ok);
detail(end + 1) = sprintf('Rc %.4f, Rh %.4f, Rf %.4f', Rc, Rh, Rf);

ok = strcmp(P.unit{strcmp(P.parameter, 'betaC0')}, 'day^-1') && ...
    strcmp(P.unit{strcmp(P.parameter, 'alpha0')}, 'day^-1') && ...
    strcmp(P.unit{strcmp(P.parameter, 'mu')}, 'day^-1');
check(end + 1) = "daily_rate_units";
status(end + 1) = pass_fail(ok);
detail(end + 1) = "betaC0, alpha0 and mu are day^-1";

CHK = table(check(:), status(:), detail(:), ...
    'VariableNames', {'check', 'status', 'detail'});
disp(CHK);
writetable(CHK, fullfile(outDir, 'T1_checks.csv'));

%% 4. R0 regression table
scenario = ["legacy_early"; "legacy_late"; "new_early"; "new_late"];
betaC = [beta0; beta1; betaEarly; betaLate];
formula = [r0OldVals; r0NewVals];
spectral = [r0OldSpec; r0NewSpec];
reference = [refOld; r0NewVals];
R0T = table(scenario, betaC, formula, spectral, reference, ...
    abs(formula - spectral), abs(formula - reference), ...
    'VariableNames', {'scenario', 'betaC', 'R0_formula', ...
    'R0_spectral', 'R0_reference', 'diff_spectral', 'diff_reference'});
disp(R0T);
writetable(R0T, fullfile(outDir, 'T1_R0_regression.csv'));

fprintf('\nTask 1 checks written to %s\n', outDir);

% -------------------------------------------------------------------------
function v = old_r0(beta, p)
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
v = beta / a + beta * p.kappa / p.nu * ...
    (p.mu / a + (p.alpha / a) * (p.muQ / b));
end

function v = new_r0(betaC, p)
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
betaH = p.rhoH0 * betaC;
betaF = p.rhoF0 * betaC;
v = betaC / a + p.alpha * betaH / (a * b) + ...
    (betaF / p.nu) * (p.mu / a + p.alpha * p.muQ / (a * b));
end

function v = spectral_old(beta, p)
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
F = zeros(4, 4);
F(1, 2) = beta;
F(1, 4) = beta * p.kappa;
V = [p.sigma, 0, 0, 0; ...
    -p.sigma, a, 0, 0; ...
    0, -p.alpha, b, 0; ...
    0, -p.mu, -p.muQ, p.nu];
v = max(abs(eig(F / V)));
end

function v = spectral_new(betaC, p)
a = p.alpha + p.gamma + p.mu;
b = p.gammaQ + p.muQ;
F = zeros(4, 4);
F(1, 2) = betaC;
F(1, 3) = p.rhoH0 * betaC;
F(1, 4) = p.rhoF0 * betaC;
V = [p.sigma, 0, 0, 0; ...
    -p.sigma, a, 0, 0; ...
    0, -p.alpha, b, 0; ...
    0, -p.mu, -p.muQ, p.nu];
v = max(abs(eig(F / V)));
end

function s = pass_fail(ok)
if ok
    s = "PASS";
else
    s = "FAIL";
end
end
