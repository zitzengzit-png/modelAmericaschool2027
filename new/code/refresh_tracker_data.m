function snap = refresh_tracker_data(varargin)
%REFRESH_TRACKER_DATA  Download the latest tracker database and rebuild CSVs.
%
%   snap = refresh_tracker_data()
%   snap = refresh_tracker_data('tag', '20261111')
%   snap = refresh_tracker_data('force', true)
%
%   Sources
%     https://ebola-tracker.org/data/ebola-drc-database.csv
%     https://ebola-tracker.org/data/ebola-drc-database-dictionary.csv
%     https://ebola-tracker.org/en/data/  (headline response indicators)
%
%   Writes into ws/data/ebola_tracker (existing snapshots are kept)
%     ebola-drc-database-<tag>.csv
%     ebola-drc-database-dictionary-<tag>.csv
%     national_weekly_<tag>.csv
%     province_latest_<tag>.csv
%     health_zone_latest_<tag>.csv
%     response_latest_<tag>.csv
%     snapshot_metadata_<tag>.json
%
%   load_data() automatically picks the newest dated files.

cfg = config();
opts = struct( ...
    'tag', char(datetime('now', 'Format', 'yyyyMMdd')), ...
    'force', false, ...
    'url', 'https://ebola-tracker.org/data/ebola-drc-database.csv', ...
    'dictUrl', 'https://ebola-tracker.org/data/ebola-drc-database-dictionary.csv', ...
    'responseUrl', 'https://ebola-tracker.org/en/data/');
opts = parse_opts(opts, varargin{:});

if ~exist(cfg.trackerDir, 'dir')
    mkdir(cfg.trackerDir);
end

% -------------------------------------------------------------------------
% 1. Download the raw database
% -------------------------------------------------------------------------
tmp = [tempname, '.csv'];
cleaner = onCleanup(@() delete_if_exists(tmp)); %#ok<NASGU>
fprintf('Downloading %s ...\n', opts.url);
websave(tmp, opts.url, weboptions('Timeout', 120, 'ContentType', 'text'));

T = readtable(tmp, 'Encoding', 'UTF-8', ...
    'VariableNamingRule', 'preserve', 'TextType', 'string');
required = {'date', 'level', 'cases', 'deaths', 'new_cases', 'new_deaths'};
missing = required(~ismember(required, T.Properties.VariableNames));
if ~isempty(missing)
    error('refresh_tracker_data:badSchema', ...
        'Downloaded file is missing columns: %s', strjoin(missing, ', '));
end
T.date = datetime(string(T.date), 'InputFormat', 'yyyy-MM-dd');
maxDate = max(T.date);
fprintf('Downloaded %d rows, latest date %s\n', height(T), ...
    string(maxDate, 'yyyy-MM-dd'));

% Refuse to replace a newer snapshot by an older download.
prevRaw = latest_tracker_file(cfg.trackerDir, 'ebola-drc-database-2*.csv');
if ~isempty(prevRaw) && ~opts.force
    P = readtable(prevRaw, 'Encoding', 'UTF-8', ...
        'VariableNamingRule', 'preserve', 'TextType', 'string');
    prevMax = max(datetime(string(P.date), 'InputFormat', 'yyyy-MM-dd'));
    if maxDate < prevMax
        error('refresh_tracker_data:older', ...
            ['Downloaded snapshot (%s) is older than %s (%s). ' ...
            'Use force=true to override.'], ...
            string(maxDate, 'yyyy-MM-dd'), prevRaw, ...
            string(prevMax, 'yyyy-MM-dd'));
    end
end

rawFile = fullfile(cfg.trackerDir, ...
    sprintf('ebola-drc-database-%s.csv', opts.tag));
movefile(tmp, rawFile, 'f');
fprintf('Saved raw database: %s\n', rawFile);

% -------------------------------------------------------------------------
% 2. Dictionary (best effort) and headline response indicators
% -------------------------------------------------------------------------
dictFile = fullfile(cfg.trackerDir, ...
    sprintf('ebola-drc-database-dictionary-%s.csv', opts.tag));
try
    websave(dictFile, opts.dictUrl, ...
        weboptions('Timeout', 60, 'ContentType', 'text'));
    fprintf('Saved dictionary: %s\n', dictFile);
catch err
    warning('refresh_tracker_data:dict', ...
        'Dictionary download failed: %s', err.message);
end

R = table();
try
    R = fetch_response_page(opts.responseUrl, opts.tag);
    fprintf('Parsed %d headline response indicators from the data page.\n', ...
        height(R));
catch err
    warning('refresh_tracker_data:response', ...
        'Response page not parsed, database fallback will be used: %s', ...
        err.message);
end

% -------------------------------------------------------------------------
% 3. Rebuild derived CSVs
% -------------------------------------------------------------------------
popFile = latest_tracker_file(cfg.trackerDir, 'province_latest_*.csv');
buildOpts = struct( ...
    'populationFile', popFile, ...
    'zonePopulationFile', fullfile(cfg.trackerDir, ...
        'zone_summary_to_20261025.csv'));
if ~isempty(R)
    buildOpts.responseTable = R;
end

snap = build_tracker_snapshot(rawFile, cfg.trackerDir, opts.tag, buildOpts);

% -------------------------------------------------------------------------
% 4. Summary
% -------------------------------------------------------------------------
fprintf('\n=== tracker snapshot %s ===\n', opts.tag);
fprintf('latest daily     : %s  %d cases / %d deaths\n', ...
    snap.meta.latest_daily.date, snap.meta.latest_daily.cases, ...
    snap.meta.latest_daily.deaths);
fprintf('weekly anchors   : W%d-W%d (%d rows)\n', ...
    snap.meta.week_range(1), snap.meta.week_range(2), ...
    snap.meta.weekly_rows);
fprintf('daily rows       : %d (%s .. %s)\n', ...
    snap.meta.daily_rows, snap.meta.daily_range(1), snap.meta.daily_range(2));
fprintf('provinces / zones: %d / %d\n', ...
    height(snap.provinceLatest), height(snap.zoneLatest));
fprintf('province totals  : %d cases / %d deaths (as of %s)\n', ...
    sum(snap.provinceLatest.cum_confirmed), ...
    sum(snap.provinceLatest.cum_deaths), ...
    string(snap.provinceLatest.as_of(1)));
disp(snap.responseLatest);
end

% -------------------------------------------------------------------------
function opts = parse_opts(opts, varargin)
if isempty(varargin)
    return;
end
if numel(varargin) == 1 && isstruct(varargin{1})
    f = fieldnames(varargin{1});
    for k = 1:numel(f)
        if ~isfield(opts, f{k})
            error('refresh_tracker_data:unknownOption', ...
                'Unknown option: %s', f{k});
        end
        opts.(f{k}) = varargin{1}.(f{k});
    end
    return;
end
if mod(numel(varargin), 2) ~= 0
    error('refresh_tracker_data:badArgs', ...
        'Use name-value pairs or a single struct.');
end
for k = 1:2:numel(varargin)
    name = char(varargin{k});
    if ~isfield(opts, name)
        error('refresh_tracker_data:unknownOption', ...
            'Unknown option: %s', name);
    end
    opts.(name) = varargin{k + 1};
end
end

function delete_if_exists(f)
if isfile(f)
    delete(f);
end
end
