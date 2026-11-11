function cfg = config(varargin)
%CONFIG  Single configuration entry point for the 2026 Problem A rebuild.
%
%   cfg = config()                       tracker daily, 2026-06-21..2026-10-25
%                                        fit, 2026-10-26..2026-11-09 holdout
%   cfg = config('dataSource','legacy')  legacy workbook W25-W41
%   cfg = config(struct('nKnots',2))     struct override
%   cfg = config('fitStart',datetime(2026,6,21), 'strict',false)
%
%   All scripts should call cfg = config(); data = load_data(cfg);
%   so that no parameter or path is hard-coded twice.

root = fileparts(fileparts(fileparts(mfilename('fullpath')))); % ws

cfg = struct();
cfg.wsRoot          = root;
cfg.oldRoot         = fullfile(root, 'old');
cfg.newRoot         = fullfile(root, 'new');
cfg.docsDir         = fullfile(root, 'docs');
cfg.dataDir         = fullfile(cfg.newRoot, 'data');
cfg.trackerDir      = fullfile(cfg.dataDir, 'ebola_tracker');
cfg.legacyWorkbook  = fullfile(cfg.oldRoot, 'data', 'outbreak_data.xlsx');
cfg.outDir          = fullfile(cfg.newRoot, 'outputs', 'p0');
cfg.p1OutDir        = fullfile(cfg.newRoot, 'outputs', 'p1');
cfg.frozenSourceDir = fullfile(cfg.oldRoot, 'code', 'matlab'); % legacy, do not edit

% Data source and time standard (day).
cfg.dataSource = 'tracker';      % 'tracker' | 'legacy'
cfg.timeUnit   = 'day';          % all state reconstruction/integration in days
cfg.dayZero    = datetime(2026, 6, 21);
cfg.fitStart   = datetime(2026, 6, 21);
cfg.fitEnd     = datetime(2026, 10, 25);   % statement 10,060 / 4,887
cfg.holdStart  = datetime(2026, 10, 26);
cfg.holdEnd    = datetime(2026, 11, 9);    % latest daily 11,042 / 5,387
cfg.fitWeeks   = [25 43];        % weekly aggregation / validation window
cfg.holdWeeks  = [44 45];        % weekly aggregation / validation holdout
cfg.fitWindow  = cfg.fitWeeks;   % backward-compatible alias
cfg.holdout    = cfg.holdWeeks;  % backward-compatible alias
cfg.strict     = true;           % assert published anchors in load_data

% Model variant (used from P1 onwards; kept here so paths/options are central).
cfg.modelVariant = 'v2';         % 'legacy' | 'v2'
cfg.hospitalTerm = true;         % structural sensitivity switch (betaH term)
cfg.nKnots       = 3;            % number of beta(t) change points
cfg.knotWeeks    = [28 34 41];   % mid-July, vaccination start, plateau
cfg.knotDates    = datetime([2026 7 13; 2026 8 17; 2026 10 11]);

% State reconstruction defaults (rates per DAY).
cfg.sigmaWeek = 0.70;            % week^-1, mean incubation about 10 days
cfg.gammaWeek = 0.21;            % week^-1
cfg.muWeek    = 0.235;           % week^-1
cfg.alphaWeek = 1.244;           % week^-1
cfg.nuWeek    = 3.5;             % week^-1
cfg.sigma  = cfg.sigmaWeek / 7;  % 0.1000 day^-1
cfg.gamma  = cfg.gammaWeek / 7;  % 0.0300 day^-1
cfg.gammaQ = cfg.gamma;
cfg.mu     = cfg.muWeek / 7;     % 0.03357 day^-1
cfg.muQ    = cfg.mu;
cfg.alpha  = cfg.alphaWeek / 7;  % 0.1777 day^-1
cfg.nu     = cfg.nuWeek / 7;     % 0.5000 day^-1
cfg.kappa  = 3.0;                % corpse relative infectivity (legacy comparison)

cfg.burialDelayDays  = 2.0;      % days, unburied corpse stock approximation
cfg.tracingDelayDays = 1.0;      % days, traced contact to isolation
cfg.isolationRatio   = 0.40;     % fallback Q / (C-M-R) when ETC data missing
cfg.reportFrac       = 1.0;      % observation reporting fraction (P2)

% P1: daily three-route fitting settings.
cfg.rhoH0      = 0.40;           % betaH / betaC baseline (net excess hospital)
cfg.rhoF0      = 3.00;           % betaF / betaC baseline (funeral)
cfg.rhoM       = 1.00;           % death reporting ratio
cfg.betaC0     = 0.20;           % day^-1, initial guess
cfg.u1         = 0.30;           % reduction at the first knot
cfg.u2         = 0.10;           % second-phase multiplier; negative = rebound
cfg.rhoRep     = 0.70;           % case reporting ratio, initial guess
cfg.betaKnots  = [datetime(2026, 8, 17); datetime(2026, 10, 11)];
cfg.alphaPrior = 0.15;           % weak prior for alpha0 (day^-1)
cfg.muPrior    = 0.030;          % weak prior for mu (day^-1)
cfg.fitWeights = struct('mu', 1.0, 'weekly', 0.3, 'cfr', 5.0, ...
    'alpha', 0.3, 'muPrior', 0.3, 'rho', 0.3);

% Output naming.
cfg.outTag = 'v2';

% -------------------------------------------------------------------------
% Overrides
% -------------------------------------------------------------------------
if nargin == 1 && isstruct(varargin{1})
    cfg = merge_struct(cfg, varargin{1});
elseif nargin > 0
    if mod(nargin, 2) ~= 0
        error('config:badArgs', 'Use name-value pairs or a single struct.');
    end
    for k = 1:2:nargin
        name = varargin{k};
        if ~(ischar(name) || isstring(name))
            error('config:badName', 'Option names must be text.');
        end
        name = char(name);
        if ~isfield(cfg, name)
            error('config:unknownOption', 'Unknown option: %s', name);
        end
        cfg.(name) = varargin{k + 1};
    end
end

if ~exist(cfg.outDir, 'dir')
    mkdir(cfg.outDir);
end
if ~exist(cfg.p1OutDir, 'dir')
    mkdir(cfg.p1OutDir);
end
end

% -------------------------------------------------------------------------
function s = merge_struct(s, o)
f = fieldnames(o);
for k = 1:numel(f)
    if ~isfield(s, f{k})
        error('config:unknownOption', 'Unknown option: %s', f{k});
    end
    s.(f{k}) = o.(f{k});
end
end
