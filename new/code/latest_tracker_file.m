function f = latest_tracker_file(dirPath, pattern)
%LATEST_TRACKER_FILE  Newest tracker file matching a pattern.
%   f = latest_tracker_file(dirPath, 'national_weekly_*.csv') returns the
%   file whose name contains the largest 8-digit date tag (YYYYMMDD).
%   Files without a date tag fall back to the newest file modification time.
%   Returns '' when nothing matches.

d = dir(fullfile(dirPath, pattern));
if isempty(d)
    f = '';
    return;
end
names = string({d.name});
score = -inf(numel(names), 1);
for k = 1:numel(names)
    t = regexp(names(k), '(\d{8})', 'tokens', 'once');
    if ~isempty(t)
        score(k) = str2double(t{1});
    end
end
if all(~isfinite(score))
    [~, i] = max([d.datenum]);
else
    [~, i] = max(score);
end
f = fullfile(dirPath, d(i).name);
end
