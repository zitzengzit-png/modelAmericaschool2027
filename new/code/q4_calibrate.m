function fit = q4_calibrate(D, p, P, y0, opts)
%Q4_CALIBRATE  Calibrate 8 province-level beta multipliers to 10/25 totals.
%
%   fit = q4_calibrate(D, p, P, y0)
%   fit = q4_calibrate(D, p, P, y0, struct('nStarts',2,'verbose',true))
%
%   Target: provincial cumulative confirmed cases on 2026-10-18 and 10/25.
%   Low-count provinces are fixed at beta_mult=1; only high-burden provinces
%   are calibrated, otherwise 2-13 case provinces dominate R_net.

if nargin < 5 || isempty(opts), opts = struct(); end
opts = set_default(opts, 'nStarts', 2);
opts = set_default(opts, 'verbose', true);
opts = set_default(opts, 'lambda', 0.05);

nP = D.nP;
Cobs = D.C10;
Cobs18 = D.C1018;

% Only high-burden provinces are calibrated. Low-count provinces are fixed
% at 1: their counts are too small to identify a multiplier and letting them
% free would dominate R_net.
fitIdx = find(isfinite(Cobs) & Cobs >= 50);
nF = numel(fitIdx);
if nF < 2
    error('q4_calibrate:tooFewTargets', 'Need at least two high-burden provinces.');
end
baseMult = ones(nP, 1);
lb = 0.50 * ones(nF, 1);
ub = 2.50 * ones(nF, 1);
q0List = [ones(nF, 1), 1.20 * ones(nF, 1)];
q0List = q0List(:, 1:min(opts.nStarts, size(q0List, 2)));

lsOpts = optimoptions('lsqnonlin', 'Display', 'off', ...
    'MaxFunctionEvaluations', 400, 'MaxIterations', 300, ...
    'FunctionTolerance', 1e-8, 'StepTolerance', 1e-8);

bestCost = inf; bestQ = [];
for k = 1:size(q0List, 2)
    obj = @(q) residual(q, D, p, P, y0, fitIdx, Cobs, Cobs18, ...
        baseMult, opts.lambda);
    try
        [qfit, resnorm, ~, exitflag] = lsqnonlin( ...
            obj, q0List(:,k), lb, ub, lsOpts);
    catch err
        if opts.verbose
            fprintf('  Q4 calibrate start %d failed: %s\n', k, err.message);
        end
        continue;
    end
    if opts.verbose
        fprintf('  Q4 calibrate start %d: cost %.4g, success %d\n', ...
            k, resnorm, exitflag > 0);
    end
    if resnorm < bestCost
        bestCost = resnorm;
        bestQ = qfit;
    end
end
if isempty(bestQ)
    error('q4_calibrate:allFailed', 'All calibration starts failed.');
end

betaMult = baseMult;
betaMult(fitIdx) = bestQ;
p2 = p;
p2.betaMult = betaMult;
out = q4_simulate(D, p2, P, y0, 0:126);
fit = struct();
fit.betaMult = betaMult;
fit.fitIdx = fitIdx;
fit.cost = bestCost;
fit.C10 = out.C(end, :)';
fit.C1018 = out.C(120, :)';
fit.success = true;
end

function res = residual(q, D, p, P, y0, fitIdx, Cobs, Cobs18, ...
    baseMult, lambda)
betaMult = baseMult;
betaMult(fitIdx) = q;
p2 = p;
p2.betaMult = betaMult;
try
    out = q4_simulate(D, p2, P, y0, 0:126);
    C25 = out.C(127, :)';
    C18 = out.C(120, :)';
catch
    res = 1e6 * ones(3*numel(fitIdx), 1);
    return;
end
C25 = max(C25(fitIdx), 1);
C18 = max(C18(fitIdx), 1);
O25 = max(Cobs(fitIdx), 1);
O18 = max(Cobs18(fitIdx), 1);
r25 = log(C25) - log(O25);
r18 = 0.5 * (log(C18) - log(O18));
res = [r25; r18; sqrt(lambda) * (q - 1)];
end

function s = set_default(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
