function T = q4_strategies(D, p, P, y0)
%Q4_STRATEGIES  Compare travel restriction, coordination, ring vaccination.
%
%   T = q4_strategies(D, p, P, y0)
%   y0 is the 10/25 state; simulation window is 10/25..11/09 (15 days).

nP = D.nP;
tspan = 126:141;
base = run_one(D, p, P, y0, tspan);
rows = {table("baseline", base.cases, base.deaths, base.Rnet, ...
    base.maxQ, base.maxI, "no intervention", ...
    'VariableNames', {'scenario', 'cases15', 'deaths15', 'Rnet', ...
    'maxQ', 'maxI', 'notes'})};

% Travel restriction: reduce off-diagonal stay shares, keep columns sum 1.
for theta = [0.5 0.9]
    P2 = P;
    off = ~eye(nP);
    P2(off) = P(off) * (1 - theta);
    for j = 1:nP
        P2(j,j) = 1 - sum(P2(:,j)) + P2(j,j);
    end
    r = run_one(D, p, P2, y0, tspan);
    rows{end+1} = table("travel_" + string(theta), r.cases, ...
        r.deaths, r.Rnet, r.maxQ, r.maxI, ...
        "off-diagonal P x (1-theta)", ...
        'VariableNames', {'scenario', 'cases15', 'deaths15', 'Rnet', ...
        'maxQ', 'maxI', 'notes'}); %#ok<AGROW>
end

% Regional coordination: 15% local transmission reduction + 10% alpha.
p2 = p;
p2.betaMult = 0.85 * p.betaMult;
p2.alpha = 1.10 * p.alpha;
r = run_one(D, p2, P, y0, tspan);
rows{end+1} = table("coordination", r.cases, r.deaths, r.Rnet, ...
    r.maxQ, r.maxI, "beta_mult x0.85, alpha x1.10", ...
    'VariableNames', {'scenario', 'cases15', 'deaths15', 'Rnet', ...
    'maxQ', 'maxI', 'notes'});

% Ring vaccination approximation: target provinces with C10 >= 50.
target = find(D.C10 >= 50);
p3 = p;
p3.betaMult(target) = p3.betaMult(target) * (1 - 0.56);
r = run_one(D, p3, P, y0, tspan);
rows{end+1} = table("ring_vaccine", r.cases, r.deaths, r.Rnet, ...
    r.maxQ, r.maxI, "target C10>=50, efficacy 0.7 x coverage 0.8", ...
    'VariableNames', {'scenario', 'cases15', 'deaths15', 'Rnet', ...
    'maxQ', 'maxI', 'notes'});

% Combination.
P2 = P;
off = ~eye(nP);
P2(off) = P(off) * 0.5;
for j = 1:nP
    P2(j,j) = 1 - sum(P2(:,j)) + P2(j,j);
end
p4 = p;
p4.betaMult(target) = p4.betaMult(target) * (1 - 0.56);
p4.betaMult = 0.85 * p4.betaMult;
p4.alpha = 1.10 * p4.alpha;
r = run_one(D, p4, P2, y0, tspan);
rows{end+1} = table("combination", r.cases, r.deaths, r.Rnet, ...
    r.maxQ, r.maxI, "travel 50% + coordination + ring", ...
    'VariableNames', {'scenario', 'cases15', 'deaths15', 'Rnet', ...
    'maxQ', 'maxI', 'notes'});

T = vertcat(rows{:});
end

function r = run_one(D, p, P, y0, tspan)
out = q4_simulate(D, p, P, y0, tspan);
C = out.C;
M = out.M;
r = struct();
r.cases = sum(C(end,:) - C(1,:));
r.deaths = sum(M(end,:) - M(1,:));
r.maxQ = max(max(out.Q));
r.maxI = max(max(out.I));
[~, ~, ~] = deal(0);
r.Rnet = q4_rnet(D, p, P, out.S(end,:), tspan(end));
end
