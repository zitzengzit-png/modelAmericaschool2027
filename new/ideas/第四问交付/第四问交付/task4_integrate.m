function [t,Y] = task4_integrate(fun, span, initial, p, options)
% Restart at known parameter jumps and evaluate at daily times.
    stops = unique([span(1), p.t1, p.t2, span(end)]);
    stops = stops(stops >= span(1) & stops <= span(end));
    t = []; Y = [];
    state = initial;
    for k = 1:numel(stops)-1
        left = stops(k); right = stops(k+1);
        grid = unique([left, ceil(left):floor(right), right]);
        segment = @(tt,yy) fun(min(tt,right-eps(right)),yy);
        [ts,ys] = ode45(segment,grid,state,options);
        if k > 1
            ts = ts(2:end); ys = ys(2:end,:);
        end
        t = [t; ts]; Y = [Y; ys]; %#ok<AGROW>
        state = ys(end,:).';
    end
end
