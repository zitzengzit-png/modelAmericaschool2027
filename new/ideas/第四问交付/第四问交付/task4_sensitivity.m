function task4_sensitivity
% Nine declared mobility scenarios; preserve shared Q2 parameters.
    root = fileparts(mfilename('fullpath'));
    cleanup = onCleanup(@clearSettings); %#ok<NASGU>
    allResults = table;
    for share = [0.005,0.015,0.03]
        for decay = [1,1.5,2]
            setappdata(0,'task4_flow',[share,decay]);
            runStrategy(root);
            result = getappdata(0,'task4_result');
            result.StayShare = repmat(share,height(result),1);
            result.DistanceDecay = repmat(decay,height(result),1);
            reference = result.WindowOnsets(1);
            result.WindowOnsetChangePct = 100*(result.WindowOnsets/reference-1);
            allResults = [allResults;result]; %#ok<AGROW>
        end
    end
    folder = fullfile(root,'output','task4');
    if ~exist(folder,'dir'), mkdir(folder); end
    writetable(allResults,fullfile(folder,'sensitivity.csv'));
    for name = unique(allResults.Scenario,'stable').'
        selected = allResults(strcmp(allResults.Scenario,name{1}),:);
        fprintf('%s: change %.2f to %.2f percent; Rnet %.4f to %.4f\n', ...
            name{1},min(selected.WindowOnsetChangePct),max(selected.WindowOnsetChangePct), ...
            min(selected.Rnet),max(selected.Rnet));
    end
end

function runStrategy(root)
    run(fullfile(root,'task4_strategies.m'));
end

function clearSettings
    if isappdata(0,'task4_flow'), rmappdata(0,'task4_flow'); end
    if isappdata(0,'task4_result'), rmappdata(0,'task4_result'); end
end
