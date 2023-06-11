function [gauge_infos,gauge_rain,gauge_time] = ghcnd_load(in_dirRain,fileNames_rain)
%% ghcnd_load.m
% This function loads the GHCN-daily data.
% Note: The user should previously have compiled the data with the separate ghcnd_access toolbox.
%       See Jaffrés, J.B.D. (2019) GHCN-Daily: a treasure trove of climate data awaiting discovery. 
%           Computers & Geosciences 122, 35-44.
%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 3 Jan 2023

%% Extract positional information for GHCN-daily data
fileList_rain = dir([in_dirRain,fileNames_rain]); % Obtain the full list of relevant rainfall files.
if size(fileList_rain,1) == 0
    error(['The rainfall file list is empty. Check the path (',in_dirRain,') and filename (',fileNames_rain,')!'])
elseif size(fileList_rain,1) > 1
    warning('Are you aware that there is more than one GHCN-daily file?')
    disp('Only the first file will be accessed!')
else
    disp('Now opening the GHCN-daily data - compiled with the separate ghcnd_access toolbox (Jaffrés, 2019).') 
end

tmpInfo = load([in_dirRain,fileList_rain(1).name],'ghcnd_gauge_info*'); % Load all station information files.
tmpInfoID = fieldnames(tmpInfo);
tmpRain = load([in_dirRain,fileList_rain(1).name],'ghcnd_data*'); % Load all station data.
tmpRainID = fieldnames(tmpRain);
tmpTime = load([in_dirRain,fileList_rain(1).name],'ghcnd_date_indiv*'); % Load all individual date vectors.
tmpTimeID = fieldnames(tmpTime);

if length(tmpInfoID) == 1
    gauge_infos = tmpInfo.(tmpInfoID{:});
    gauge_rain = tmpRain.(tmpRainID{:});
    gauge_time = tmpTime.(tmpTimeID{:});
elseif length(tmpInfoID) > 1
    gauge_infos = cell(40000*length(tmpInfoID),6); % Based on the Sep-2021 download, the largest sub-matrix has over 38k rows.
    gauge_rain = cell(40000*length(tmpInfoID),1);
    gauge_time = cell(40000*length(tmpInfoID),1);
    posCount = 1;
    for x = 1:length(tmpInfoID)
        tmpImat = tmpInfo.(tmpInfoID{x});
        gauge_infos(posCount:posCount + size(tmpImat,1) - 1,:) = tmpImat;
        tmpRmat = tmpRain.(tmpRainID{x});
        gauge_rain(posCount:posCount + size(tmpRmat,1) - 1,:) = tmpRmat;
        tmpTmat = tmpTime.(tmpTimeID{x});
        gauge_time(posCount:posCount + size(tmpTmat,1) - 1,:) = tmpTmat;
        posCount = posCount + size(tmpImat,1); clear tmpImat tmpRmat tmpTmat
    end; clear x
    gauge_infos(posCount:end,:) = []; % Remove excess rows
    gauge_rain(posCount:end,:) = []; % Remove excess rows
    gauge_time(posCount:end) = []; % Remove excess rows
    clear posCount
else
    warning('Have you first applied ghcnd_access to aggregate the GHCN-daily .dly data?')
    error('Your file does not contain any variables in the ghcnd_gauge_info* format.')
end
