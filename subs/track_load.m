function [date_tracks,track_numData,trackIDs_all,trackIDs] = ...
    track_load(in_dirTracks,fileNames_tracks,TdataCols,trackInfo,srcType)
%% track_load.m
% This function loads the tracks of the atmospheric low-pressure systems (ALPS).
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 11 May 2023

%% First check whether the track data was assigned the expected timezone of UTC+0:
if trackInfo(1) ~= 0
    if trackInfo(1) < 0
        sn = '';
    else
        sn = '+';
    end
    if strcmp(srcType,'grid')
        suff = ' in line 40 in rainfall_tracker.m!';
    elseif strcmp(srcType,'GHCND')
        suff = ' in line 44 in rainfall_tracker_ghcnd.m!';
    else
        suff = '!';
    end
    warning(['The assigned time zone for your track data is unexpectedly UTC',...
        sn,num2str(trackInfo(1)),' instead of UTC+0.']);
    cont = input(['Do you want to stop (0) the run - or continue (1) with a track time zone of UTC',sn,num2str(trackInfo(1)),'? --> ']);
    if cont == 1
        disp(['You have chosen to continue the run with the selected time zone (UTC',...
            sn,num2str(trackInfo(1)),') for track data.'])    
    else % cont ~= 1
        disp('You have indicated that the time zone for the track data should be corrected.')
        error(['Fix "timeZone_tracks"',suff])
    end; clear cont sn suff
end

%% Load the track data:
try
    if exist('OCTAVE_VERSION','builtin') == 0 % Matlab
        track_table = readtable([in_dirTracks,fileNames_tracks]);
        trackIDs_all = table2cell(track_table(:,1));
    else % GNU Octave
        pkg load io; pkg load statistics; % Load required GNU Octave packages
        track_table = csv2cell([in_dirTracks,fileNames_tracks]);
        disp(['The number of header rows for the track data is ',num2str(trackInfo(2)),'. If that is incorrect, stop the run and fix!'])
        track_table = track_table(1 + trackInfo(2):end,:);
        trackIDs_all = track_table(:,1);
    end
catch
    disp([in_dirTracks,fileNames_tracks])
    error('<-- Check that you have defined the path and filename for the track data correctly!')
end
trackIDs = unique(trackIDs_all); % Extract the trackIDs subset from table. 

%% Extract the numeric data from the ALPS file:
if exist('OCTAVE_VERSION','builtin') == 0 % Matlab
    if TdataCols(7) ~= 0 % There is a separate data column for "hour".
        track_numData = table2array(track_table(:,TdataCols(2:end))); % Include the hour column.
    else % There is no separate data column for "hour".
        track_numData = table2array(track_table(:,TdataCols(2:end - 1))); % No hour column is included.
    end
else % GNU Octave
    if TdataCols(7) ~= 0 % There is a separate data column for "hour".
        track_numData = cell2mat(track_table(:,TdataCols(2:end))); % Include the hour column.
    else % There is no separate data column for "hour".
        track_numData = cell2mat(track_table(:,TdataCols(2:end - 1))); % No hour column is included.
    end
end
% Now obtain the date (applicable code varies depending on presence of format of hour):
if TdataCols(7) ~= 0 % There is a separate data column for "hour".
    if max(track_numData(:,6)) > 1 || min(track_numData(:,6)) < 0
        warning(['Your track hours (',num2str(min(track_numData(:,6))),' to ',...
            num2str(max(track_numData(:,6))),') are not in the expected range (0 to 1).'])
        disp('Are your hours in 24-hour format instead? If so, do you want to divide your hours by 24?')
        hourCheck = input('Do you want to continue (1) by applying hours/24 or stop the run (0) and fix your track hours? --> ');
        if hourCheck == 1
            disp('The track hours are now divided by 24 to obtain a range of 0 to 1.')
            track_numData(:,6) = track_numData(:,6)/24;
        else
            error('Fix your track hour format.')
        end
    end
    date_tracks = datenum([track_numData(:,3),track_numData(:,4),track_numData(:,5) + track_numData(:,6)]);
else % There is no separate data column for "hour".
    date_tracks = datenum([track_numData(:,3),track_numData(:,4),track_numData(:,5)]);
end
track_numData = track_numData(:,1:2);
