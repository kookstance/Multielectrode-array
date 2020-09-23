%% Notes
% 1. This code requires sorted spike data from Plexon saved in an excel
% format delineated as: 'SpikeTimes', 'Unit no.', 'channels. no.'; in that order. 

% 2. It will generate a new array named 'raw_units' with each unit's firing
% activity listed as a single Nx3 array where N is the no. of events. The
% rasters are created from just the first column of each unit's array (e.g.
% the spike times).


%% Import raw spike sorted data from Plexon 

clear;
close all;

[FileName, FilePath] = uigetfile( ...
       {'*.xlsx','New Excel (*.xlsx)'; ...
       '*.xls','Old Excel (*.xls)';
       '*.txt', 'Text file (*.txt)'}, ...
        'Pick a file', ...
        'MultiSelect', 'on');
File = fullfile(FilePath, FileName);
[num, txt, raw] = xlsread(File);

% clearvars txt File

%% Display file name / experiment details

fprintf('%s \n\n', FileName);


%% dimensions
% figure dimensions, in inches

x_width = 6;                                                               
y_width = 3;

% plot dimensions
time_window = 100;                                                       % this is the time window that is shown in the plot; specify in seconds; it does not affect the PI analysis


%% format duration of recording 
% if the analysis requires only a certain portion of the recording, use
% this module to determine the timeframe to analyze 

Duration = 0;                                                            % specify if analysis is to be performed on a specific time duration of the recording

spike_start = 10;                                                        % in seconds
spike_end = 115;                                                         % in seconds

if Duration > 0 || Duration < 0
    num = num(num(:,1)>=spike_start & num(:,1)<=spike_end, :);
    raw = cellfun(@(z) z(z(:,1)>=spike_start & z(:,1)<=spike_end, :), raw, 'UniformOutput', false);
    
    fprintf('Record analyzed from %d to %ds \n\n', spike_start, spike_end);
end

if Duration == 0
    fprintf('Full record analyzed \n\n');
end


%% Acquire timestamps of light intervals from trigger times
% 1. MC_Rack continuously records the trigger input via a negative (-1) bias voltage every 3 ms
% 2. If a +1V trigger signal is sent via TTL, the bias reaches 0 (or "null") and no time is recorded during this triggering period
% 3. If Trigger = 1, then trigger filename must exactly match the .xlsx spike sorted data.


Trigger = 1;                                                            % trigger times = 1, other wise = 0

if Trigger > 0           

    trigFile = strrep(File, '.xlsx', '.txt');                           % imports the corresponding .txt trigger file
    fidTrig = fopen(trigFile);
    
    delimiter = '\t';
    formatSpec = '%*s%s%[^\n\r]';
    trig_timesArray = textscan(fidTrig, ...                             % opens .txt trigger file (from MC_Rack data tool) and parses raw text file
        formatSpec, 'Delimiter', delimiter, ...                         % into a 1x2 array with 1st cell being 3 ms trigger record
        'TextType', 'string',  'ReturnOnError', false);                 % and 2nd cell being the bias voltage (-1 or null)

    fclose(fidTrig);

    trig_timesRaw = trig_timesArray{1,1}(:,1);                          % creates new numerical array with only the 3 ms trigger record
    trig_timesRaw(1:4,:) = []; 
    trig_timesRaw = double(trig_timesRaw);
    
    if Duration > 0 || Duration < 0                                     % if looking at a specific time window of the recording
        trig_timesRaw = trig_timesRaw(trig_timesRaw(:,1)>=(spike_start*1000) & trig_timesRaw(:,1)<=(spike_end*1000), :);
    end
    
    if Duration < 1
        record_time = max(trig_timesRaw)/1000;                          % returns the total time of the recording in seconds
    end
    
    if Duration > 0 || Duration < 0
        record_time = spike_end - spike_start;
    end
        
    clearvars ans delimiter fidTrig formatSpec trig_timesArray
    
    parsed_trigTimes = [];

    for i = 1:length(trig_timesRaw)-1                                   % creates an array with the trigger times before and after the 1V TTL signal
        diff_trig = trig_timesRaw(i + 1) - trig_timesRaw(i);
        if diff_trig > 4
            parsed_trigTimes = [parsed_trigTimes; trig_timesRaw(i); trig_timesRaw(i + 1)];
        end
    end
    
    parsed_trigTimes = parsed_trigTimes/1000;
    
    interv_times = [parsed_trigTimes(1:2:end,:), parsed_trigTimes(2:2:end,:)];         % splits numTime array into two columns - column 1 for light on and column 2 for light off
    interv_duration = diff(interv_times, 1, 2);                         % returns the total length of each light stim interval, in seconds
    interv_duration = interv_duration.';
    lighton_time = sum(interv_duration);                                % returns the total time that the light stim was on, in seconds
    dark_time = record_time - lighton_time;                             % length of time, in seconds, without light stimulus
else
end

clearvars diff_trig

if Trigger < 0
    [TrigFileName, TrigFilePath] = uigetfile( ...
        {'*.xlsx', 'New Excel (*.xlsx)'; ...
        '*.xls', 'Old Excel (*.xls)'}, ...
        'Pick a file', ...
        'Multiselect', 'on');
    trigFile = fullfile(TrigFilePath, TrigFileName);
    [trig_times] = xlsread(trigFile);
    
    record_time = max(num(:,1));
    
    if Duration > 0 || Duration < 0
        % raw_units = cellfun(@(z) z(z(:,1)>=spike_start & z(:,1)<=spike_end, :), raw_units, 'UniformOutput', false);
    end

    interv_times = [trig_times(1:2:end,:), trig_times(2:2:end,:)];
    
    interv_duration = diff(interv_times, 1, 2);
    interv_duration = interv_duration.';
    lighton_time = sum(interv_duration);
    dark_time = record_time - lighton_time;
else
end


%% Raw histogram of all recorded spikes (figure 1)

Histoplot = 1;                                                          % set 0 (no histogram) or 1 (histogram)

BW = 0.1;                                                               % set bins (bin width, BW) here (in seconds) 

fprintf('Bin size = %d ms \n', BW * 1000)
spike_timeHist = cell2mat(raw(:,1));
[N, EDGES] = histcounts(spike_timeHist, 'BinWidth', BW);                % N is the counts for each bin; EDGES are the bin edges

hold on;
if Histoplot > 0
    histogram_plot = figure(1);
    HistoSpikes = histogram(spike_timeHist, 'BinWidth', BW);
    xlabel('Time (s)');
    ylabel('Number of spikes');
else 
    fprintf('No histogram plotted\n\n');
end
hold off


%% split raw spikes into corresponding channel

[~,~,channels] = unique(num(:,3));                                      % first separate raw num array based on electrode ch from MEA chip
raw_channels = accumarray(channels, 1:size(num,1),[],@(r){num(r,:)});   % generate a cell w/ subcells that contain each channel's unit firing


%% split channels into units (waveforms)

raw_units = [];
ntrials = [];
spike_times = [];

for i = 1:numel(raw_channels)
    [~,~,units] = unique(raw_channels{i,1}(:,2));                       % generate raw_channels array based on unit number from each ch
    raw_units = [raw_units; ...
        accumarray(units, ...
        1:size(raw_channels{i,1}(:,2),1),[],@(r){raw_channels{i,1}(r,:)})];             % generate a cell array with subcells that has each unit's activity
end


%% crop spike data in time
% 
% if Duration > 0 || Duration < 0
%     raw_units = cellfun(@(z) z(z(:,1)>=spike_start & z(:,1)<=spike_end, :), raw_units, 'UniformOutput', false);
% end
%     

%% Raster trains of spike data from all units (figure 2)

Sort = 1;                                                               % if 1 = sort, if 0 = raw unit # without sorting

unit_raster = figure(2);

hold on;

if Sort < 1
    for m = 1:length(raw_units)
        spike_times = raw_units{m}(:,1);
        ntrials = ones(size(spike_times,1),1) * m;
        plot(spike_times, ntrials, 'Marker', '.', 'Color', 'k', 'LineStyle', 'none')
    end
else
end

if Sort > 0
    [~,sorted_units] = sort(cellfun(@length,raw_units), 'descend');
    raw_units = raw_units(sorted_units);
    for m = 1:length(raw_units)
        spike_times = raw_units{m}(:,1);
        ntrials = ones(size(spike_times,1),1) * m;
        plot(spike_times, ntrials, 'Marker', '.', 'Color', 'k', 'LineStyle', 'none')
    end
else
end

xlim([0 time_window]);                                                  % set range of x-axis, in seconds
ylim([0 size(raw_units,1) + 1]);
xlabel('Time (s)');
ylabel('Unit');

set(unit_raster, 'units', 'inches');
set(unit_raster, 'position', [0 0 x_width y_width]);

hold off

fprintf('Number of channels = %d \n', i);
fprintf('Number of units = %d \n\n', m);


%% Calculate firing frequencies and PI per unit (figure 3)

if Trigger > 0 || Trigger < 0
    raw_unitsTime = cell(numel(raw_units), 1);

    for m = 1:length(raw_units)
        unit_time = raw_units{m,1}(:,1);
        raw_unitsTime{m} = unit_time;
    end

    spikes_light = cell(numel(raw_units), 1);
    spikes_on = [];
    
    freq_light = cell(numel(raw_units), 1);
    freq_on = [];
    
    unitfreq_light = cell(numel(raw_units), 1);
    spikes_dark = cell(numel(raw_units), 1);
    unitfreq_dark = cell(numel(raw_units), 1);
    
    for m = 1:length(raw_units)
        for r = 1:length(interv_times)
            spikes_on(r) = numel(raw_unitsTime{m}(raw_unitsTime{m}(:,1) >= interv_times(r,1) & raw_unitsTime{m}(:,1) <= interv_times(r,2)));
            % spikes_on = spikes_on.';
            
            spikes_light{m} = spikes_on;                                % calculates number of spikes that occur in each light-on interval for a particular unit
        end
    end
    
    for m = 1:length(raw_units)
        for r = 1:length(interv_times)
            freq_on(r) = (spikes_light{m}(1,r) / interv_duration(1,r));
            % freq_on = freq_on.';
            
            freq_light{m} = freq_on;                                    % calculates the firing frequency of each unit in each of the light-on intervals
        end
        
        
        spikes_dark{m} = numel(raw_unitsTime{m}(raw_unitsTime{m}(:,1) >=0)) - sum(spikes_light{m});
        unitfreq_dark{m} = spikes_dark{m} / dark_time;                  % calculates the average unit firing frequency in without light stimulus
    end
    
    unitfreq_dark = cell2mat(unitfreq_dark);
    unitfreq_light = cellfun(@mean, freq_light);
    
    avgfreq_dark = mean(unitfreq_dark);
    stdfreq_dark = std(unitfreq_dark);
    avgfreq_light = mean(unitfreq_light);
    stdfreq_light = std(unitfreq_light);
    
    for m = 1:length(raw_units)
        unit_PI(m) = (unitfreq_light(m) - unitfreq_dark(m)) / (unitfreq_light(m) + unitfreq_dark(m));
    end
    
    unit_PI = unit_PI.';
    
    avg_unitPI = mean(unit_PI);
    std_unitPI = std(unit_PI);
    
    PI_histo = figure(3);
    hold on;
    
    BW2 = 0.05;                                                         % bin width for histogram of PI values; is not the binwidth for spiking frequency BW
    unitPI_histoplot = histogram(unit_PI, 'BinWidth', BW2);
    xlim([-1 1]);
    xlabel('Photoswitch index, PI');
    ylabel('No. events');
    xl = xline (0, ':', 'LineWidth', 1.5);
    
    hold off;
    
    [N_histPI, edge_histPI] = histcounts(unit_PI, 'BinWidth', BW2);
    bin_centersPI = edge_histPI(1:end-1) + diff(edge_histPI)/2;
    
    PI_histcount = [bin_centersPI.', N_histPI.'];
    
    fprintf('Average firing frequency in darkness = %.2f +/- %.2f Hz \n', avgfreq_dark, stdfreq_dark);
    fprintf('Average firing frequency in light = %.2f +/- %.2f Hz \n\n', avgfreq_light, stdfreq_light);
    fprintf('PI histogram binsize = %.3f \n', BW2);
    fprintf('Average photoswitch index, P.I. = %.3f +/- %.3f \n\n', avg_unitPI, std_unitPI);
    
end

    
%% Calculating firing frequencies and PI per recording (not per unit)

avg_firing = (N(1,:) / BW) / numel(raw_units);                          % [no. events / bin size (s) = frequency] / no. units = average firing frequency per unit
bin_centers = EDGES(1:end-1) + diff(EDGES)/2;


%% Create frequency raster (figure 4)

freq_raster = figure(4);

FreqPlot = bar(bin_centers, avg_firing, 'FaceColor', 'k', 'BarWidth', 1.5);
hold on;

xlim([0 time_window]);                                                  % set range of x-axis, in seconds
ylim([0 15]);

if Trigger > 0 || Trigger < 0
    for r = 1:length(interv_times)                                      % creates a shaded region for the light intervals
        stim_limits = interv_times(r,:);
        light_stim = [min(stim_limits) max(stim_limits) max(stim_limits) min(stim_limits)];
        patch(light_stim, [0 0 max(ylim)*[1 1]], [0.3010 0.7450 0.9330], 'LineStyle', 'none');
        hold on
    end

    FreqPlot = bar(bin_centers, avg_firing, 'FaceColor', 'k', 'BarWidth', 1.5);
    hold on
else
end

xlabel('Time (s)');
ylabel('Average firing frequency per unit (Hz)');

set(freq_raster, 'units', 'inches');
set(freq_raster, 'position', [0 0 x_width 1.5]);                        % use preset values above, or set own limits in inches

% print(freq_raster, 'freq_raster.png', '-dpng', '-r300');  

hold off


%% Light response index (LRI) (figure 5)

if Trigger > 0 || Trigger < 0
    unit_LRI = abs(unit_PI);
    
    LRI_histo = figure(5);
    
    hold on;
    
    BW3 = 0.05;                                                         % bin width for LRI histograms, not binwidth for PI histo or binwidth for spiking frequencies

    unitPI_histoplot = histogram(unit_LRI, 'BinWidth', BW3);
    xlim([0 1]);
    xlabel('Light response index, LRI');
    ylabel('No. events');
    % xl2 = xline (0, ':', 'LineWidth', 1.5);
    
    hold off;
    
    [N_histLRI, edge_histLRI] = histcounts(unit_LRI, 'BinWidth', BW3);
    bin_centersLRI = edge_histLRI(1:end-1) + diff(edge_histLRI)/2;
    
    LRI_histcount = [bin_centersLRI.', N_histLRI.'];
    
else
end


%% Subplot figure (figure 6)
figure(6);

ax(1) = subplot(2,1,1);

if Sort < 1
    for m = 1:length(raw_units)
        hold on;
        spike_times = raw_units{m}(:,1);
        ntrials = ones(size(spike_times,1),1) * m;
        plot(spike_times, ntrials, 'Marker', '.', 'Color', 'k', 'LineStyle', 'none')
    end
    hold off;
else
end

if Sort > 0
    [~,sorted_units] = sort(cellfun(@length,raw_units), 'descend');
    raw_units = raw_units(sorted_units);
    for m = 1:length(raw_units)
        hold on;
        spike_times = raw_units{m}(:,1);
        ntrials = ones(size(spike_times,1),1) * m;
        plot(spike_times, ntrials, 'Marker', '.', 'Color', 'k', 'LineStyle', 'none')
    end
    hold off;
else
end

ylim([0 size(raw_units,1) + 1]);
ylabel('Unit');
set(ax(1), 'YTickLabel', [], 'XTickLabel', []);
set(ax(1), 'Visible', 'off');

hold off;

ax(2) = subplot(2,1,2);

FreqPlot = bar(bin_centers, avg_firing, 'FaceColor', 'k', 'BarWidth', 1.5);
hold on;

if Trigger > 0 || Trigger < 0
    for r = 1:length(interv_times)                                         
        stim_limits = interv_times(r,:);
        light_stim = [min(stim_limits) max(stim_limits) max(stim_limits) min(stim_limits)];
        patch(light_stim, [0 0 max(ylim)*[1 1]], [0.3010 0.7450 0.9330], 'LineStyle', 'none');
        hold on
    end

    FreqPlot = bar(bin_centers, avg_firing, 'FaceColor', 'k', 'BarWidth', 1.5);
    hold on
else
end

xlabel('Time (s)');
ylabel('Average firing frequency per unit (Hz)');

set(ax(2), 'TickDir', 'out');
set(ax(2), 'box', 'off');

hold off

linkaxes(ax,'x');                                                       % links the two x-axes 


%% find peak spike activity in light intervals
% determine the maximum firing frequency in each light interval and take
% the average

% if Trigger > 0 || Trigger < 0 
%     for m = 1:length(raw_units)
%         for r = 1:length(interv_times)
%             spikes_on(r) = numel(raw_unitsTime{m}(raw_unitsTime{m}(:,1) >= interv_times(r,1) & raw_unitsTime{m}(:,1) <= interv_times(r,2)));
%             % spikes_on = spikes_on.';
%             
%             spikes_light{m} = spikes_on;                                % calculates number of spikes that occur in each light-on interval for a particular unit
%         end
%     end
% end

%% Photoswitch index (e.g. relative change in RGC firing in dark v. in light)
% Calculates average firing frequencies in darkness & in light, and the
% average PI from these two values. To do so the code first calculates 1.
% the total frequency (sum) of light responses and 2. the total
% number of these events. The average light freq is the ratio of these two
% values (sum of lighton_timesSum / total no. light events). 
% The dark frequency is calculated by taking the total frequency of the
% entire recording and subtracting the total frequency of the light
% responses. The total number of dark events is calulated the same way.
% 
% if Trigger > 0
%     lighton_timesSum = [];
%     lighton_events = [];
% 
%     for r = 1:length(interv_times(:,1))
%         lighton_timesSum = [lighton_timesSum; sum(avg_firing(bin_centers.' >= interv_times(r,1) & bin_centers.' <= interv_times(r,2)))];
%         lighton_events = [lighton_events; numel(avg_firing(bin_centers.' >= interv_times(r,1) & bin_centers.' <= interv_times(r,2)))];
%     end
% 
%     lightoff_timesSum = (sum(avg_firing(bin_centers.' >= 0)) - sum(lighton_timesSum));
%     lightoff_events = (numel(avg_firing(bin_centers.' >= 0)) - sum(lighton_events));
% 
%     avg_darkfireFreq = lightoff_timesSum/lightoff_events;
%     avg_lightfireFreq = sum(lighton_timesSum)/sum(lighton_events);
%     avg_PI = ((avg_lightfireFreq - avg_darkfireFreq) / (avg_lightfireFreq + avg_darkfireFreq));
%     
%     disp('The following values come from the binning the histogram data:');
%     fprintf('Average firing frequency in darkness = %.2f Hz \n', avg_darkfireFreq);
%     fprintf('Average firing frequency in light = %.2f Hz \n', avg_lightfireFreq);
%     fprintf('Average photoswitch index, P.I. = %.3f \n', avg_PI);
% else
% end


%% Calculate dark firing
% If there is no trigger, this sequence calculates the total firing
% frequency without light stimulus ("dark firing").

% if Trigger < 1 & Trigger > -1
%     lightoff_timesSum = sum(avg_firing(bin_centers.' >= 0));
%     lightoff_events = numel(avg_firing(bin_centers.' >= 0));
%     
%     avg_darkfireFreq = lightoff_timesSum/lightoff_events;
%     fprintf('Average firing frequency in darkness = %.2f Hz \n', avg_darkfireFreq);
% else
% end

%% Histogram method of finding frequencies and PI per unit    

% if Trigger > 0
%     [N_unit, EDGES_unit] = cellfun(@(x) histcounts(x, 'BinWidth', BW), raw_unitsTime, 'UniformOutput', false);
%     clearvars x
% 
%     avg_firingUnit = cellfun(@(x) x / BW, N_unit, 'UniformOutput', false);
%     clearvars x
% 
%     bin_centersUnit = cellfun(@(x) (x(1:end-1) + diff(x)/2), EDGES_unit, 'UniformOutput', false);
%     clearvars x
% 
%     merged_units = cell(numel(raw_units), 1);
% 
%     for m = 1:length(raw_units)
%         merge = [avg_firingUnit{m,1}(1,:); bin_centersUnit{m,1}(1,:)];
%         merge = merge.';
%         merged_units{m} = merge;
%         
% %         figure(7)
% %         hold on;
% %         plot(merged_units{m}(:,2),merged_units{m}(:,1));
% %         hold off;
%     end
%     
%     light_unit = cell(numel(raw_units), 1);
%     lighton = [];
% 
%     light_events = cell(numel(raw_units), 1);
%     lighton_events = [];
%     
%     lighton_freq  = cell(numel(raw_units), 1);
%     
%     dark_unit = cell(numel(raw_units), 1);
%     dark_events = cell(numel(raw_units), 1);
%     
%     dark_freq = cell(numel(raw_units), 1);
%     
%     unit_PIhist = cell(numel(raw_units), 1);
%     
%     
%     for m = 1:length(raw_units)
%         for r = 1:length(interv_times)
%             lighton(r) = sum(merged_units{m}(merged_units{m}(:,2) >= interv_times(r,1) & merged_units{m}(:,2) <= interv_times(r,2)));
%             lighton = lighton.';   
%         end
%         light_unit{m} = sum(lighton(:,1));
%         
%         for r = 1:length(interv_times)
%             lighton_events(r) = numel(merged_units{m}(merged_units{m}(:,2) >= interv_times(r,1) & merged_units{m}(:,2) <= interv_times(r,2)));
%             lighton_events = lighton_events.';   
%         end
%         light_events{m} = sum(lighton_events(:,1));
%        
%         lighton_freq{m} = light_unit{m} / light_events{m};
%         
%         dark_unit{m} = sum(merged_units{m}(merged_units{m}(:,2) >= 0)) - light_unit{m};
%         dark_events{m} = numel(merged_units{m}(merged_units{m}(:,2) >=0)) - light_events{m};
%         
%         dark_freq{m} = dark_unit{m} / dark_events{m};
%         
%         unit_PIhist{m} = (lighton_freq{m} - dark_freq{m}) / (lighton_freq{m} + dark_freq{m});
%         
%     end
% 
%     unit_PIhist = cell2mat(unit_PIhist);
%     
%     avg_lightfreqhist = mean(cell2mat(lighton_freq));
%     avg_darkfreqhist = mean(cell2mat(dark_freq));
%     
%     avg_unitPIhist = mean(unit_PIhist);
%     
%     figure(4)
%     hold on;
%     
%     BW2 = 0.1;
%     PI_histoplot = histogram(unit_PIhist, 'BinWidth', BW2);
%     xlim([-1 1]);
%     xlabel('Photoswitch index, PI');
%     ylabel('Events');
%     
%     hold off;
%     disp('The followind values come from binning the data:');
%     fprintf('Average firing frequency in darkness = %.2f Hz \n', avg_darkfreqhist);
%     fprintf('Average firing frequency in light = %.2f Hz \n', avg_lightfreqhist);
%     fprintf('Average photoswitch index, P.I. = %.3f \n', avg_unitPIhist);
% 
% else
% end


