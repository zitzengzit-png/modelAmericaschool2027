function [y, st] = state_at_day(data, when, opts)
%STATE_AT_DAY  Reconstruct the SEIQRD state on a calendar day.
%
%   [y, st] = state_at_day(data, when)
%   [y, st] = state_at_day(data, when, opts)
%
%   when: datetime, 'yyyy-MM-dd' string, or 0-based day index t_day.
%
%   opts.qSource          'auto' (default) | 'etc' | 'ratio'
%   opts.isolationRatio   fallback Q/(C-M-R), default from data.cfg or 0.40
%   opts.burialDelayDays  default from data.cfg or 2.0
%   opts.sigma            day^-1, default from data.cfg or 0.10
%
%   Rules (all per day)
%     C, M  daily cumulative confirmed cases and deaths
%     R     cumulative recoveries; last valid value carried forward
%     Q     etc_admitted when available, otherwise isolationRatio*(C-M-R)
%     I     max(C - M - Q - R, 0)      so that I+Q+R+M = C exactly
%     E     daily new cases (7-day mean preferred) / sigma
%     D     burialDelayDays * daily deaths (deaths/day * days = persons)
%     S     N - E - I - Q - R - M

if nargin < 3 || isempty(opts)
    opts = struct();
end
opts = set_default(opts, 'qSource', 'auto');
opts = set_default(opts, 'isolationRatio', get_cfg(data, 'isolationRatio', 0.40));
opts = set_default(opts, 'burialDelayDays', get_cfg(data, 'burialDelayDays', 2.0));
opts = set_default(opts, 'sigma', get_cfg(data, 'sigma', 0.10));

if ~isfield(data, 'daily') || ~isfield(data.daily, 'date')
    error('state_at_day:noDaily', ...
        'data.daily is missing; rebuild it with load_data().');
end
d = data.daily;

% Resolve the day index.
if isdatetime(when)
    date = dateshift(when, 'start', 'day');
    idx = find(d.date == date, 1);
elseif isstring(when) || ischar(when)
    date = datetime(string(when), 'InputFormat', 'yyyy-MM-dd');
    idx = find(d.date == date, 1);
elseif isnumeric(when) && isscalar(when)
    idx = double(when) + 1;
    if idx < 1 || idx > numel(d.date)
        error('state_at_day:badIndex', ...
            't_day %.0f is outside 0..%d.', when, numel(d.date) - 1);
    end
    date = d.date(idx);
else
    error('state_at_day:badWhen', ...
        'when must be a datetime, yyyy-MM-dd string or t_day index.');
end
if isempty(idx)
    error('state_at_day:dateNotFound', ...
        'Date %s is not in the daily series %s..%s.', ...
        string(date, 'yyyy-MM-dd'), ...
        string(d.date(1), 'yyyy-MM-dd'), string(d.date(end), 'yyyy-MM-dd'));
end

N = data.N;
C = d.cases(idx);
M = d.deaths(idx);

% Recoveries: carry the last valid value forward.
R = d.recovered(idx);
rSource = "observed";
if ~isfinite(R)
    prior = d.recovered(1:idx);
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
qEtc = d.etcAdmitted(idx);
switch lower(string(opts.qSource))
    case "etc"
        if ~isfinite(qEtc)
            error('state_at_day:noEtc', ...
                'etc_admitted is missing on %s; use qSource=''ratio''.', ...
                string(date, 'yyyy-MM-dd'));
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
        error('state_at_day:badQSource', ...
            'qSource must be auto, etc or ratio (got %s).', opts.qSource);
end
Q = min(max(Q, 0), active);

% Remaining states.
I = max(C - M - Q - R, 0);
newC = d.newCases7d(idx);
eSource = "reconstructed_7d";
if ~isfinite(newC)
    newC = d.newCases(idx);
    eSource = "reconstructed_raw";
end
if ~isfinite(newC) && idx > 1
    newC = C - d.cases(idx - 1);
    eSource = "reconstructed_diff";
end
if ~isfinite(newC)
    newC = 0;
    eSource = "assumed_zero";
end

newD = d.newDeaths7d(idx);
dSource = "reconstructed_7d";
if ~isfinite(newD)
    newD = d.newDeaths(idx);
    dSource = "reconstructed_raw";
end
if ~isfinite(newD) && idx > 1
    newD = M - d.deaths(idx - 1);
    dSource = "reconstructed_diff";
end
if ~isfinite(newD)
    newD = 0;
    dSource = "assumed_zero";
end
newC = max(newC, 0);
newD = max(newD, 0);

E = newC / opts.sigma;
D = opts.burialDelayDays * newD;
S = N - E - I - Q - R - M;

y = [S; E; I; Q; R; D; M];

% Consistency checks.
if S <= 0
    error('state_at_day:negativeS', ...
        'Reconstructed S is %.1f on %s; check N and the initial stocks.', ...
        S, string(date, 'yyyy-MM-dd'));
end
tol = 1e-9 * max(N, 1);
if abs((I + Q + R + M) - C) > max(tol, 1e-6)
    error('state_at_day:caseIdentity', ...
        'I+Q+R+M does not equal C on %s.', string(date, 'yyyy-MM-dd'));
end
if abs((S + E + I + Q + R + M) - N) > max(tol, 1e-6)
    error('state_at_day:conservation', ...
        'S+E+I+Q+R+M does not equal N on %s.', string(date, 'yyyy-MM-dd'));
end

st = struct();
st.date = date;
st.t_day = d.t(idx);
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
st.flags = d.flags(idx);
end

% -------------------------------------------------------------------------
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
