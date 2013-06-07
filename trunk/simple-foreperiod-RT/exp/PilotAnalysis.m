clear all
load('pilot-data/resp-njs-full-1.mat')

close all
figure
go_onsets = [results.go_onset];
foreperiod_onsets = [results.foreperiodonset];
actual_delays = [go_onsets.stimon] - [foreperiod_onsets.stimon];
intended_delays = [results.targdelay];
regular_trial = strcmp({results.trialType}, 'regular');
good = ([results.isPractice] == 0) .* ([results.jumped_gun] == 0);
%hist(actual_delays - intended_delays, 0:0.0167:0.06)
hold all
plot(actual_delays(find(good .* regular_trial)), [results(find(good .* regular_trial)).resp_latency], 'b.')
plot(actual_delays(find(good .* ~regular_trial)), [results(find(good .* ~regular_trial)).resp_latency], 'r.')
plot([0, 1.3], [params.cutoffTime, params.cutoffTime], 'k:');

%figure
%hist(actual_delays)
%hold on
%plot([-10 10], [-10 10])

bin_width = 0.100;
bin_mins = 0:bin_width:(max(actual_delays) + bin_width);
for i = 1:length(bin_mins)
    bin_min = bin_mins(i);
    idx = find((actual_delays > bin_min) .* (actual_delays < bin_min + bin_width) .* regular_trial .* good);
    meanRT_regular(i) = mean([results(idx).resp_latency]);
    idx = find((actual_delays > bin_min) .* (actual_delays < bin_min + bin_width) .* ~regular_trial .* good);
    meanRT_bonus(i) = mean([results(idx).resp_latency]);
end
plot(bin_mins + bin_width / 2, meanRT_regular, 'b-', 'linewidth', 2)
plot(bin_mins + bin_width / 2, meanRT_bonus, 'r-', 'linewidth', 2)

axis([0.3, 1.2, 0.15, 0.30]);