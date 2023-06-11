function [dateTracks_shifted,track_numData] = rain_vs_tracks(lonR,timeZone_rain,track_numData,trackInfo,date_tracks,rainSource)
%% rain_vs_tracks.m
% This function compares to compatibility of the content in the rainfall and track files.
% Data (longitude and/or timezone) of the tracks are restructured, if required.
%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 18 Jan 2022

%% Convert longitude of the track data if the range does not match the rainfall grid
% Check whether the longitude is in +/- 180 degrees or 360 degrees:
if min(lonR) < 0 
    % The rainfall longitude is split at the international date line (+/- 180 degrees)
    if max(track_numData(:,1)) > 180 % Shift the longitude values (in the western hemisphere).
        stop360
    end
else
    % The rainfall longitude is split at the prime meridian (0 degrees)
    if min(track_numData(:,1)) < 0 % Shift the longitude values (in the western hemisphere).
%     if max(track_numData(:,1)) < 0 % Shift the longitude values (in the western hemisphere).
        disp('Western hemisphere (longitude) track values are now shifted by 360 degrees (to positive values)')
        track_numData(track_numData(:,1) < 0,1) = track_numData(track_numData(:,1) < 0,1) + 360; % Shift negative values up by 360 degrees
    end
end

%% Shift the dates of the track data if they do not align with the rainfall grid:
if trackInfo(1) ~= timeZone_rain
    disp('The track and rainfall data are NOT based on the same time zone and the track dates will therefore be shifted.')
    dateTracks_shifted = date_tracks + (timeZone_rain - trackInfo(1))/24;
else % Dates are compatible and date_tracks can therefore remain unchanged.
    disp('The track and rainfall data are based on the same time zone and no shift will therefore be applied.')
    dateTracks_shifted = date_tracks;
end

if strcmp(rainSource,'SILO') || strcmpi(rainSource,'AWAP')
    if strcmp(rainSource,'SILO')
        disp([rainSource,' rainfall data cover 9 a.m. the previous day to 9 a.m. of "today".'])
        disp('      However, all that rain is assigned to "today" (i.e. in midnight to midnight format).')
        disp('      Therefore, shift the track data forward by 14.99 hours to align with the rain day.')
        disp('      Thus, a track point at 9:30 a.m. the previous day will be shifted to 00:30 of "today".')
    elseif strcmpi(rainSource,'AWAP')
       % AWAP rainfall data cover 9 a.m. the previous day to 9 a.m. of "today".
       % A track point at 9:30 a.m. the previous day will be shifted to 00:30 of "today".
        disp(['Shift the track data forward by 14.99 hours to align with the ',rainSource,' rain day.'])
    end
    % Shift by (just under) 15 hours to take into account 9 a.m. rainfall cut-off:
    dateTracks_shifted = dateTracks_shifted + 14.99/24; 
end
