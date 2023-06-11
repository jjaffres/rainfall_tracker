function track_check(TC_subset,date_tracks,trackIDs_all,out_dir,fileNames_tracks,trackInfo)
%% track_check.m
% This function checks the structure of the track file.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 12 May 2023

%% Test whether the extracted, positional TC data are correct
whichData = '';
if min(TC_subset(:,1)) < -180 || max(TC_subset(:,1)) > 360 % Check longitude
    disp(['Longitude ranges from ',num2str(min(TC_subset(:,1))),' to ',num2str( max(TC_subset(:,1)))]);
    warning('Are you sure you assigned the correct .csv column to longitude?!')
    scriptCheck = input('Do you want to continue (1) or stop the run (0)? --> '); whichData = 'longitude';
elseif min(TC_subset(:,2)) < -90 || max(TC_subset(:,2)) > 90 % Check latitude
    disp(['Latitude ranges from ',num2str(min(TC_subset(:,2))),' to ',num2str( max(TC_subset(:,2)))]);
    warning('Are you sure you assigned the correct .csv column to latitude?!')
    scriptCheck = input('Do you want to continue (1) or stop the run (0)? --> '); whichData = 'latitude';
end
if strcmp(whichData,'') ~= 1 % If positional data issues were identified:
    if scriptCheck == 1
        disp('You have chosen to continue the run.')    
    else % if scriptCheck == 0
        error(['Fix the ',whichData,' issues in the track file (or column assignment).'])
    end
end

%% Check if dates for individual tracks are consistently monotonically increasing.
% Any instance when that is not the case will be highlighted in an exported file, if relevant.
trackIDs = unique(trackIDs_all);
checkData = NaN(length(trackIDs),1); count = 0;
for x = 1:length(trackIDs)
    posx = find(strcmp(trackIDs_all,trackIDs(x)) == 1);
    tmpDate = date_tracks(posx);
    diffDate = tmpDate(2:end) - tmpDate(1:end - 1); clear tmpDate
    posCheck = find(diffDate <= 0);
    if ~isempty(posCheck)
        checkData(count + 1:count + length(posCheck)) = posx(posCheck);
        count = count + length(posCheck);
    end
end
if count > 0 % Some track data have unexpected dates
    warning('Not all track data are monotonously increasing.') 
    disp('An additional .mat file (with the prefix "Check") will be generated.') 
    readme = {'"checkData" contains the row numbers with unexpected dates';
             ' - specifically, when the date is not later than the preceding track point'
             ' based on the provided order in your track input file.'}; % readme
    checkData = checkData(1:count) + trackInfo(2); % Crop the vector - and shift by the number of header rows.
    posStop = strfind(char(fileNames_tracks),'.');
    % Save the file:
    save([out_dir,'Check_',fileNames_tracks(1:posStop(end) - 1),'.mat'],'checkData','readme')
end