% function [event_rain,stations_ghcnd,lonlat_ghcnd,pos_stationsIn,daily_rain,daily_dates,inCircle_YN,trackIDs] = ...
%     station_select(in_dirRain,out_dir,fileNames_rain,cellCount,...
%     dateTracks_shifted,trackIDs_all,latR,lonR,posLatU,posRel_tracks,timeZones)
function [event_rain,stationIDs,stations_ghcnd,lonlat,lonlat_ghcnd,pos_stationsIn,...
    daily_rain,daily_dates,inCircle_YN,trackIDs] = ...
    station_select(in_dirRain,fileNames_rain,cellCount,dateTracks_shifted,...
    trackIDs_all,latR,lonR,posLatU,posRel_tracks,timeZones)
%% station_select.m
% This function aggregates the rainfall of stations within the radius along 
%       the track of the atmospheric low-pressure system.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 3 Jan 2023

trackIDs = unique(trackIDs_all); % Extract the trackIDs subset from table. 

%% Extract positional information for GHCN-daily data.
[gauge_infos,gauge_rain,gauge_time] = ghcnd_load(in_dirRain,fileNames_rain);
disp('The GHCN-daily rainfall data have now been extracted.')
siteNames = char(gauge_infos(:,1)); siteNames = siteNames(:,1:2);

%% Use the station positional and temporal information to narrow down the relevant sites.
lonlat_ghcnd = cell2mat(gauge_infos(:,[3 2])); % Position of rain gauges.
dateRange_ghcnd = cell2mat(gauge_infos(:,5:6)); % Period of rain gauge operation.
stations_ghcnd = cell2mat(gauge_infos(:,1)); % Unique station ID (in GHCN-daily).
% Convert longitude to the 0-360 degree range:
lonlat_ghcnd(lonlat_ghcnd(:,1) < 0,1) = lonlat_ghcnd(lonlat_ghcnd(:,1) < 0,1) + 360; 

% Assign each gauge to the relevant lonR/latR:
posRel_ghcnd = NaN(size(lonlat_ghcnd,1),2);
for x = 1:size(posRel_ghcnd,1)
   posRel_ghcnd(x,:) = [dsearchn(lonR,lonlat_ghcnd(x,1)) dsearchn(latR,lonlat_ghcnd(x,2))];
end; clear x 
% For any station nearest to 360 degrees, assign to 0 instead:
posRel_ghcnd(posRel_ghcnd(:,1) == length(lonR),1) = 1;

%% Now determine which stations are relevant (in a loop).
% Identify the rainfall that coincides with TC occurence within the area encompassed by the radius.
% Rainfall for each longitude/latitude grid point per TC (3rd dimension):
event_rain = cell(length(trackIDs),1); % Rain total for each event.
daily_rain = cell(length(trackIDs),1); % Each event will have a days x station matrix with daily rain values.
daily_dates = cell(length(trackIDs),1); % Each event will have a days x station matrix with daily rain values.
inCircle_YN = cell(length(trackIDs),1); % Logical matrix - per event - for each day x station to check when each station was inside the circle.
pos_stationsIn = cell(length(trackIDs),1); % Positions (of original GHCN-Daily list) of stations inside the circle at least once.
stationIDs = cell(length(trackIDs),1); % Stations IDs (see original GHCN-Daily list).
lonlat = cell(length(trackIDs),1); % Vector containing the relevant longitude/latitude matrices for each track.
for xT = 1:length(trackIDs)
    if floor(xT/50)*50 == xT; disp(['Extracting rainfall for the ',num2str(xT),'th track']); end % Display a message for every 10th TC track.
    posx = find(strcmp(trackIDs_all,trackIDs(xT)) == 1); % Position of the full track of the target TC.
    
    dateTracks_subset = dateTracks_shifted(posx);
    if dateTracks_subset(end) - dateTracks_subset(1) > 366
        disp(['Check for multiple tracks with the same name --> ',trackIDs{xT}])
        error('Super-zombie (track lasts over a year) - check for potential database issues (e.g. duplicate name).');
    end
    
    % Potentially relevant dates of rain days (remove irrelevant days at the end of the loop):
    eventDateRange = unique(floor(dateTracks_subset));
    eventDateRange = min(eventDateRange) - 1:max(eventDateRange) + 1;
    % Day-resolution of rainfall within the circle:
    eventDetails = NaN(length(eventDateRange),size(gauge_infos,1));
    inCircleDetailsYN = false(length(eventDateRange),size(gauge_infos,1));
    for xE = 1:length(posx) % For each track position of the current event:
        % First, determine which stations were operational at the time of the track position
        %       (with a 1-day buffer to account for differences in 24-hour rain cut-off times).
        tmp_dateTrack = dateTracks_subset(xE); % dateTracks_shifted(posx(xE));
        
        % Positions of relevant sites operational during the period of interest:
        posG_dates = find(dateRange_ghcnd(:,1) < tmp_dateTrack + 1 & dateRange_ghcnd(:,2) > tmp_dateTrack - 1);
        if ~isempty(posG_dates) % If there is at least one relevant site.
            posSlice = find(posLatU == posRel_tracks(posx(xE),2)); % Relevant slice position.
            
            % Find relevant positions of sites in a box surrounding the track point
            % (based on the largest number of grid points from the reference longitude):
            posBox_lonRef = (posRel_tracks(posx(xE),1) - max(cellCount(:,posSlice)):posRel_tracks(posx(xE),1) + max(cellCount(:,posSlice)))';
            % Relevant positions of sites based on the first/last non-NaN value w.r.t. the reference longitude:
            posBox_latRef = (find(~isnan(cellCount(:,posSlice)),1,'first'):find(~isnan(cellCount(:,posSlice)),1,'last'))';

            % Adjust posBox_lonRef if values are outside the acceptable range --> 1:length(lonR) - 1
            if min(posBox_lonRef) < 1 || max(posBox_lonRef) >= length(lonR)           
                posBox_lonRef(posBox_lonRef < 0) = posBox_lonRef(posBox_lonRef < 0) + length(lonR);
                posBox_lonRef(posBox_lonRef >= length(lonR)) = posBox_lonRef(posBox_lonRef >= length(lonR)) - length(lonR) + 1;
            end

            % Relevant positions based on both ghcnd longitude and latitude:
            posG_loc = find(ismember(posRel_ghcnd(:,1),posBox_lonRef) & ismember(posRel_ghcnd(:,2),posBox_latRef));
            clear posBox_latRef posBox_lonRef

            % Relevant positions based on both ghcnd location and date (operational):
            posG_comboDL = posG_loc(ismember(posG_loc,posG_dates)); 
            if ~isempty(posG_comboDL) % If some gauges are in the generic box.
                % For the remaining stations, specifically check whether they are in the circle:
                inbox = false(length(posG_comboDL),1);
                for xB = 1:length(inbox) % For each gauge within the box:
                    % Number of relevant in-circle grid points on either side of the reference track longitude:
                    tmp_lonShift = cellCount(posRel_ghcnd(posG_comboDL(xB),2),posSlice); 

                    % Positional range w.r.t. longitudinal track position:
                    tmpPos_lonRange = (posRel_tracks(posx(xE),1) - tmp_lonShift:posRel_tracks(posx(xE),1) + tmp_lonShift)'; 
                    clear tmp_lonShift                

                    % Adjust posBox_lonRef if values are outside the acceptable range --> 1:length(lonR) - 1
                    if min(tmpPos_lonRange) < 1 || max(tmpPos_lonRange) >= length(lonR)  
                        tmpPos_lonRange(tmpPos_lonRange < 0) = tmpPos_lonRange(tmpPos_lonRange < 0) + length(lonR);
                        tmpPos_lonRange(tmpPos_lonRange >= length(lonR)) = ...
                            tmpPos_lonRange(tmpPos_lonRange >= length(lonR)) - length(lonR) + 1;
                    end

                    % If longitude is within range, then the track position is within the circle:
                    if ismember(posRel_ghcnd(posG_comboDL(xB),1),tmpPos_lonRange)
                        inbox(xB) = 1;
                    end
                end
                posIn_stations = posG_comboDL(inbox); % Stations inside the circle.
                
                % Now, for all relevant stations, extract the applicable rainfall:
                [dailyRain,rainDate] = rain_access_ghcnd(gauge_rain,gauge_time,siteNames,...
                    posIn_stations,tmp_dateTrack,timeZones);
                rainDate_u = unique(rainDate);
                
                % Now assign the rain to the correct rain day:
                for xD = 1:length(rainDate_u) % For each unique rain day:
                    posEventDay = find(eventDateRange == rainDate_u(xD)); % Position of rain day in eventDetails.
                    posStations = find(rainDate == rainDate_u(xD)); % Positions of stations with data on the rain day.
                    eventDetails(posEventDay,posIn_stations(posStations)) = dailyRain(posStations);
                    inCircleDetailsYN(posEventDay,posIn_stations(posStations)) = 1; % Assign 1 even if there are no rainfall data.
                    clear posEventDay posStations
                end; clear posIn_stations xD
            end
        end    
    end; clear xE
    
    % Simplify event-specific output (remove irrelevant stations and dates):
    tmpCheckS = find(sum(isnan(eventDetails)) < size(eventDetails,1)); % Station with at least one relevant day of data.
    tmpCheckD = find(sum(isnan(eventDetails')) < size(eventDetails,2)); % Day with at least one relevant station with data.
    eventDetails = eventDetails(tmpCheckD,tmpCheckS);

    % Now fill in the cell vectors:
    daily_rain(xT) = {eventDetails};
    daily_dates(xT) = {eventDateRange(tmpCheckD)};
    pos_stationsIn(xT) = {tmpCheckS};
    inCircle_YN(xT) = {inCircleDetailsYN(tmpCheckD,tmpCheckS)}; clear inCircleDetailsYN
    event_rain(xT) = {nansum(eventDetails)}; clear eventDetails
    stationIDs(xT) = {cellstr(stations_ghcnd(tmpCheckS,:))};
    
    lonlat(xT) = {lonlat_ghcnd(tmpCheckS,:)};
end; clear xT
