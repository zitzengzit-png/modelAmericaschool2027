function T = q4_border_risk(nSeeds, mGrid, kGrid)
%Q4_BORDER_RISK  Negative-binomial branch-process import risk.
%
%   T = q4_border_risk(nSeeds, mGrid, kGrid)
%   nSeeds: vector of seed counts (e.g. [9 1])
%   mGrid : local secondary-case means
%   kGrid : negative-binomial dispersion (Inf = Poisson)

if nargin < 1 || isempty(nSeeds), nSeeds = [9 1]; end
if nargin < 2 || isempty(mGrid), mGrid = [0.8 1.0 1.05 1.2 1.5]; end
if nargin < 3 || isempty(kGrid), kGrid = [0.5 1 Inf]; end

rows = {};
for n = nSeeds(:)'
    for m = mGrid(:)'
        for k = kGrid(:)'
            q = extinction_prob(m, k);
            rows{end+1,1} = table(n, m, k, q, 1 - q^n, ...
                'VariableNames', {'nSeeds', 'm', 'k', 'q_extinct', ...
                'p_nonextinct'}); %#ok<AGROW>
        end
    end
end
T = vertcat(rows{:});
end

function q = extinction_prob(m, k)
if m <= 1
    q = 1;
    return;
end
q = 0;
for iter = 1:10000
    if isinf(k)
        qNew = exp(m * (q - 1));
    else
        qNew = (1 + (m/k) * (1 - q))^(-k);
    end
    if abs(qNew - q) < 1e-12
        q = qNew;
        return;
    end
    q = qNew;
end
end
