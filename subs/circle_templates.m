function [radiusArea,rainInfo_test,lonR,latR,latRexp,midPoint,rainPeriod,leRainT,reg_vs_glob] = ...
    circle_templates(in_dirRain,fileList_rain,rain_options,timeZone_rain,...
    rainRadius,rainIDs,rainSource,unitConv,ALPSlats,out_dir)
%% circle_templates.m
% This function generates a circle at a specific radius (rainRadius) to track the rainfall along a track.
% The haversine formula (cf. haversine.m) is applied to convert between lat/lon degrees and kilometres.
%
% rainIDs: Location (in NetCDF file) of the required rainfall data: [longitude, latitude, time, rainfall]
%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 12 May 2023

% Load the rainfall data (one slice)
        % ncdisp([in_dirRain,fileList_rain(end).name]) % Visually determine the size.
if exist('OCTAVE_VERSION','builtin') == 0 % Matlab
    inR = netcdf.open([in_dirRain,fileList_rain(end).name],'nc_nowrite');
    lonR = netcdf.getVar(inR,rainIDs(1)); latR = netcdf.getVar(inR,rainIDs(2));
    rainTime = double(netcdf.getVar(inR,rainIDs(3))); 
    netcdf.close(inR);
else % GNU Octave
    pkg load netcdf; pkg load io; pkg load nan; pkg load statistics % Load required GNU Octave packages
    inR = netcdf_open([in_dirRain,fileList_rain(end).name],'nowrite');
    lonR = netcdf_getVar(inR,rainIDs(1)); latR = netcdf_getVar(inR,rainIDs(2));
    rainTime = double(netcdf_getVar(inR,rainIDs(3))); 
    netcdf_close(inR);
end; clear inR

%% Check that the rainfall input is in order.
% Extract the rain file details:
rainDets = ncinfo([in_dirRain,fileList_rain(end).name]); % length(rainDets.Variables(rainIDs(4) + 1).Size)
[rainPeriod,leRainT,reg_vs_glob] = rain_type(rain_options,rainIDs,...
    timeZone_rain,lonR,latR,rainSource,rainTime,unitConv,rainDets);

%% Obtain NetCDF-specific file details (NaNs, scale factor and applied offset)
% Extract the rainfall data attributes.
% SILO:     NaNs: -32767; scale_factor = 0.1; add_offset = 3276.5.
nInfo = ncinfo([in_dirRain,fileList_rain(end).name]);
varNames = {nInfo.Variables.Name}; 
rainNaNs = double(ncreadatt([in_dirRain,fileList_rain(end).name],char(varNames(rainIDs(4) + 1)),'_FillValue'));
try % Check if a scaling factor is applied in the NetCDF file:
    rainScaling = double(ncreadatt([in_dirRain,fileList_rain(end).name],char(varNames(rainIDs(4) + 1)),'scale_factor'));
catch
    rainScaling = 1; % No scaling is applied in the NetCDF file. Hence, set the muliplier to 1.
end
try % Check if an offset is applied in the NetCDF file:
    rainOffset = double(ncreadatt([in_dirRain,fileList_rain(end).name],char(varNames(rainIDs(4) + 1)),'add_offset'));
catch
    rainOffset = 0; % No offset is applied in the NetCDF file. Hence, set the addition to 1.
end
rainInfo_test = [rainNaNs rainScaling rainOffset]; clear varNames nInfo rainNaNs rainOffset rainScaling

%% Check if the rain grid latitude requires expanding 
% I.e. ALPS tracks may have some locations outside the latitudinal rain range.
if min(ALPSlats) < min(latR) || max(ALPSlats) > max(latR)
    disp('ALPS tracks are outside the rain grid range and the template areas will thus be expanded.')
    expYes = 1;
    
    % First expand latR without altering the original values:
    latRexp = latR; % The expanded latitudinal vector for rainfall (for track matching only)
    pos1 = find(latR == min(latR)); % Position of lowest latitude
    pos2 = find(latR == min(latR) + 1); % Position of lowest latitude + 1 degree
    stepDist = 1/(pos2 - pos1); % grid step size to be applied
    
    if min(ALPSlats) < min(latR)
        latVec = min(latR):-stepDist:floor(min(ALPSlats));
        posNearest = knnsearch(latVec',min(ALPSlats));
        latVec = latVec(2:posNearest)';
        
        % Now ensure that the additional vector is attached in the correct direction:
        if pos1 == 1 % The lowest value is at the top of the vector (i.e. ascending values)
            % latVec needs to be reversed before merging:
            latRexp = [flip(latVec); latRexp];
        else % if pos1 == length(latR) % The lowest value is NOT at the top of the vector (i.e. descending values)
            latRexp = [latRexp; latVec];
        end; clear latVec posNearest
    end
    if max(ALPSlats) > max(latR)
        latVec = max(latR):stepDist:ceil(max(ALPSlats));
        posNearest = knnsearch(latVec',max(ALPSlats));
        latVec = latVec(2:posNearest)';
        
        % Now ensure that the additional vector is attached in the correct direction:
        if pos1 == 1 % The lowest value is at the top of the vector (i.e. ascending values)
            latRexp = [latRexp; latVec];
        else % if pos1 == length(latR) % The lowest value is NOT at the top of the vector (i.e. descending values)
            % latVec needs to be reversed before merging:
            latRexp = [flip(latVec); latRexp];
        end; clear latVec posNearest
    end; clear pos1 pos2
else % Keep original latR
    expYes = 0;
    latRexp = latR; % The (in this case not) expanded latitudinal vector for rainfall (for track matching only)
end

%% Haversine formula 
q = pi/180;
lonRad = lonR * q; latRad = latRexp * q; % Radial longitude and latitude.
R = 6371000; % Radius of Earth in meters.
% Minimum number of grids at any latitude to remain within rainRadius.
min_lonGrids = floor(rainRadius/(100*(lonR(2) - lonR(1)))*0.9); % Minimum number of grids at any latitude to remain within rainRadius.

% Cell count per latitudinal position of low centre:
cellCount = NaN(length(latRexp)); % == 0 if only reference lon(i.e. low/TC lon) is within circle; == NaN if outside
for xt = 1:length(latRexp)
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
    % If the entire longitudinal range is within rainRadius (i.e. half on either side): 
    if tmp_lonGrids > length(lonR)/2 
        cellCount(xt,xt) = tmp_lonGrids - 1;
    else % If only part of the longitudinal range is within rainRadius:
        cellCount(xt,xt) = tmp_lonGrids - 2;
    end
    
    for xd = xt + 1:length(latRad)
        dist = haversine(lonRad,latRad,tmp_lonGrids,xt,xd,R); % Now apply the haversine formula! 
        if tmp_lonGrids > 1 % Only go into subloop if not already == 1
            % While moving towards the equator previous tmp_lonGrids will be outside the grid.
            while dist > rainRadius && tmp_lonGrids > 1 
                tmp_lonGrids = tmp_lonGrids - 1 ;
                dist = haversine(lonRad,latRad,tmp_lonGrids,xt,xd,R); % Now apply the haversine formula! 
            end
            if dist <= rainRadius % Only add grid number if within radius (otherwise, keep NaN)
                if tmp_lonGrids == 720 || tmp_lonGrids == 722; stop1; end
                cellCount(xd,xt) = tmp_lonGrids - 1;
            end
        elseif dist < rainRadius
                if tmp_lonGrids == 720 || tmp_lonGrids == 722; stop2; end
            cellCount(xd,xt) = tmp_lonGrids - 1;
        end
    end; clear xd 
    
    tmp_lonGrids = cellCount(xt,xt) + 2;  
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
                    cellCount(xd,xt) = floor(length(lonR)/2); % Half of length(lonR).
                else
                    cellCount(xd,xt) = tmp_lonGrids - 1;
                end
            end
        elseif dist < rainRadius
                if tmp_lonGrids == 720 || tmp_lonGrids == 722; stop4; end
            cellCount(xd,xt) = tmp_lonGrids - 1;
        end
    end; clear xd 
end

%% If the latitudinal vector was expanded, check if it can be reduced again based on the applied rainRadius.
if expYes == 1
    pos1match = find(latRexp == latR(1)); % First position corresponding to original latR.
    pos2match = find(latRexp == latR(end)); % Last position corresponding to original latR.
    
    % Trim the expanded latitude to now only include latR (but keep a slice per latRexp):
    cellCount = cellCount(pos1match:pos2match,:);
    
    % Check which expanded latitude circles reach the rainfall grid region.
    areaRel = nanmax(cellCount); 
    p1 = find(~isnan(areaRel),1,'first');
    p2 = find(~isnan(areaRel),1,'last');
    % Note: Need to keep one extra latitude on both sides to ensure that
    %       extreme track positions will not get an area:
    if p1 > 1
        p1 = p1 - 1;
    end
    if p2 < length(areaRel) % length(areaRel) represents the maximum value per slice (hence, the number of slices). 
        p2 = p2 + 1;
    end; clear areaRel
    
    % Reduce both latRexp and cellCount to relevant latitudes:
    cellCount = cellCount(:,p1:p2);
    latRexp = latRexp(p1:p2); clear p1 p2
end; clear expYes

%% Now fill in the logical 3-D matrix
% Create filled circle in the centre of longitudinal range (i.e. the template
%       TC centre is always at the longitudinal mid-point).
midPoint = floor(length(lonR)/2); % Longitudinal mid-point.
% Empty 3D matrix - one template per (extended) latitude:
radiusArea = false(length(lonR),length(latR),length(latRexp)); 
    % The first two dimensions of radiusArea match the matrix of the rainfall grid.
    % The third dimension represents individual latitudinal slices.
for xS = 1:length(latRexp) % For each slice.
    for xLat = 1:length(latR)
        le = cellCount(xLat,xS); % Number of cells from low (east and west from low centre).
        if ~isnan(le)
            if midPoint - le == 0 % If the entire longitude is within rainRadius (and length(lonR) is an odd number): 
                radiusArea(midPoint - (le - 1):midPoint + le,xLat,xS) = 1;
            else
                radiusArea(midPoint - le:midPoint + le,xLat,xS) = 1;
            end
        end; clear le
    end; clear xLat
end; clear xS
