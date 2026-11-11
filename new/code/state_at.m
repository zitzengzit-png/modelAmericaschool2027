function [y, st] = state_at(data, week, opts)
%STATE_AT  Reconstruct the SEIQRD state at a given ISO week.
%
%   [y, st] = state_at(data, week)
%   [y, st] = state_at(data, week, opts)
%
%   opts.qSource          'auto' (default) | 'etc' | 'ratio'
%   opts.isolationRatio   fallback Q/(C-M-R), default from data.cfg or 0.40
%   opts.burialDelayDays  default from data.cfg or 2.0
%   opts.sigma            default from data.cfg or 0.70
%
%   Rules
%     C, M  cumulative confirmed cases and deaths from the weekly series
%     R     cumulative recoveries; last valid value is carried forward
%     Q     etc_admitted when available, otherwise isolationRatio*(C-M-R)
%     I     max(C - M - Q - R, 0)      so that I+Q+R+M = C exactly
%     E     weekly new cases / sigma   (about one incubation period of stock)
%     D     burialDelayDays/7 * weekly deaths (unburied corpse stock)
%     S     N - E - I - Q - R - M
%
%   The returned struct st records the provenance of every component so a
%   report can state which parts are observed and which are reconstructed.

if nargin < 3 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'qSource', 'auto');
opts = set_default(opts, 'isolationRatio', get_cfg(data, 'isolationRatio', 0.40));
opts = set_default(opts, 'burialDelayDays', get_cfg(data, 'burialDelayDays', 2.0));
opts = set_default(opts, 'sigma', get_cfg(data, 'sigma', 0.70));

if ~isfield(data, 'series') || ~isfield(data.series, 'week')
    error('state_at:noSeries', ...
        'data.series is missing; rebuild it with load_data().');
end

idx = find(data.series.week == week, 1);
if isempty(idx)
    error('state_at:weekNotFound', ...
        'Week W%d is not in the series W%d-W%d.', week, ...
        data.series.week(1), data.series.week(end));
end

N = data.N;
C = data.series.cases(idx);
M = data.series.deaths(idx);

% Recoveries: carry the last valid value forward.
R = data.series.recovered(idx);
rSource = "observed";
if ~isfinite(R)
    prior = data.series.recovered(1:idx);
    prior = prior(isfinite(prior));
    if isempty(prior)
        R = 0;
        rSource = "assumed_zero";
    else
        R = prior(end);
        rSource = "carried_forward";
    end
end
R = max(R, 0);

% Isolation stock.
active = max(C - M - R, 0);
qEtc = data.series.etcAdmitted(idx);
qFixed = NaN;
if isfield(data.series, 'fixedQ')
    qFixed = data.series.fixedQ(idx);
end

if isfinite(qFixed)
    Q = qFixed;
    qSource = "fixed";
else
    switch lower(string(opts.qSource))
        case "etc"
            if ~isfinite(qEtc)
                error('state_at:noEtc', ...
                    'etc_admitted is missing at W%d; use qSource=''ratio''.', week);
            end
            Q = qEtc;
            qSource = "etc_admitted";
        case "ratio"
            Q = opts.isolationRatio * active;
            qSource = "isolation_ratio";
        case "auto"
            if isfinite(qEtc) && qEtc > 0
                Q = qEtc;
                qSource = "etc_admitted";
            else
                Q = opts.isolationRatio * active;
                qSource = "isolation_ratio";
            end
        otherwise
            error('state_at:badQSource', ...
                'qSource must be auto, etc or ratio (got %s).', opts.qSource);
    end
end
Q = min(max(Q, 0), active);

% Remaining states.
I = max(C - M - Q - R, 0);
newC = pick_new(data.series.newCasesAdj(idx), ...
    data.series.newCasesRaw(idx), data.series.cases, idx);
newD = pick_new(data.series.newDeathsAdj(idx), ...
    data.series.newDeathsRaw(idx), data.series.deaths, idx);
newC = max(newC, 0);
newD = max(newD, 0);
E = fixed_value(data.series, 'fixedE', idx);
eSource = "reconstructed";
if isfinite(E)
    eSource = "fixed";
else
    E = newC / opts.sigma;
end
D = fixed_value(data.series, 'fixedD', idx);
dSource = "reconstructed";
if isfinite(D)
    dSource = "fixed";
else
    D = (opts.burialDelayDays / 7) * newD;
end
S = N - E - I - Q - R - M;

y = [S; E; I; Q; R; D; M];

% Consistency checks.
if S <= 0
    error('state_at:negativeS', ...
        'Reconstructed S is %.1f at W%d; check N and the initial stocks.', ...
        S, week);
end
tol = 1e-9 * max(N, 1);
if abs((I + Q + R + M) - C) > max(tol, 1e-6)
    error('state_at:caseIdentity', ...
        'I+Q+R+M does not equal C at W%d.', week);
end
if abs((S + E + I + Q + R + M) - N) > max(tol, 1e-6)
    error('state_at:conservation', ...
        'S+E+I+Q+R+M does not equal N at W%d.', week);
end

st = struct();
st.week = week;
if isfield(data.series, 'weekEnd') && numel(data.series.weekEnd) >= idx
    st.week_end = data.series.weekEnd(idx);
end
st.S = S; st.E = E; st.I = I; st.Q = Q; st.R = R; st.D = D; st.M = M;
st.C = C;
st.new_cases = newC;
st.new_deaths = newD;
st.q_source = qSource;
st.r_source = rSource;
st.e_source = eSource;
st.d_source = dSource;
st.sigma = opts.sigma;
st.burial_delay_days = opts.burialDelayDays;
st.isolation_ratio = opts.isolationRatio;
st.conservation_error = (S + E + I + Q + R + M) - N;
st.case_identity_error = (I + Q + R + M) - C;
end

% -------------------------------------------------------------------------
function v = pick_new(adj, raw, series, idx)
if isfinite(adj)
    v = adj;
elseif isfinite(raw)
    v = raw;
elseif idx > 1
    v = series(idx) - series(idx - 1);
else
    v = 0;
end
end

function v = fixed_value(s, name, idx)
v = NaN;
if isfield(s, name)
    v = s.(name)(idx);
end
end

function v = get_cfg(data, name, default)
v = default;
if isfield(data, 'cfg') && isfield(data.cfg, name) && ~isempty(data.cfg.(name))
    v = data.cfg.(name);
end
end

function s = set_default(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
