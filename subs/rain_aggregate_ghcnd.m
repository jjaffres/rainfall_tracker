function event_rain = rain_aggregate_ghcnd(in_dirRain,fileNames_rain,rainRadius,sideWin,...
    timeZone_rain,in_dirTracks,fileNames_tracks,TdataCols,trackInfo,out_dir,outName_suffix)
%% rain_aggregate_ghcnd.m
% This function aggregates the rainfall of stations within the radius along 
%       the track of the atmospheric low-pressure system.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 11 May 2023

%% Load TC track data.
srcType = 'GHCND'; % Data source type: to tailor output messages.
[date_tracks,track_numData,trackIDs_all,~] = track_load(in_dirTracks,fileNames_tracks,TdataCols,trackInfo,srcType);
% Adjust for timezone differences between the track and station datasets.
disp('Note: Only one timezone per run is currently implemented. Run script for each timezone separately.')
dateTracks_shifted = date_tracks + (timeZone_rain - trackInfo(1))/24; clear date_tracks

%% Check that the TC track input is in order.
track_check(track_numData,dateTracks_shifted,trackIDs_all,out_dir,fileNames_tracks,trackInfo)

%% Now check if a side window needs to be invoked:
if sideWin == 0 % No side window is applied. Thus keep original data.
    dateTracksExp_shifted = dateTracks_shifted;
    track_numDataExp = track_numData;
    trackIDs_allExp = trackIDs_all;    
else % A side window is wanted
    disp(['You have elected to apply a side window (',num2str(sideWin),' hours on either side of each track position)'])
    % Because GHCN-Daily data are in daily format, side windows of less than 12 hours (i.e. less
    %       than 1 day total) do not require special treatment.
    numPeriods = ceil(sideWin/24); % GHCN-daily is in daily (24 hour) format. Hence, each multiple 
    %                         (of 24) of the side window requires a separate date copy.
    
    le = size(track_numData,1);
    dateTracksExp_shifted = [dateTracks_shifted; NaN(le*numPeriods*2,1)];
    track_numDataExp = repmat(track_numData,numPeriods*2 + 1,1); % Apply repmat!!!
    trackIDs_allExp = repmat(trackIDs_all,numPeriods*2 + 1,1); % Apply repmat!!! 
    for x = 1:numPeriods % Number of additional periods for which to create positional copies for.
        posR1 = le*(x*2 - 1) + 1; % Starting position for addition of preceding time.
        posR2 = le*(x*2 + 1); % Last position for addition of subsequent time.
        if x < numPeriods % Shift by the multiple of 24 hours (reflected by "x" = 1 day):
            dateTracksExp_shifted(posR1:posR2) = [dateTracks_shifted - x; dateTracks_shifted + x];
        else % Shift by the full period (sideWin)
            dateTracksExp_shifted(posR1:posR2) = [dateTracks_shifted - sideWin/24; dateTracks_shifted + sideWin/24];
        end        
    end; clear le numPeriods
end; clear dateTracks_shifted track_numData trackIDs_all

%% Create high-resolution lon/lat vectors.
% For station data, a high-resolution grid is created for the purpose of template creation:
res = 0.01; latR = (-90:res:90)';
lonR = (0:res:360)'; % 0:res:360 - res; 
% Apply lonR/latR vectors to find the nearest equivalent location for each track position.

%% Determine relevant latitudes (for template creation):
% First, convert western longitudes (<0 degrees), if necessary:
track_numDataExp(track_numDataExp(:,1) < 0,1) = track_numDataExp(track_numDataExp(:,1) < 0,1) + 360; 
% Relevant latitudinal positions for which a rain template area needs to be extracted:
posRel_tracks = NaN(size(track_numDataExp,1),2); % track_latMatch
for x = 1:size(posRel_tracks,1)
   posRel_tracks(x,:) = [dsearchn(lonR,track_numDataExp(x,1)) dsearchn(latR,track_numDataExp(x,2))];
end; clear x
posLatU = unique(posRel_tracks(:,2)); % All unique latitude grid positions (for which to create a radial area).

% For any tracks nearest to 360 degrees, assign to 0 instead:
posRel_tracks(posRel_tracks(:,1) == length(lonR),1) = 1;

%% Extract template areas inside the target radius (only for relevant station latitudes).
% Note: Only create template areas for relevant latitudes 
%       (i.e. one template for all track points at the same latitude).
cellCount = circle_templates_stations(rainRadius,lonR,latR,posLatU);

%% Use the station positional and temporal information to narrow down the relevant sites.
timeZones = [trackInfo(1) timeZone_rain]; 
% [event_rain,stations_ghcnd,lonlat_ghcnd,pos_stationsIn,daily_rain,daily_dates,inCircle_YN,trackIDs] = ...
%     station_select(in_dirRain,out_dir,fileNames_rain,cellCount,dateTracksExp_shifted,...
%     trackIDs_allExp,latR,lonR,posLatU,posRel_tracks,timeZones);
[event_rain,stationIDs,stations_ghcnd,lonlat,lonlat_ghcnd,pos_stationsIn,daily_rain,daily_dates,inCircle_YN,trackIDs] = ...
    station_select(in_dirRain,fileNames_rain,cellCount,dateTracksExp_shifted,...
    trackIDs_allExp,latR,lonR,posLatU,posRel_tracks,timeZones);

% Narrow down the relevant stations (i.e. remove any stations that were never accessed):
inCheck = false(size(lonlat_ghcnd,1),1);
for x = 1:length(event_rain)
    % Now re-open pos_stationsIn (for each event) and determine which stations are relevant: 
    tmpPos = cell2mat(pos_stationsIn(x));
    inCheck(tmpPos) = 1; clear tmpPos
end; clear x
fullOrder = 1:length(inCheck);

%% Now obtain the maximum intensity per relevant site and track:
peakIntensity = cell(size(event_rain));
for x = 1:length(trackIDs)
    peakIntensity(x) = {max(daily_rain{x})};
end

%% Save the compiled rainfall of each TC event.
disp('The daily rainfall station data were successfully collated for each low-pressure system.')
% lonlat = track_numData(:,1:2);
readme = {'rainRadius:      The applied radius from the centre of the low.';
          'sideWin:         The applied side window for each track position.';
          'timeZones:       Assigned time zones for TC tracks (position 1) vs rainfall (position 2).';
          'lonlat:          Vector of matrices that list relevant longitudes and latitudes (per track) for station rainfall data.'; 
          'lonlat_ghcnd:    Matrix of longitude and latitude for station rainfall data (see pos_stationsIn).'; 
          'dims_lonlat:     Header for lonlat_ghcnd.'
          'pos_stationsIn:	Positions (of original GHCN-Daily list) of stations inside the circle at least once.';
          'event_rain:      Vector containing 1D vectors of total event rainfall per track and relevant weather station.';
          'peakIntensity:   Vector containing 1D vectors of peak (24-hour) rainfall intensity per track and relevant weather station.'
          'daily_rain:      Vector of matrices that lists daily rainfall for all stations that are inside the circle.';
          'daily_dates:     Vectors of relevant dates.';
          'inCircle_YN:     Vector of logical 2D matrices that shows which stations were inside the circle (regardless of data availability).'
          'stationIDs:      List of all relevant stations (per track).';
          'trackIDs:        List of unique low-pressure system IDs.'};
% dims_event_rain = {'Longitude','Latitude','Daily rain slice for TC'}; 
dims_lonlat = {'Longitude','Latitude'}; 

save([out_dir,'eventRain_ghcnd_',outName_suffix,'.mat'],'readme','rainRadius','sideWin',...
    'timeZones','lonlat','lonlat_ghcnd','dims_lonlat','pos_stationsIn','event_rain','peakIntensity',...
    'daily_rain','daily_dates','inCircle_YN','stationIDs','trackIDs','stations_ghcnd','-mat');
