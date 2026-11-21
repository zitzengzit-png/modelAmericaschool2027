function S = task3_scenarios()
%TASK3_SCENARIOS  Fourteen main scenarios from 第三问建模.md section 4.5.
%
%   Fields are logical switches; qTarget is the follow-up coverage used by
%   contact tracing and by PEP (0.78 baseline, 0.90 main scenario).

S = mk('B0',  'baseline',                          0,0,0,0,0,0,0,0,0, 0.78);
S(end+1) = mk('S1',  'isolation only',             1,0,0,0,0,0,0,0,0, 0.78);
S(end+1) = mk('S2',  'contact tracing 90%',        0,1,0,0,0,0,0,0,0, 0.90);
S(end+1) = mk('S3',  'safe burial only',           0,0,1,0,0,0,0,0,0, 0.78);
S(end+1) = mk('S4',  'hospital IPC only',          0,0,0,1,0,0,0,0,0, 0.78);
S(end+1) = mk('S5',  'vaccination only',           0,0,0,0,1,0,0,0,0, 0.78);
S(end+1) = mk('S6a', 'MBP134 only',                0,0,0,0,0,1,0,0,0, 0.78);
S(end+1) = mk('S6b', 'remdesivir only',            0,0,0,0,0,0,1,0,0, 0.78);
S(end+1) = mk('S7',  'obeldesivir PEP only',       0,0,0,0,0,0,0,1,0, 0.78);
S(end+1) = mk('S8',  'community education only',   0,0,0,0,0,0,0,0,1, 0.78);
S(end+1) = mk('A',   'A: 1+2+3+8',                 1,1,1,0,0,0,0,0,1, 0.90);
S(end+1) = mk('B',   'B: 1+4+MBP134',              1,0,0,1,0,1,0,0,0, 0.78);
S(end+1) = mk('C',   'C: 2+5+7+8',                 0,1,0,0,1,0,0,1,1, 0.90);
S(end+1) = mk('D',   'D: all eight (MBP134)',      1,1,1,1,1,1,0,1,1, 0.90);
end

% -------------------------------------------------------------------------
function s = mk(id, label, iso, ct, burial, hic, vax, mbp, rdv, pep, ce, q)
s = struct('id', string(id), 'label', string(label), ...
    'iso', logical(iso), 'ct', logical(ct), 'burial', logical(burial), ...
    'hic', logical(hic), 'vax', logical(vax), 'mbp', logical(mbp), ...
    'rdv', logical(rdv), 'pep', logical(pep), 'ce', logical(ce), ...
    'qTarget', q);
end
