function [event_rain,peakIntensity,rain_fullRes,dateRange] = rain_subdaily(in_dirRain,rainSource,rainInfo_test,rainPeriod,fileList_rain,...
    rainIDs,RfileYears_cont,lonR,latR,latRexp,radiusArea,midPoint,dateTracks_subset,track_subset,...
    lonR_360,posLon_left,x,event_rain,peakIntensity,rain_fullRes,dateRange,rain_options,leRainT,unitConv)

%% rain_subdaily.m
% This function extracts the rainfall for every sub-daily rainfall interval (e.g. hourly).
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 10 Jan 2022

%% Define expanded TC range:
% Note: Date [and the other TC data) were sorted by time (rather than ID) in window_apply.m.
leFirst = dateTracks_subset(2) - dateTracks_subset(1); % The time between the first two track positions.
leLast = dateTracks_subset(end) - dateTracks_subset(end - 1); % The time between the last two track positions.
% For the range start, add a second (== 1/3600/24) in case the time is exactly the end of a rain period:
tRange = [dateTracks_subset(1) - leFirst/2 + 1/3600/24; dateTracks_subset(end) + leLast/2]; % Lower and upper track time range.

%% Obtain the time range for every track position:
track_timeRange = NaN(length(dateTracks_subset),2);
track_timeRange(1,1) = leFirst; track_timeRange(end,2) = leLast;
for xR = 1:length(dateTracks_subset) 
    % For the range start, add a second (== 1/3600/24) in case the time is exactly the end of a rain period.
    if xR == 1
        le1 = dateTracks_subset(xR + 1) - dateTracks_subset(xR);
        track_timeRange(xR,:) = [(dateTracks_subset(xR) - le1/2 + 1/3600/24) (dateTracks_subset(xR) + le1/2)];
    elseif xR == length(dateTracks_subset)
        track_timeRange(xR,:) = [(dateTracks_subset(xR) - le1/2 + 1/3600/24) (dateTracks_subset(xR) + le1/2)];
    else
        le2 = dateTracks_subset(xR + 1) - dateTracks_subset(xR);
        track_timeRange(xR,:) = [(dateTracks_subset(xR) - le1/2 + 1/3600/24) (dateTracks_subset(xR) + le2/2)];
        le1 = le2; clear le2
    end
end; clear le1 xR

%% Now extract the first and last year of SHIFTED date data:
% if x == 1; warning('Hourly data for 23:01 31 Dec 2020 would require the data for 00:00 1/1/2021'); end
% Shift the time forward by the timestep AND deduct a second (to avoid the 
%       potential addition of a new day because of just a second). 
%       (e.g, 23:00 in hourly data should remain in the original day, whereas
%       23:01-00:00 will be covered by rainfall with the midnight time):
tmpyearTC = datevec(tRange + leRainT - 1/3600/24);
tmpyearTC = tmpyearTC(:,1); 
yearFirst = tmpyearTC(1); % First relevant year of the track.
yearLast = tmpyearTC(2); clear tmpyearTC % Last year of the track.

%% Open the netCDF of the year that equals yearFirst:
[subdailyRain,rainDate,rainInfo] = rain_access(in_dirRain,rainSource,rainPeriod,fileList_rain,...
    rainIDs,yearFirst,RfileYears_cont,lonR,latR,dateTracks_subset,tRange);
% Note: subdailyRain and rainDate are subsets, covering only the period of the TC track.

if yearFirst == yearLast % Only one netCDF file needs to be open.
    flagNY = 0; % This TC did NOT occur over New Year 
    leFull = length(rainDate);
    if strcmp(rain_options,'raw') % Only save the raw data if requested (to save space).
        dateRange(x) = {rainDate};
    end
elseif yearLast - yearFirst == 1 % This is a New Year TC (i.e. occurring over two calendar years)
    flagNY = 1; % This TC did occur over New Year       
    % Open the netCDF of the year that equals yearLast:
    [subdailyRain2,rainDate2,~] = rain_access(in_dirRain,rainSource,rainPeriod,fileList_rain,...
        rainIDs,yearLast,RfileYears_cont,lonR,latR,dateTracks_subset,tRange);
    leFull = length(rainDate) + length(rainDate2);
    if strcmp(rain_options,'raw') % Only save the raw data if requested (to save space).
        dateRange(x) = {rainDate; rainDate2};
    end
end; clear M  

% Note: The last time slice of sub-daily rain in the first year is contained
%        in the file of the next year (e.g. 23:01 - 23:59 31/12/2020 is
%        contained in the 00:00 1/1/2021 rain slab).
posRrep = NaN(ceil(2*(track_timeRange(end,2) - track_timeRange(1,1))/leRainT),2);
posTC = NaN(ceil(2*(track_timeRange(end,2) - track_timeRange(1,1))/leRainT),1); % Reference position of applicable TC lon/lat.
ct = 1;
for xTC = 1:length(dateTracks_subset)
    posR1 = find(rainDate >= track_timeRange(xTC,1),1,'first');
    posR2 = find(rainDate >= track_timeRange(xTC,2),1,'first');
    if ~isempty(posR1)
        flag1 = 1; 
    else
        posR1 = find(rainDate2 >= track_timeRange(xTC,1),1,'first');
        flag1 = 2; 
%         error('This should never be empty?!')
    end
    if ~isempty(posR2) % I.e. if this track was not over the New Year:
        flag2 = 1; 
    else
        posR2 = find(rainDate2 >= track_timeRange(xTC,1),1,'first');
        flag2 = 2; 
%         error('Check New Year tracks?!')
    end
    if flag2 == 1 || flag1 == 2 % Full period is in same year (either 1st or 2nd):
        posRange = posR1:posR2;
        posRrep(ct:ct + posR2 - posR1,:) = [posRange' flag2.*ones(length(posRange),1)];
    else % Period is over New Year (two rainfiles needed):
        re1 = posR1:length(rainDate);
        re2 = 1:posR2;
        posRange = [re1 re2]';
        posRrep(ct:ct + length(posRange) - 1,:) = [posRange [flag1.*ones(length(re1),1) flag2.*ones(length(re2),1)]];
        
        stopCheck
    end
    posTC(ct:ct + length(posRange) - 1) = xTC;
    ct = ct + length(posRange); clear posRange
end; clear xTC
posRrep = posRrep(1:ct - 1,:); posTC = posTC(1:ct - 1);

rainYesFull = false(length(lonR),length(latR)); % Will keep track of which grids are ever within the radius
% rainPeriod_1Track = zeros(length(lonR),length(latR),length(leFull));
rainPeriod_1Track = NaN(length(lonR),length(latR),length(leFull));
for xTime = 1:leFull % For every individual rain slice (e.g. every rain hour)
    posTime = find(posRrep(:,1) == xTime);

    % Add rainfall matrices together per rainfall time period.
    rainYes = false(length(lonR),length(latR)); % Logical matrix with same lon/lat grid size as the rainfall data.
    rain0s = zeros(length(lonR),length(latR)); % Zero rain (initially) everywhere.
    rainNaNs = NaN(length(lonR),length(latR)); % NaN rain (initially) everywhere.
    for xT = 1:length(posTime) 

        if  flagNY == 1
            % Check to see if the current year is the old year or the new year.
            if posRrep(posTime,2) == 2 % Only enter this loop once per track:
                stop2
                flagNY = 0; 
                subdailyRain = subdailyRain2; clear subdailyRain2 rainDate2
            end; clear tmpyear
        end     
        
        % Extract relevant rainfall time-slice:
        rain_1slice = subdailyRain(:,:,posRrep(posTime(xT),1)); 
        rain_1slice(rain_1slice == rainInfo(1)) = NaN; % rainInfo(1) == value corresponding to NaNs in netCDF file. 

        % Reverse the offset and the scale (applied in netCDF) to ensure that the rainfall data are in the correct unit.
        % The scale is always multiplied and the offset is always added.
        % rainInfo(2) == value corresponding to the scaling factor of rainfall in the netCDF file.
        % rainInfo(3) == value corresponding to the offset added to rainfall in the netCDF file.
        rain_1slice = rain_1slice.*rainInfo(2) + rainInfo(3); 
    
        % Find the position closest to the target track point (latitude and longitude).
        % Note: posLon_left considers that lonR was expanded to the west to derive lonR_360!
        posLon = dsearchn(lonR_360,track_subset(posTC(posTime(xT)),1)) - posLon_left; 
%         posLat = dsearchn(latR,track_subset(posTC(posTime(xT)),2));
        posLat = dsearchn(latRexp,track_subset(posTC(posTime(xT)),2));
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
        rainNaNs(tempcircle == true) = 1;
    end; clear xT
    rainYesFull(rainYes == true) = true;
    rainPeriod_1Track(:,:,xTime) = rain_1slice.*rainNaNs;
    event_rain(:,:,x) = event_rain(:,:,x) + rain_1slice.*rain0s; clear rain0s rainYes
end; clear rainDate flagNY xTime 
if strcmp(rain_options,'raw') % Only save the raw data if requested (to save space).
    rain_fullRes(x) = {rainPeriod_1Track*unitConv}; % Apply the unit conversion now.
end
% Now reset to NaN if it never was within the radius
tmpRain = event_rain(:,:,x); tmpRain(rainYesFull == false) = NaN;
event_rain(:,:,x) = tmpRain;  
tmpPeak = nanmax(rainPeriod_1Track,[],3); % tmpPeak = max(rainPeriod_1Track,[],3); 
tmpPeak(rainYesFull == false) = NaN;
peakIntensity(:,:,x) = tmpPeak; clear posx tmpRain
