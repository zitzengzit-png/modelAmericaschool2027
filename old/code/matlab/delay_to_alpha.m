function a = delay_to_alpha(delayDays)
%DELAY_TO_ALPHA  Convert mean admission delay (days) to a weekly rate.
if delayDays <= 0
    error('delay must be positive');
end
a = 7 / delayDays;
end
