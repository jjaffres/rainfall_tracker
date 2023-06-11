%% rainfall_tracker.m
%
% Copyright (C) 2023 by Jasmine B.D. Jaffrés(1) and J.L. Gray(2)
% (1) C&R Consulting, Australia (http://candrconsulting.com.au/).
% (2) Central Queensland University, Australia.
%
% Citation: Jaffrés, J.B.D. and Gray, J.L. (2023) Chasing rainfall: estimating
%           event precipitation along tracks of tropical cyclones via reanalysis 
%           data and in-situ gauges.
%
% This script extracts the rainfall within the chosen distance from the centre of 
%       each position along the track of all individual atmospheric low-pressure systems (ALPSs).
% This script can be used in either MATLAB or GNU Octave (v4.2.0).
%
% This script can easily be modified to suit your needs, e.g.: 
%       - Import a regional or global, gridded rainfall dataset.
%       - Extract total event rainfall, maximum rainfall intensity or rainfall for individual times.
%       - Import a track dataset of low-pressure systems in a non-UTC time zone.
%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% You can redistribute this script and/or modify it under the terms of the
% GNU General Public License as published by the Free Software Foundation,
% either version 3 of the License, or (at your option) any later version.
%
% This script is distributed in the hope that it will be useful, but WITHOUT
% ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
% FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 4 Jan 2023
clear

%% Pre-run modifications
%% Directory
in_dirTracks = '.\data\'; % Your input directory for the track data
in_dirRain = '.\data\'; % Your input directory for your rainfall data
out_dir = '.\output\'; % Your output directory

%% Define attributes of atmospheric lows
fileNames_tracks = '2023articleTCs.csv'; % Full name of your track file.
headerRows_tracks = 1;  % Only required for GNU Octave. Default is one header row (change, if needed). 
timeZone_tracks = 0;    % Time zone with respect to UTC. UTC+0 is generally standard.
                            % Examples: 1) If UTC+0, set to 0; 2) if AEST, set to +10.
                            % Note: If the time zone is variable, either split up the track dataset 
                            %       and run each time zone separately or select the most appropriate time zone.                    

%% Define which column corresponds to each track information
trackID = 1;      % Define column with unique track identifier.
trackID_lon = 2;  % Define column with track longitude.
trackID_lat = 3;  % Define column with track latitude.
trackID_year = 4; % Define column with track year.
trackID_month = 5; % Define column with track month.
trackID_day = 6;  % Define column with track day.
trackID_hour = 7; % Define column with track hour.
                  % Note: Set to 0, if you have no separate column for hours (e.g.
                  %       if already incorporated with the "day" variable).

%% Define rainfall attributes
rainSource = 'ERA5'; % Options (tested):  
                     % AWAP (regional Australian dataset) - daily data in yearly files.
                     % SILO (regional Australian dataset) - daily data in yearly files.
                     % ERA5 (global dataset) - hourly data in yearly files.
fileNames_rain = '*ERA5*.nc'; % Name(s) of your rainfall files. 
                                    % Use a wildcard (*) if there are several files 
                                    %       (e.g. '*.daily_rain.nc' for SILO data).
                                    %       (e.g. 'AWAP_daily_*.nc' for AWAP data).
                                    %       (e.g. '*ERA5*.nc' for ERA5 data).
timeZone_rain = 0; % Time zone with respect to UTC.
                    % If UTC, set to 0 (e.g. global datasets like ERA5).
                    % If AEST, set to +10.
                    % If timezone is variable (e.g. for SILO), either: 
                    %       1) Split up the track dataset into relevant timezones and run 
                    %          the subfiles separately for each relevant time zone; or 
                    %       2) Select most appropriate time zone for the rainfall data.                    
unitConv = 1000; % Do you want to apply a unit conversion? 
             %      = 1 (default): The original unit is kept (e.g. metres for ERA5).
             %      = 1000: For example, change from metres to mm (e.g. for ERA5).
             %      = 1/1000: For example, change from mm to metres.
             % Note: unitConv is separate to the scaling applied within some of the netCDF files.
rainRadius = 500; % Define the applicable rainfall radius around the atmospheric low.
sideWin = 1; % Define the side window (hours before/after track position) to be 
             %      applied for the rainfall extraction.
             % = 0 (default): Rain is only extracted for the grid time most closely.
             %                matching the track position (e.g. one 3-hourly period for SILO).
             % = 2:           A total window of 4 hours (2 hours on either side).
             %                --> Up to three 3-hour periods for SILO, 1-2 periods for daily rainfall data.            
rain_options = 'raw'; % Define which rainfall output type you want to save.
                    % Options:  total:   sum of all rainfall over the period of the track.
                    %           maximum: maximum rainfall intensity per grid point.
                    %           raw:     individual outputs for every rain time period.
                    
%% Define wanted rainfall output (see rainfall_info.xlsx)
% Provide netCDF ID (order) for each data type.
% Note: netCDF files are 0-indexed, i.e. ID (order) of first variable in any netCDF file is 0!
rainID_Lon = 0; % Define ID of longitude in netCDF file
rainID_Lat = 1; % Define ID of latitude in netCDF file
rainID_Time = 2; % Define ID of time in netCDF file
rainID_Rain = 3; % Define ID of rainfall in netCDF file

outName_suffix = 'test'; % Stipulate the suffix for the output rainfall file (.mat format).
                     % Note: The file prefix is "eventRain_" followed by your
                     %       chosen rainSource (see line 54). For example, if
                     %       left blank ('') and SILO is the rainfall source,
                     %       the name will be: "eventRain_SILO_.mat".
                     
%% End of user-defined parameters                        
disp('User input is now complete and your rainfall data will now be collated.')
TdataCols = [trackID; trackID_lon; trackID_lat; trackID_year; trackID_month; trackID_day; trackID_hour]; % Identification of all relevant track data columns.
trackInfo = [timeZone_tracks headerRows_tracks]; % Time zone and number of header rows for track file.
rainIDs = [rainID_Lon; rainID_Lat; rainID_Time; rainID_Rain]; % Identification of all relevant rainfall data.
clear trackID trackID_day trackID_hour trackID_lat trackID_lon trackID_month trackID_year
clear rainID_Lat rainID_Lon rainID_Rain rainID_Time headerRows_tracks timeZone_tracks             
                    
%% Extract target rainfall
addpath('.\subs\'); % Location of subroutines
rain_output = rain_aggregate(in_dirRain,fileNames_rain,rain_options,unitConv,rainRadius,sideWin,...
    rainIDs,rainSource,timeZone_rain,in_dirTracks,fileNames_tracks,TdataCols,trackInfo,out_dir,outName_suffix); % ,reg_vs_glob
