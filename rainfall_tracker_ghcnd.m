%% rainfall_tracker_ghcnd.m
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
% This script extracts daily rainfall data from relevant stations in the GHCN-daily network.
% Note: First run ghcnd_access.m to convert the .dly files into netCDF: https://github.com/jjaffres/ghcnd_access
%       Citation for ghcnd_access.m: 
%       Jaffrés, J.B.D. (2019) GHCN-Daily: a treasure trove of climate data awaiting
%       discovery. Computers & Geosciences 122, 35-44.
%
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
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 3 Jan 2023
clear

%% Pre-run modifications.
%% Directories:
in_dirTracks = '.\data\'; % Your input directory for the track data
in_dirRain = '.\data\'; % Your input directory for your rainfall data
out_dir = '.\output\'; % Your output directory

%% Define attributes of atmospheric lows.
fileNames_tracks = '2023articleTCs.csv'; % Full name of your track file.
headerRows_tracks = 1;  % Only required for GNU Octave. Default is one header row (change, if needed). 
timeZone_tracks = 0;    % Time zone with respect to UTC. UTC+0 is generally standard.
                            % Examples: 1) If UTC+0, set to 0; 2) if AEST, set to +10.
                            % Note: If the time zone is variable, either split up the track dataset 
                            %       and run each time zone separately or select the most appropriate time zone.

%% Define which column corresponds to each track information.
trackID = 1;      % Define column with unique track identifier.
trackID_lon = 2;  % Define column with track longitude.
trackID_lat = 3;  % Define column with track latitude.
trackID_year = 4; % Define column with track year.
trackID_month = 5; % Define column with track month.
trackID_day = 6;  % Define column with track day.
trackID_hour = 7; % Define column with track hour.
                  % Note: Set to 0, if you have no separate column for hours (e.g.
                  %       if already incorporated with the "day" variable).
                  
%% Define rainfall attributes of GHCN-daily data.
fileNames_rain = 'GHCND_day_PRCP*.mat'; % Name(s) of your rainfall files. 
                                    % Use a wildcard (*) if there are several files 
                                    %       (e.g. 'GHCND_day_PRCP*.nc' for multiple GHCN-daily files).
timeZone_rain = 10; % Time zone with respect to UTC.
                    % If UTC, set to 0.
                    % If AEST, set to +10.
                    % If timezone is variable), either: 
                    %       1) Split up the track dataset into relevant timezones and run 
                    %          the subfiles separately for each relevant time zone; or 
                    %       2) Select most appropriate time zone for the rainfall data.                    
rainRadius = 500; % Define the applicable rainfall radius around the atmospheric low.
sideWin = 1; % Define the side window (hours before/after track position) to be 
             %      applied for the rainfall extraction.
             % = 0 (default): Rain is only extracted for the station time most closely
             %                matching the track position (i.e. one daily period).
             % = 2:           A total window of 4 hours (2 hours on either side).
             %                --> Up to two days for daily rainfall data.
                    
%% Define wanted rainfall output name (suffix only).
outName_suffix = 'test'; % Stipulate the suffix for the output rainfall file (.mat format).
                     % If left blank (''), the name will be: "eventRain_ghcnd_.mat".
                     % Note: The default file prefix is "eventRain_ghcnd_".
                     
%% End of user-defined parameters.                   
disp('User input is now complete and your rainfall data will now be collated.')
TdataCols = [trackID; trackID_lon; trackID_lat; trackID_year; trackID_month; trackID_day; trackID_hour]; % Identification of all relevant track data columns.
trackInfo = [timeZone_tracks headerRows_tracks]; % Time zone and number of header rows for track file.
clear trackID trackID_day trackID_hour trackID_lat trackID_lon trackID_month trackID_year
clear headerRows_tracks timeZone_tracks

%% Extract target rainfall.
addpath('.\subs\'); % Location of subroutines
event_rain = rain_aggregate_ghcnd(in_dirRain,fileNames_rain,rainRadius,sideWin,...
    timeZone_rain,in_dirTracks,fileNames_tracks,TdataCols,trackInfo,out_dir,outName_suffix);
