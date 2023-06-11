function rainDate = rain_timeConverter(yearTarget,rainTime,rainSource)
%% rain_timeConverter.m
% This function converts the date of the rainfall netCDF into MATLAB format.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 4 Jan 2023

%% First convert the netCDF into MATLAB format:
%% Adjust the time based on the rain source reference time.
% Check rain source
if strcmpi(rainSource,'SILO')
    % Time is with respect to days since 1 January of the file year (e.g. 1/1/2020).
    % Open netcdf of the year that equals the yearTarget:
    rainDate = datenum(yearTarget,1,1) + rainTime; % rainTime: Days since 1 January.
elseif strcmpi(rainSource,'AWAP')
    % Time is with respect to days since 1/1/1850 (at 9 a.m.).
    % Note: Original AWAP (daily) time is already at 9 a.m. - which is now reverted to 0:00 instead: 
    disp([rainSource,' rainfall data cover 9 a.m. the previous day to 9 a.m. of "today".'])
    disp('      However, all that rain is assigned to "today" (i.e. in midnight to midnight format)...')
    disp('              ...to facilitate the extraction of total rainfall per (daily) rainfall period.')
    rainDate = datenum(1850,1,1) + rainTime - 9/24; % rainTime: Days since 09:00 1 Jan 1850.
elseif strcmpi(rainSource,'ERA5')
    % Time is with respect to hours since 1/1/1900.
    rainDate = datenum(1900,1,1) + rainTime/24; % rainTime: Hours since 1 Jan 1900.
else
    stop
end
