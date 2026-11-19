%% Q2 best tau: second knot 2026-09-20
% Data-driven best from Q2_tau_grid; saved alongside the 10/11 baseline.
clear; clc; close all;

cfg = config();
data = load_data(cfg);
outDir = cfg.q2OutDir;
cfgT = cfg;
cfgT.betaKnots = [datetime(2026, 8, 17); datetime(2026, 9, 20)];

fitFix = fit_daily_seiqrd(data, cfgT, struct('nStarts', 8, ...
    'verbose', true, 'fixRhoRep', true));
fitFree = fit_daily_seiqrd(data, cfgT, struct('nStarts', 8, ...
    'verbose', true, 'fixRhoRep', false));

write_one(outDir, fitFix, 'Q2_besttau_fixed');
write_one(outDir, fitFree, 'Q2_besttau_free');

fprintf('besttau fixed: R2 %.4f/%.4f holdMAPE %.3f/%.3f R0 %.3f late %.3f AIC %.1f\n', ...
    fitFix.metrics.R2cases, fitFix.metrics.R2deaths, ...
    fitFix.metrics.holdoutMAPEcases, fitFix.metrics.holdoutMAPEdeaths, ...
    fitFix.metrics.R0, fitFix.metrics.R0late, fitFix.metrics.AIC);
fprintf('besttau free rhoRep %.4f: R2 %.4f/%.4f holdMAPE %.3f/%.3f AIC %.1f\n', ...
    fitFree.params.rhoRep, fitFree.metrics.R2cases, ...
    fitFree.metrics.R2deaths, fitFree.metrics.holdoutMAPEcases, ...
    fitFree.metrics.holdoutMAPEdeaths, fitFree.metrics.AIC);
fprintf('Q2 BEST TAU OK\n');

% -------------------------------------------------------------------------
function write_one(outDir, fit, prefix)
writetable(fit.metrics.params, fullfile(outDir, [prefix '_parameters.csv']));
m = fit.metrics;
m = rmfield(m, 'params');
m.params = table2struct(fit.metrics.params);
m.q = fit.q;
m.qFull = fit.qFull;
m.paramNames = fit.paramNames;
m.freeNames = fit.freeNames;
m.fixedParams = fit.fixedParams;
m.y0 = fit.y0;
m.knots = fit.knots;
fid = fopen(fullfile(outDir, [prefix '_metrics.json']), 'w');
fprintf(fid, '%s', jsonencode(m, 'PrettyPrint', true));
fclose(fid);
end
