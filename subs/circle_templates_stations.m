function cellCount = circle_templates_stations(rainRadius,lonR,latR,posLatU)
%% circle_templates_stations.m
% This function generates a circle at a specific radius (rainRadius) to track the rainfall along a track.
% The haversine formula (cf. haversine.m) is applied to convert between lat/lon degrees and kilometres.
%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray 15 Jan 2022
latRel = latR(posLatU); % All unique latitudes

%% Haversine formula 
lonRad = lonR * pi/180; latRad = latR * pi/180; % Radial longitude and latitude.
R = 6371000; % Radius of Earth in meters.
% Minimum number of grids at any latitude to remain within rainRadius:
min_lonGrids = floor(rainRadius/(100*(lonR(2) - lonR(1)))*0.9); % min_lonGrids ~= 90 km; 

% Cell count per latitudinal position of low centre:
% cellCount dim1: All relevant latitudes; dim2: all unique latitudinal track positions.
cellCount = NaN(length(latR),length(latRel)); % == 0 if only reference lon(i.e. low/TC lon) is within circle; == NaN if outside
for xL = 1:length(posLatU)
    xt = posLatU(xL); % Positions for the full latitudinal grid.
    posNow = find(posLatU == xt); % Slices for the reduced (subset) latitudinal positions (i.e. low positions only).
    % First obtain the grid distance directly east from the low/TC centre:
    dist = haversine(lonRad,latRad,min_lonGrids,xt,xt,R); % Now apply the haversine formula! 
    
    tmp_lonGrids = min_lonGrids;    
    while dist < rainRadius % && tmp_lonGrids < length(lonR)
        tmp_lonGrids = tmp_lonGrids + 1;
        if tmp_lonGrids > length(lonR)/2 % If the entire longitudinal range is within rainRadius (i.e. half on either side):
            break % Stop the while-loop.
        end        
        dist = haversine(lonRad,latRad,tmp_lonGrids,xt,xt,R); % Now apply the haversine formula!    
    end
    if tmp_lonGrids > length(lonR)/2 % If the entire longitudinal range is within rainRadius (i.e. half on either side): 
        cellCount(xt,posNow) = tmp_lonGrids - 1;
    else % If only part of the longitudinal range is within rainRadius:
        cellCount(xt,posNow) = tmp_lonGrids - 2; % -2 because lonGrids == 1 would be at the track location (i.e. 0 count).
    end
    
    for xd = xt + 1:length(latRad)
        dist = haversine(lonRad,latRad,tmp_lonGrids,xt,xd,R); % Now apply the haversine formula.
        if tmp_lonGrids > 1 % Only go into subloop if not already == 1
            % While moving towards the equator previous tmp_lonGrids will be outside the grid.
            while dist > rainRadius && tmp_lonGrids > 1 
                tmp_lonGrids = tmp_lonGrids - 1 ;
                dist = haversine(lonRad,latRad,tmp_lonGrids,xt,xd,R); % Now apply the haversine formula! 
            end
            if dist <= rainRadius % Only add grid number if within radius (otherwise, keep NaN)
                cellCount(xd,posNow) = tmp_lonGrids - 1;
            end
        elseif dist < rainRadius
                if tmp_lonGrids == 720 || tmp_lonGrids == 722; stop2; end
            cellCount(xd,posNow) = tmp_lonGrids - 1;
        end
    end; clear xd 
    tmp_lonGrids = cellCount(xt,posNow) + 2;  
    if tmp_lonGrids > length(lonR) % tmp_lonGrids exceeds the longitudinal number of grid point! 
        tmp_lonGrids = tmp_lonGrids - 1;
    end
    
    for xd = xt - 1:-1:1
        dist = haversine(lonRad,latRad,tmp_lonGrids,xt,xd,R); % Now apply the haversine formula! 
        if tmp_lonGrids > 1 % Only go into subloop if not already == 1
            % While moving towards the equator previous tmp_lonGrids will be outside the grid.
            while dist > rainRadius && tmp_lonGrids > 1
                tmp_lonGrids = tmp_lonGrids - 1 ;
                dist = haversine(lonRad,latRad,tmp_lonGrids,xt,xd,R); % Now apply the haversine formula! 
            end
            if dist <= rainRadius % Only add grid number if within radius (otherwise, keep NaN).
                if tmp_lonGrids - 1 > floor(length(lonR)/2) % If the entire longitudinal range is within rainRadius (i.e. half on either side):
                    cellCount(xd,posNow) = floor(length(lonR)/2); % Half of length(lonR).
                else
                    cellCount(xd,posNow) = tmp_lonGrids - 1;
                end
            end
        elseif dist < rainRadius
                if tmp_lonGrids == 720 || tmp_lonGrids == 722; stop4; end
            cellCount(xd,posNow) = tmp_lonGrids - 1;
        end
    end; clear xd xt
end; clear xL
