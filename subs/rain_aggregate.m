function rain_output = rain_aggregate(in_dirRain,fileNames_rain,rain_options,unitConv,rainRadius,sideWin,...
    rainIDs,rainSource,timeZone_rain,in_dirTracks,fileNames_tracks,TdataCols,trackInfo,out_dir,outName_suffix)
%% rain_aggregate.m
% This function aggregates the rainfall within the radius along the track of the atmospheric low-pressure system.
%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 11 May 2023
% addpath('.\subs\'); % Location of subroutines

fileList_rain = dir([in_dirRain,fileNames_rain]); % Obtain the full list of relevant rainfall files
if size(fileList_rain,1) == 0
    error(['The rainfall file list is empty. Check the path (',in_dirRain,') and filename (',fileNames_rain,')!'])
end

%% Load ALPS track data.
srcType = 'grid'; % Data source type: to tailor output messages.
[date_tracks,track_numData,trackIDs_all,trackIDs] = track_load(in_dirTracks,fileNames_tracks,TdataCols,trackInfo,srcType);

%% Check that the track input is in order.
track_check(track_numData,date_tracks,trackIDs_all,out_dir,fileNames_tracks,trackInfo)

%% Extract the year(s) and position of the (first/last) year from each filename:
RfileYears_cont = rain_fileYears(in_dirRain,fileList_rain);

%% Extract template areas inside the target radius:
[radiusArea,rainInfo_test,lonR,latR,latRexp,midPoint,rainPeriod,leRainT,reg_vs_glob] = ...
    circle_templates(in_dirRain,fileList_rain,rain_options,timeZone_rain,...
    rainRadius,rainIDs,rainSource,unitConv,track_numData(:,2),out_dir);
% rainStep_hrs = leRainT*24; % Convert daily

%% Check whether the data formatting of the tracks and rainfall grids are compatible.
% Modify the TC track data (longitude and/or timezone), if required.
[dateTracks_shifted,track_numData] = rain_vs_tracks(lonR,timeZone_rain,track_numData,trackInfo,date_tracks,rainSource);

%% Additional spatial information for rainfall data
if strcmp(reg_vs_glob,'regional')
    % For regional datasets, create an expanded longitudinal vector to later permit circle shifting:
    lonDiff = 1/(find(lonR == lonR(1) + 1) - 1); % lonR(2) - lonR(1); % 
    % Test whether absolute numbers are included in lonR (in which case zero would be, too): 
    if find(lonR == lonR(1) + 1) == find(lonR == floor(lonR(1)) + 1) 
        lonR_360 = (0:lonDiff:360 - lonDiff)'; 
        posLon_left = find(lonR_360 == lonR(1)) - 1; % The additional number of grid cells to the west.
    else
        stop
    end; clear lonDiff
else
    lonR_360 = lonR; % Rainfall longitude range is already 360 degrees.
    posLon_left = 0; % The additional number of grid cells to the west.
end
% lonR_360 = (lonR(1):lonR(2) - lonR(1):180)';
% warning('"lonR_360" may have to be specific to individual rainfall datasets.')

% Ensure that longitude values are all positive (i.e. not split at +/- 180 degrees east/west)
% See rain_vs_tracks.m

%% Now check if a side window needs to be invoked:
if sideWin ~= 0 % A side window is applied.
    rainStep_hrs = 24*leRainT; % Convert daily to hourly.
    [dateTracks_shifted,track_numData,trackIDs_all] = ...
        window_apply(sideWin,dateTracks_shifted,track_numData(:,1:2),trackIDs_all,rainStep_hrs);
end

%% Rain vs tracks loop
% Identify the rainfall that coincides with ALPS occurrence within the area encompassed by the radius.
% Rainfall for each longitude/latitude grid point per track (3rd dimension):
event_rain = zeros(length(lonR),length(latR),length(trackIDs));
peakIntensity = zeros(length(lonR),length(latR),length(trackIDs));
if strcmp(rain_options,'raw') % Check if raw rainfall data were requested:
    rain_fullRes = cell(length(trackIDs),1);
    dateRange = cell(length(trackIDs),1);
else
    rain_fullRes = 'Raw data were not saved';
    dateRange = 'Dates for raw data were not saved';
end
for x = 1:length(trackIDs)
    if floor(x/50)*50 == x; disp(['Extracting rainfall for the ',num2str(x),'th track']); end % Display a message for every 10th track track.
    posx = find(strcmp(trackIDs_all,trackIDs(x)) == 1); % Data position of the full track.
    
    dateTracks_subset = dateTracks_shifted(posx);
    if dateTracks_subset(end) - dateTracks_subset(1) > 366
        disp(['Check for multiple tracks with the same name --> ',trackIDs{x}])
        error('Super-zombie (track lasts over a year) - check for potential database issues (e.g. duplicate name).');
    end
    
    if strcmp(rainPeriod,'daily')
         % Modified in May 2023 (not yet checked):
%         [event_rain,peakIntensity] = rain_daily(in_dirRain,rainSource,rainInfo_test,rainPeriod,fileList_rain,...
%             rainIDs,RfileYears_cont,lonR,latR,latRexp,radiusArea,midPoint,dateTracks_subset,...
%             track_numData,lonR_360,posLon_left,posx,x,event_rain,peakIntensity);        
        [event_rain,peakIntensity,rain_fullRes,dateRange] = rain_daily(in_dirRain,rainSource,rainInfo_test,rainPeriod,fileList_rain,...
            rainIDs,RfileYears_cont,lonR,latR,latRexp,radiusArea,midPoint,dateTracks_subset,...
            track_numData,lonR_360,posLon_left,posx,x,event_rain,peakIntensity,...
            rain_fullRes,dateRange,rain_options,unitConv);    
    else
        [event_rain,peakIntensity,rain_fullRes,dateRange] = rain_subdaily(in_dirRain,rainSource,rainInfo_test,rainPeriod,fileList_rain,...
            rainIDs,RfileYears_cont,lonR,latR,latRexp,radiusArea,midPoint,dateTracks_subset,...
            track_numData(posx,:),lonR_360,posLon_left,x,event_rain,peakIntensity,...
            rain_fullRes,dateRange,rain_options,leRainT,unitConv);     
    end
end; clear x

%% Save the compiled rainfall of each TC event
disp('The rainfall data were successfully collated for each low-pressure system.')
timeZones = [trackInfo(1) timeZone_rain]; 
% Note: The scale factor to convert between units is applied to rainfall!
rain_output  = save_rain(rain_options,unitConv,rainRadius,sideWin,timeZones,...
    lonR,latR,trackIDs,event_rain,peakIntensity,rain_fullRes,dateRange,...
    out_dir,rainSource,outName_suffix);

% [X,Y] = meshgrid(latR,lonR); % Grid matrices for longitude (X) and latitude (Y)
% x = 1; figure; surf(Y,X,event_rain(:,:,x),'EdgeColor','none'); view(2); axis image; colorbar