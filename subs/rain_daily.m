function [event_rain,peakIntensity,rain_fullRes,dateRange] = rain_daily(in_dirRain,rainSource,rainInfo_test,rainPeriod,fileList_rain,...
    rainIDs,RfileYears_cont,lonR,latR,latRexp,radiusArea,midPoint,dateTracks_subset,track_subset,...
    lonR_360,posLon_left,posx,x,event_rain,peakIntensity,...
    rain_fullRes,dateRange,rain_options,unitConv) % Modified in May 2023 (not yet checked).
%% rain_daily.m
% This function extracts the rainfall for every day.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 5 May 2023

%% Define expanded TC range
% Note: Date [and the other TC data) were sorted by time (rather than ID) in window_apply.m.
leFirst = dateTracks_subset(2) - dateTracks_subset(1); % The time between the first two track positions.
leLast = dateTracks_subset(end) - dateTracks_subset(end - 1); % The time between the last two track positions.
tRange = [dateTracks_subset(1) - leFirst/2; dateTracks_subset(end) + leLast/2]; % Lower and upper track time range.

% For daily rainfall data, rainfall for all track positions within one day are compiled together.
% Thus, the hour of the track location is irrelevant:
tmpTCdates_floored = floor(dateTracks_subset); % Individual (shifted) and hours removed

% Determine all relevant days for which to extract rainfall (once per relevant day).
TCdates_daily = unique(tmpTCdates_floored); % One per shifted day

%% Now extract the first and last year of SHIFTED date data:
tmpyearTC = datevec(tmpTCdates_floored); tmpyearTC = tmpyearTC(:,1);
yearFirst = tmpyearTC(1); % First relevant year of the TC track.
yearLast = tmpyearTC(end); clear tmpyearTC % Last relevant year of the track.

%% Open the netCDF of the year that equals yearFirst:
[dailyRain,rainDate,rainInfo] = rain_access(in_dirRain,rainSource,rainPeriod,fileList_rain,...
    rainIDs,yearFirst,RfileYears_cont,lonR,latR,dateTracks_subset,tRange);
if yearFirst == yearLast % Only one NetCDF file needs to be open.
    flagNY = 0; % This track did NOT occur over New Year
    % Modified in May 2023 (not yet checked):
    if strcmp(rain_options,'raw') % Only save the raw data if requested (to save space).
        dateRange(x) = {rainDate};
    end
elseif yearLast - yearFirst == 1 % This is a New Year tracks (i.e. occurring over two calendar years)
    flagNY = 1; % This track did occur over New Year       
    % Open the NetCDF of the year that equals yearLast:
    [Daily_rain2,rainDate2] = rain_access(in_dirRain,rainSource,rainPeriod,fileList_rain,...
        rainIDs,yearLast,RfileYears_cont,lonR,latR,dateTracks_subset,tRange);
    % Modified in May 2023 (not yet checked):
    if strcmp(rain_options,'raw') % Only save the raw data if requested (to save space).
        dateRange(x) = {rainDate};
    end
end; clear M

rainYesFull = false(length(lonR),length(latR)); % This will keep track of which grids are ever within the radius.
rainDaily_1Track = zeros(length(lonR),length(latR),length(TCdates_daily));
for xTime = 1:length(TCdates_daily) % For every individual rain day (i.e. once per rain day)
    if  flagNY == 1
        % Check to see if the current year is the old year or the new year.
        % This subloop takes the year variable from time and compares the TC year with the last year of the track. 
        tmpyear = datevec(TCdates_daily(xTime)); tmpyear = tmpyear(1);
        if tmpyear == yearLast % Only enter this loop once per track:
            flagNY = 0; 
            dailyRain = Daily_rain2;
            rainDate = rainDate2; clear Daily_rain2 rainDate2
        end; clear tmpyear
    end 
    pos_trackDay = find(tmpTCdates_floored == TCdates_daily(xTime)); % Relevant date-position for which to extract rainfall

    % Extract relevant rainfall day-slab:
    posTime = find(rainDate == TCdates_daily(xTime));
    rain1day = dailyRain(:,:,posTime); 
    rain1day(rain1day == rainInfo(1)) = NaN; % rainInfo(1) == value corresponding to NaNs in NetCDF file (SILO: NaNs = -32767).

    % Reverse the offset and the scale (applied in netCDF) to ensure that the rainfall data are in the correct unit.
    % The scale is always multiplied and the offset always added.
    % rainInfo(2) == value corresponding to the scaling factor of rainfall in the netCDF file.
    % rainInfo(3) == value corresponding to the offset added to rainfall in the netCDF file.
    rain1day = rain1day.*rainInfo(2) + rainInfo(3); 

    % Add rainfall matrices together per day.
    rainYes = false(length(lonR),length(latR)); % Which grids to extract 1-day rainfall from (unlike rainYesFull, which represents the total track)
    rain0s = zeros(length(lonR),length(latR)); % Zero rain (initially) everywhere.
    for xT = 1:length(pos_trackDay) 
        % Find the position closest to the target track point (latitude and longitud). 
        % Note: posLon_left considers that lonR was expanded to the west to derive lonR_360!
        posLon = dsearchn(lonR_360,track_subset(posx(pos_trackDay(xT)),1)) - posLon_left; 
        posLat = dsearchn(latRexp,track_subset(posx(pos_trackDay(xT)),2));
        refCircle = radiusArea(:,:,posLat);

        tempcircle = false(length(lonR),length(latR));
        circleshift = posLon - midPoint; clear posLat posLon
        if circleshift > 0
            tempcircle(circleshift + 1:end,:) = refCircle(1:end - circleshift,:);
        elseif circleshift < 0
            tempcircle(1:end + circleshift,:) = refCircle(1 - circleshift:end,:);
        end
        rainYes(tempcircle == true) = true;
        rain0s(tempcircle == true) = 1;
    end; clear xT
    rainYesFull(rainYes == true) = true;
    rainDaily_1Track(:,:,xTime) = rain1day.*rain0s;
    event_rain(:,:,x) = event_rain(:,:,x) + rain1day.*rain0s; clear rain0s rainYes
end; clear rainDate flagNY posx xTime 
% Added in May 2023 (not yet checked):
if strcmp(rain_options,'raw') % Only save the raw data if requested (to save space).
    rain_fullRes(x) = {rainDaily_1Track*unitConv}; % Apply the unit conversion now.
end
% Now reset to NaN if it never was within the radius:
tmpRain = event_rain(:,:,x); tmpRain(rainYesFull == false) = NaN;
event_rain(:,:,x) = tmpRain; 
tmpPeak = max(rainDaily_1Track,[],3); tmpPeak(rainYesFull == false) = NaN;
peakIntensity(:,:,x) = tmpPeak; clear tmpRain
