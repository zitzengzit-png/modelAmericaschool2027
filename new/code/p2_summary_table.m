function T = p2_summary_table(names, X, baseline)
%P2_SUMMARY_TABLE  Mean/sd/median/95% interval for each column of X.
%
%   names    cellstr or string array, one per column
%   X        n-by-p matrix (NaN rows/columns are ignored per column)
%   baseline 1-by-p vector of reference values

names = cellstr(string(names));
names = names(:);
p = numel(names);
if size(X, 2) ~= p
    error('p2_summary_table:sizeMismatch', ...
        'X has %d columns but names has %d entries.', size(X, 2), p);
end
if nargin < 3 || isempty(baseline)
    baseline = nan(1, p);
end
baseline = baseline(:)';

meanV = nan(p, 1);
sdV = nan(p, 1);
medV = nan(p, 1);
loV = nan(p, 1);
hiV = nan(p, 1);
nV = zeros(p, 1);

for i = 1:p
    x = X(:, i);
    x = x(isfinite(x));
    nV(i) = numel(x);
    if isempty(x)
        continue;
    end
    meanV(i) = mean(x);
    if numel(x) > 1
        sdV(i) = std(x);
    else
        sdV(i) = 0;
    end
    medV(i) = median(x);
    loV(i) = local_quantile(x, 0.025);
    hiV(i) = local_quantile(x, 0.975);
end

T = table(names, baseline(:), meanV, sdV, medV, loV, hiV, nV, ...
    'VariableNames', {'quantity', 'baseline', 'mean', 'sd', ...
    'median', 'p2_5', 'p97_5', 'n'});
end

function q = local_quantile(x, p)
x = sort(x(:));
n = numel(x);
if n == 1
    q = x;
    return;
end
pos = 1 + (n - 1) * p;
lo = floor(pos);
hi = ceil(pos);
if lo == hi
    q = x(lo);
else
    q = x(lo) + (pos - lo) * (x(hi) - x(lo));
end
end
