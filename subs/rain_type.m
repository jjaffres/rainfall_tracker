function [rainPeriod,leRainT,reg_vs_glob] = rain_type(rain_options,rainIDs,...
    timeZone_rain,lonR,latR,rainSource,rainTime,unitConv,rainDets)
%% rain_type.m
% This function determines what rainfall data is wanted.
% This function also checks the structure of the rainfall file(s).
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 12 May 2023

%% Check whether the rainfall grid is a global or regional dataset
if max(latR) - min(latR) == 180 && max(lonR) - min(lonR) + abs(lonR(2) - lonR(1)) == 360 
    reg_vs_glob = 'global';
elseif max(latR) - min(latR) >= 150 && max(lonR) - min(lonR) + abs(lonR(2) - lonR(1)) == 360 
    reg_vs_glob = 'near-global';
else
    reg_vs_glob = 'regional';
end

%% Check whether netCDF data position specifications have potentially an error:
if length(rainIDs) ~= unique(length(rainIDs))
    disp('At least one rainfall parameter (rainID_Lon, rainID_Lat, rainID_Time or rainID_Rain) have been specified incorrectly!')
    error('Check lines 93 to 96 in "rainfall_tracker.m" (duplicate extraction ID)!')
end

%% Check whether all data dimensionalities are as expected:
dimExp = [1 1 1 3]; % Expected dimensionality.
dimName = {'longitude' 'latitude' 'time' 'rainfall'};
nameOrig = {'rainID_Lon' 'rainID_Lat' 'rainID_Time' 'rainID_Rain'};
for x = 1:length(rainIDs) - 1 % First check the 1D parameters:
    dimNum = length(rainDets.Variables(rainIDs(x) + 1).Size);
    if length(rainDets.Variables(rainIDs(x) + 1).Size) ~= dimExp(x)
        error(['The dimensionality of "',dimName{x},'" is unexpected (= ',num2str(dimNum),...
            'D) - check ',nameOrig{x},' in rainfall_tracker.m!'])
    end; clear dimNum
end; clear x
x = 4; % Now check rainfall, which requires greater flexibility (3D vs 4D):
if length(rainDets.Variables(rainIDs(x) + 1).Size) < 3 || length(rainDets.Variables(rainIDs(x) + 1).Size) > 4
    error(['The dimensionality of "',dimName{x},'" is unexpected (= ',num2str(dimNum),...
            'D) - check ',nameOrig{x},' in rainfall_tracker.m!'])
end; clear dimExp dimName nameOrig x

%% Check rain source
if strcmpi(rainSource,'SILO') || strcmpi(rainSource,'AWAP')
    warning([rainSource,' rainfall data have non-uniform dates - with state- and season-specific timezones.'])
    disp('If your TC tracks cover more than one timezone (of the rainfall data):')
    disp('      1) Split your TC dataset into:')
    disp('         a) Specific regions (e.g. Western Australia vs Queensland); and/or')
    disp('         b) Winter vs summer (if daylight saving is applied); or')
    disp('      2) Accept that your TC data will be misaligned with rainfall by up to three hours (for Australia-wide studies).')
    if timeZone_rain < 8 || timeZone_rain > 11
        warning(['Your selected time zone is ',num2str(timeZone_rain)])
        disp(['   However, the time zone for ',rainSource,' ranges from +8 (AWST) in Western Australia...'])
        disp('   ...to +9.5 (ACST) in the Northern Territory and +10 (AEST) in Queensland...')
        disp('   ...and +11 (AEDT) in New South Wales during summer.')
        cont = input(['Do you want to stop (0) the run - or continue (1) with a time zone of ',num2str(timeZone_rain),'? --> ']);
    else
        cont = 1;
    end
elseif timeZone_rain ~= 0 && strcmp(reg_vs_glob,'regional') == 0
    warning(['Your selected timezone is ',num2str(timeZone_rain),' instead of 0 UTC (the most common time zone for global datasets).'])
    cont = input(['Do you want to stop (0) the run - or continue (1) with a time zone of ',num2str(timeZone_rain),'? --> ']);
else
    cont = 1;
end
if cont == 1
    disp('You have chosen to continue the run with the selected time zone for rainfall.')    
else % cont ~= 1
    error('You have indicated that "timeZone_rain" needs to be corrected. See line 66 in rainfall_tracker.m!')
end; clear cont

%% Test whether the rainfall file extraction assigned the correct data
if min(latR) < -90 || max(latR) > 90
    disp(['Latitude ranges from ',num2str(min(latR)),' to ',num2str(max(latR))]);
    warning('Are you sure you assigned the correct netCDF ID (order) to latitude?!')
    cont = input(['Do you want to stop (0) the run - or continue (1) with latitudes of ',num2str(min(latR)),' to ',num2str(max(latR)),'? --> ']);
elseif min(lonR) < -180 || max(lonR) > 360
    disp(['Longitude ranges from ',num2str(min(lonR)),' to ',num2str(max(lonR))]);
    warning('Are you sure you assigned the correct netCDF ID (order) to longitude?!')    
    cont = input(['Do you want to stop (0) the run - or continue (1) with longitudes of ',num2str(min(lonR)),' to ',num2str(max(lonR)),'? --> ']);
else
    cont = 1;
end
if cont ~= 1
    error('You have indicated that longitude or latitude needs be corrected. See lines 93-94 in rainfall_tracker.m!')
end; clear cont

%% Check whether correct rainfall conversion is applied.
if strcmpi(rainSource,'SILO') || strcmpi(rainSource,'AWAP')
    if unitConv ~= 1 % No rainfall conversion is applied.
        warning(['Are you sure that you want to apply a rainfall conversion for ',rainSource,'?!'])
        checkStop = 1;
    else
        checkStop = 0;
    end
elseif strcmpi(rainSource,'ERA5')
    if unitConv ~= 1000 % A rainfall conversion is requested.
        if  unitConv == 1
            warning(['Are you sure that you do not want to apply a rainfall conversion for ',rainSource,'?!'])
        else
            warning(['Are you sure that you want to apply a rainfall conversion of ',num2str(unitConv),' for ',rainSource,'?!'])
        end
        checkStop = 1;
    else
        checkStop = 0;
    end
end
if checkStop == 1
	disp(['If you have  applied an incorrect rainfall conversion for ',rainSource,' data:'])
    cont = input(['Do you want to stop (0) the run - or continue (1) with a rainfall conversion of ',num2str(unitConv),'? --> ']);
    if cont ~= 1
        error('You have indicated that the rainfall conversion (unitConv) needs be corrected. See line 73 in rainfall_tracker.m!')
    end; clear cont    
end; clear checkStop 
    
if unitConv ~= 1
    disp(['Rainfall is mutiplied by unitConv = ',num2str(unitConv),'.'])
end

%% Define wanted rainfall data
% disp('Select the variable type to extract - if not listed, adjust rain_options on line #42 before re-running script')
if strcmp(rain_options,'total')
    disp('Event rainfall - the total rainfall (per grid point) for the entire track - will be extracted.');
elseif strcmp(rain_options,'maximum')
    disp('The maximun rainfall intensity (per grid point) will be extracted, with the rain period determined by the rainfall source.');
elseif strcmp(rain_options,'raw')
    disp('For each rainfall timestep, the rainfall within the circle will be extracted.');
else    
    error('You have not specified a valid rainfall variable (cf. rain_options on line 83).')
end

% %% Check whether the longitude is in +/- 180 degrees or 360 degrees
% if min(lonR) < 0
%     % The rainfall longitude is split at the international date line (+/- 180 degrees)
% else
%     % The rainfall longitude is split at the prime meridian (0 degrees)
% end

%% Check whether the rainfall data are daily or sub-daily:
% First convert the netCDF into Matlab/GNU Octave format:
rainDate = rain_timeConverter(2021,rainTime,rainSource); % Note: yearTarget can be any year this time.

% Now extract the time step:
posDiff = find(rainDate == floor(rainDate(1)) + 1) - find(rainDate == floor(rainDate(1))); % Time steps until one day later.

leRainT = 1/posDiff; % Time (days) between successive rainfall slices.
if leRainT == 1 % posDiff == 1
    rainPeriod = 'daily';
    disp(['You are using ',rainPeriod,' ',rainSource,' rainfall data.'])
elseif posDiff == 24
    rainPeriod = 'hourly';
    disp(['You are using ',rainPeriod,' ',rainSource,' rainfall data.'])
elseif leRainT < 1
    rainPeriod = 'sub-daily';
    disp(['You are using ',rainPeriod,' ',rainSource,' rainfall data (',num2str(leRainT*24),' hours).'])
elseif isempty(leRainT)
    warning('The incorrect "time" variable was loaded for the first netCDF file!')
%     disp('1) Either ensure you only call the relevant subset (if files are in the same folder), or...')
%     disp('   ...2) move files with different formatting into another folder!')
    error('Have you applied the incorrect time ID (order) in the netCDF file (e.g. for 4D ERA5 rain files)?!')
else
    error(['Your rainfall file is neither daily or subdaily (',num2str(leRainT),' days)!'])
end
