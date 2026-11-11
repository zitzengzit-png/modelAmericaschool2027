function cfg = config(varargin)
%CONFIG  Single configuration entry point for the 2026 Problem A rebuild.
%
%   cfg = config()                       tracker snapshot, W25-W43 fit,
%                                        W44-W45 holdout, v2 model settings
%   cfg = config('dataSource','legacy')  legacy workbook W25-W41
%   cfg = config(struct('nKnots',2))     struct override
%   cfg = config('fitWindow',[25 43], 'strict',false)
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
cfg.frozenSourceDir = fullfile(cfg.oldRoot, 'code', 'matlab'); % legacy, do not edit

% Data source and windows (ISO weeks).
cfg.dataSource = 'tracker';      % 'tracker' | 'legacy'
cfg.fitWindow  = [25 43];        % W25-W43: matches the 10,060 / 4,887 statement
cfg.holdout    = [44 45];        % W44-W45: forward validation only
cfg.strict     = true;           % assert published anchors in load_data

% Model variant (used from P1 onwards; kept here so paths/options are central).
cfg.modelVariant = 'v2';         % 'legacy' | 'v2'
cfg.hospitalTerm = true;         % structural sensitivity switch (betaH term)
cfg.nKnots       = 3;            % number of beta(t) change points
cfg.knotWeeks    = [28 34 41];   % mid-July, vaccination start, plateau

% State reconstruction defaults (used by state_at.m).
cfg.sigma            = 0.70;     % week^-1, mean incubation about 10 days
cfg.burialDelayDays  = 2.0;      % days, unburied corpse stock approximation
cfg.tracingDelayDays = 1.0;      % days, traced contact to isolation
cfg.isolationRatio   = 0.40;     % fallback Q / (C-M-R) when ETC data missing
cfg.reportFrac       = 1.0;      % observation reporting fraction (P2)

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
