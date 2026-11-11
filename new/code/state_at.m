function [y, st] = state_at(data, when, opts)
%STATE_AT  Reconstruct the SEIQRD state at a date (daily) or ISO week (legacy).
%
%   [y, st] = state_at(data, when)
%   [y, st] = state_at(data, when, opts)
%
%   New standard: when is a datetime, a 'yyyy-MM-dd' string, or a 0-based
%   day index (t_day) into data.daily.
%
%   Legacy: if data.daily is absent (legacy workbook branch), when is an ISO
%   week number and the weekly reconstruction in state_at_week is used.

if nargin < 3 || isempty(opts)
    opts = struct();
end

if isfield(data, 'daily') && isfield(data.daily, 'date') && ...
        ~isempty(data.daily.date)
    [y, st] = state_at_day(data, when, opts);
else
    [y, st] = state_at_week(data, when, opts);
end
end
