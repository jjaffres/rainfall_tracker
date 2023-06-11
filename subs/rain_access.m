function [dailyRain,rainDate,rainInfo] = rain_access(in_dirRain,rainSource,rainPeriod,fileList_rain,...
    rainIDs,yearTarget,RfileYears_cont,lonR,latR,dateTracks_subset,tRange)
%% rain_access.m
% This function extracts rainfall data from the relevant, gridded netCDF file (set up for multi-/annual files).
% This function also checks the structure of the rainfall file(s).
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 11 May 2023

%% First identify which filename to open (based on yearTarget)
fileNum = RfileYears_cont(RfileYears_cont(:,1) == yearTarget,2);
if isempty(fileNum)
    disp(['Check whether you have rainfall data for the year ',num2str(yearTarget),'!'])
    disp(['If you do not have rainfall data for ',num2str(yearTarget),', remove relevant tracks and then re-run the script!'])
    error(['The year ',num2str(yearTarget),...
        ' for tracks of atmospheric lows does not seem to have corresponding rainfall data!'])
elseif length(fileNum) > 1
    disp(['A total of ',num2str(length(fileNum)),' ',rainSource,...
        ' files with rainfall data exist for the year ',num2str(yearTarget),'!'])
    disp('The following file(s) will be ignored:')
    x = 2;
    while x <= length(fileNum)
         disp(fileList_rain(fileNum(x)).name)
         x = x + 1;
    end; clear x
    fileNum = fileNum(1);
    disp(['Instead, only the file "',fileList_rain(fileNum).name,'" will be accessed!'])
end

%% Load the relevant netCDF file and extract its date vector
if exist('OCTAVE_VERSION','builtin') == 0 % Matlab
    inR = netcdf.open([in_dirRain,fileList_rain(fileNum).name],'nc_nowrite');
    rainTime = double(netcdf.getVar(inR,rainIDs(3))); % Open date vector.
else % GNU Octave
    inR = netcdf_open([in_dirRain,fileList_rain(fileNum).name],'nc_nowrite');
    rainTime = double(netcdf_getVar(inR,rainIDs(3))); % Open date vector.
end

%% Adjust the time based on the rain source reference time.
rainDate = rain_timeConverter(yearTarget,rainTime,rainSource);

%% Obtain netCDF-specific file details (NaNs, scale factor and applied offset)
% Extract the rainfall data attributes.
% SILO:     NaNs: -32767; scale_factor = 0.1; add_offset = 3276.5.
nInfo = ncinfo([in_dirRain,fileList_rain(fileNum).name]);
varNames = {nInfo.Variables.Name}; 
try
    rainNaNs = double(ncreadatt([in_dirRain,fileList_rain(fileNum).name],char(varNames(rainIDs(4) + 1)),'_FillValue'));
catch
    warning('Have you called rain files with mixed formatting (e.g. 3D vs 4D ERA5)?!')
    disp('If so, 1) either ensure you only call the relevant subset (if files are in the same folder), or...')
    disp('    ...2) move files with different formatting into another folder!')
    rainNaNs = double(ncreadatt([in_dirRain,fileList_rain(fileNum).name],char(varNames(rainIDs(4) + 1)),'_FillValue'));
end
try % Check if a scaling factor is applied in the netCDF file:
    rainScaling = double(ncreadatt([in_dirRain,fileList_rain(fileNum).name],char(varNames(rainIDs(4) + 1)),'scale_factor'));
catch
    rainScaling = 1; % No scaling is applied in the netCDF file. Hence, set the muliplier to 1.
end
try % Check if an offset is applied in the netCDF file:
    rainOffset = double(ncreadatt([in_dirRain,fileList_rain(fileNum).name],char(varNames(rainIDs(4) + 1)),'add_offset'));
catch
    rainOffset = 0; % No offset is applied in the netCDF file. Hence, set the addition to 1.
end
rainInfo = [rainNaNs rainScaling rainOffset]; clear varNames nInfo rainNaNs rainOffset rainScaling

%% Define wanted rain subset:
% Especially hourly/sub-daily rainfall (with an entire year per file) are too large to open in its entirety.
% Thus only extract a (temporal) subset relevant for the ALPS tracks:
if strcmp(rainPeriod,'daily') % Daily rainfall requires the extraction of the first full rainday: 
    posR1 = find(rainDate >= floor(tRange(1)),1,'first'); % Find first rain date within ALPS range.
    posR2 = find(rainDate <= tRange(2),1,'last'); % Find last rain date within ALPS range.
else %% Sub-daily rainfall is covered by the first subsequent time-slice (unlike daily):
    posR1 = find(rainDate >= tRange(1),1,'first'); % Find first rain date within ALPS range.
    posR2 = find(rainDate >= tRange(2),1,'first'); % Find last rain date within ALPS range.
end
if isempty(posR2) % An ALPS over new year - apply the final position of the year.
    posR2 = length(rainDate);
end
rainDate = rainDate(posR1:posR2); % Reduced rainfall dates

%% Now open the reduced rainfall data (as per extended time vector)
% Load the relevant netCDF file and extract its rainfall data and date vector:
% Warning: Recent ERA5 years (for example) have 4D rainfall datasets!
if exist('OCTAVE_VERSION','builtin') == 0 % Matlab
    try
        dailyRain = netcdf.getVar(inR,rainIDs(4),[0 0 posR1 - 1],[length(lonR) length(latR) posR2 - posR1 + 1]); % Open partial rainfall matrix.
    catch % Especially ERA5 files are not always formatted consistently. Older files are in 3D but newer files may have 4D data:
        dailyRain = netcdf.getVar(inR,rainIDs(4),[0 0 0 posR1 - 1],[length(lonR) length(latR) 1 posR2 - posR1 + 1]); 
        dailyRain = squeeze(dailyRain); % Open partial rainfall matrix.  
        disp(['Rain data in ',fileList_rain(fileNum).name,' are 4D (rather than the usual 3D format)']) 
    end
    netcdf.close(inR);
else % GNU Octave
    try
        dailyRain = netcdf_getVar(inR,rainIDs(4),[0 0 posR1 - 1],[length(lonR) length(latR) posR2 - posR1 + 1]);  
    catch % Especially ERA5 files are not always formatted consistently. Older files are in 3D but newer files may have 4D data:
        dailyRain = netcdf_getVar(inR,rainIDs(4),[0 0 0 posR1 - 1],[length(lonR) length(latR) 1 posR2 - posR1 + 1]); 
        dailyRain = squeeze(dailyRain);
        disp(['Rain data in ',fileList_rain(fileNum).name,' are 4D (rather than the usual 3D format)']) 
    end
    netcdf_close(inR);
end; clear inR 
dailyRain = double(dailyRain);
