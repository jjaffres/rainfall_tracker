function [dateTracksExpSorted,track_numDataExpSort,trackIDs_allExpSort] = ...
    window_apply(sideWin,dateTracks_shifted,track_numData,trackIDs_all,rainStep_hrs)
%% window_apply.m
% This function applies the chosen side window to all ALPS track positions.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 4 Jan 2023

%% Check if a side window needs to be invoked:
% if sideWin ~= 0 % A side window is applied.
% if sideWin == 0 % No side window is applied. Thus keep original data.
disp(['You have elected to apply a side window (',num2str(sideWin),' hours on either side of each track position)'])
% Note: Data in daily format and a side window of less than 12 hours (i.e. less
%       than a 1-day total) do not require special treatment.
numPeriods = ceil(sideWin/rainStep_hrs); 
%       1) e.g. GHCN-daily is in daily (24 hour) format. Hence, each multiple 
%                         (of 24) of the side window requires a separate date copy.
%       2) Sub-daily data (e.g. 3-hourly), with a sideWin = 4 would
%                         require additional copies.
    
le = size(track_numData,1);
dateTracksExp_shifted = [dateTracks_shifted; NaN(le*numPeriods*2,1)];
track_numDataExp = repmat(track_numData,numPeriods*2 + 1,1); % Apply repmat!!!
trackIDs_allExp = repmat(trackIDs_all,numPeriods*2 + 1,1); % Apply repmat!!! 
for x = 1:numPeriods % Number of additional periods for which to create positional copies for.
    posR1 = le*(x*2 - 1) + 1; % Starting position for addition of preceding time.
    posR2 = le*(x*2 + 1); % Last position for addition of subsequent time.
    if x < numPeriods % Shift by the multiple of rainStep_hrs hours:
        dateTracksExp_shifted(posR1:posR2) = [dateTracks_shifted - x; dateTracks_shifted + x];
    else % Shift by the full period (sideWin) - and ensure to convert hours to days (i.e. Matlab/Octave date unit).
        dateTracksExp_shifted(posR1:posR2) = [dateTracks_shifted - sideWin/24; dateTracks_shifted + sideWin/24];
    end        
end; clear le numPeriods
clear dateTracks_shifted track_numData trackIDs_all

%% Now sort the data into time order
% ...because first and last two time stamps will later be accessed for the date range
[dateTracksExpSorted,dataSort] = sort(dateTracksExp_shifted); 
track_numDataExpSort = track_numDataExp(dataSort,:);
trackIDs_allExpSort = trackIDs_allExp(dataSort); 
clear dataSort dateTracksExp_shifted track_numDataExp trackIDs_allExp
