function R = fetch_response_page(url, asOf)
%FETCH_RESPONSE_PAGE  Extract the six headline response indicators.
%
%   R = fetch_response_page()
%   R = fetch_response_page(url, asOf)
%
%   The ebola-tracker data page publishes six headline response numbers with
%   stable CSS classes (is-alerts, is-labo, is-contacts, is-cte, is-vaccin,
%   is-poe). They are not all present in the raw CSV database, so they are
%   scraped here and written into response_latest_<tag>.csv.
%
%   Returns a table with columns metric, value, unit, period, as_of, source.
%   Individual metrics are NaN if the page changes; callers should fall back.

if nargin < 1 || isempty(url)
    url = 'https://ebola-tracker.org/en/data/';
end
if nargin < 2 || isempty(asOf)
    asOf = char(datetime('now', 'Format', 'yyyyMMdd'));
end

html = webread(url, weboptions('Timeout', 60, 'ContentType', 'text'));
if isstring(html)
    html = char(html);
end

keys = ["is-alerts", "is-labo", "is-contacts", "is-cte", ...
    "is-vaccin", "is-poe"];
value = nan(numel(keys), 1);
for k = 1:numel(keys)
    pat = ['class="rc-n ' char(keys(k)) '"[^>]*>([0-9.,]+)'];
    tok = regexp(html, pat, 'tokens', 'once');
    if ~isempty(tok)
        value(k) = str2double(erase(tok{1}, ','));
    end
end

if all(isnan(value))
    error('fetch_response_page:parseFailed', ...
        'No headline indicator could be parsed from %s', url);
end

if ischar(asOf) && numel(asOf) == 8
    asOfDate = string(datetime(asOf, 'InputFormat', 'yyyyMMdd'), 'yyyy-MM-dd');
else
    asOfDate = string(asOf);
end

metric = ["alerts_received"; "test_positivity"; "contacts_seen"; ...
    "patients_per_100_beds"; "vaccinated_total"; "travellers_screened"];
unit = ["alerts"; "%"; "%"; "patients/100 beds"; "people"; "people"];
period = ["last 7 bulletins"; "last 7 bulletins"; "last 7 bulletins"; ...
    "latest"; "cumulative"; "last bulletin"];
as_of = repmat(asOfDate, numel(metric), 1);
source = repmat("data page", numel(metric), 1);

R = table(metric, value, unit, period, as_of, source, ...
    'VariableNames', {'metric', 'value', 'unit', 'period', 'as_of', 'source'});
end
