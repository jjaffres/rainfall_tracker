function [dailyRain,rainDate] = rain_access_ghcnd(gauge_rain,gauge_time,siteNames,posIn_stations,dateTrack_orig,timeZones)
%% rain_access_ghcnd.m
% This function extracts rainfall data from the relevant GHCN-Daily station.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 3 Jan 2023

% Open the rainfall data for the target station:
dailyRain = NaN(length(posIn_stations),1);
rainDate = NaN(length(posIn_stations),1);
for xR = 1:length(posIn_stations) % Extract rain data for the current gauge of interest:
    tmpRain = cell2mat(gauge_rain(posIn_stations(xR)));
    tmpDate = cell2mat(gauge_time(posIn_stations(xR)));

% If the rain data are from Australia, be aware that:
%           Rainfall data cover 9 a.m. the previous day to 9 a.m. of "today".
%           However, all that rain is assigned to "today" (i.e. in midnight to midnight format).
%           Therefore, shift the track data forward by 14.99 hours to align with the rain day.
%           Thus, a track point at 9:30 a.m. the previous day will be shifted to 00:30 of "today".
            % AS, CK(?), KT(?), NF(?)

    % Note: The difference in timezone between rain(2) and track(1) has already
    %       been accounted for (see dateTracks_shifted in rain_aggregate_ghcnd.m).
    zoneDiff = (timeZones(2) - timeZones(1))/24; % Difference in timezone between rain(2) and track(1)
    % Because we keep the rain time zone constant, only shifting the track time,
    %       any rain cut-offs w.r.t. UTC (rather than local time) is irrespective of the track date.
    
    % Now determine the day of relevant rainfall:
    if strcmp(siteNames(posIn_stations(xR),:),'CH') || ...
        strcmp(siteNames(posIn_stations(xR),:),'MG')
%         % Shift track data forward depending on the implemented rain time zone:
%         %     If timezone = UTC+8 (i.e. correct for China, Mongolia), then proceed as usual.
%         %     by 3.99 hours to take into account the 8 p.m. local time 
%         %       (12:00 UTC) data period in China, Mongolia:
%         % China and Mongolia have timezone UTC+8:
%         rainZoneDiff = timeZones(2) - 8; % Difference (in hours) between input timezone and country timezone.

        % Shift track data forward by 3.99 hours to take into account the 8 p.m. local time 
        %       (12:00 UTC) data period in China, Mongolia:
        dateTrack = floor(dateTrack_orig + 3.99/24);
    elseif strcmp(siteNames(posIn_stations(xR),:),'AS') || ...
        strcmp(siteNames(posIn_stations(xR),:),'FJ')
        % Shift track data forward by 14.99 hours to take into account the 9 a.m. (local time) data period in Australia and Fiji:
        dateTrack = floor(dateTrack_orig + 14.99/24);
    elseif strcmp(siteNames(posIn_stations(xR),:),'IN')
        % Shift track data forward by 15.49 hours to take into account the 8:30 a.m. (local time) data period in India:
        dateTrack = floor(dateTrack_orig + 15.49/24);
    else % Keep track date unchanged:
        dateTrack = floor(dateTrack_orig);
    end
    rainDate(xR) = dateTrack;
    
    posR = find(tmpDate == dateTrack); % The position of the relevant rain day.
    if length(posR) == 1
        dailyRain(xR) = tmpRain(posR); % Rain data for one station (of currently track position).
    elseif length(posR) > 1
        stop
    end
end
