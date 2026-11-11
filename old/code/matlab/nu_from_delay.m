function nu = nu_from_delay(delayDays)
%NU_FROM_DELAY  Convert mean safe-burial delay (days) to a weekly rate.
if delayDays <= 0
    error('delay must be positive');
end
nu = 7 / delayDays;
end
