function p = default_params(data)
%DEFAULT_PARAMS  Baseline SEIQRD parameters.
%   For the ebola-tracker W25-W45 data source, use the provisional latest
%   fit. For the legacy W25-W41 workbook fallback, keep the reference values.
p.N = data.N;

if isfield(data, 'data_source') && contains(string(data.data_source), 'ebola-tracker')
    % Provisional fit to tracker W25-W45 (tau=5, one start).
    p.beta0 = 1.5069;   % week^-1, before the change point
    p.beta1 = 0.8938;   % week^-1, from W30 onward
    p.tau = 5;          % t = 0 is W25, so tau = 5 is W30
    p.alpha = 1.2878;   % week^-1, admission/isolation
    p.mu = 0.2756;      % week^-1, death outside isolation
else
    % Reference baseline (W25-W41 retrospective series).
    p.beta0 = 1.298;    % week^-1, before the change point
    p.beta1 = 0.847;    % week^-1, from W32 onward
    p.tau = 7;          % t = 0 is W25, so tau = 7 is W32
    p.alpha = 1.244;    % week^-1, admission/isolation
    p.mu = 0.235;       % week^-1, death outside isolation
end

p.muQ = p.mu;           % assume muQ = mu
p.sigma = 0.70;         % week^-1, mean incubation about 10 days
p.gamma = 0.21;         % week^-1, community recovery
p.gammaQ = 0.21;        % week^-1, isolated recovery
p.nu = 3.5;             % week^-1, safe burial (about 2 days)
p.kappa = 3.0;          % relative corpse infectivity
p.dTraced = 1.0;        % days from tracing to isolation
p.y0 = data.y0;
end
