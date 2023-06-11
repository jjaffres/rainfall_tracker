function RfileYears_cont = rain_fileYears(in_dirRain,fileList_rain)
%% rain_fileYears.m
% This function extracts the years (first/last) for each rainfall file (based on their title).
%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 22 Sep 2021
        disp('rainfall_tracker.m is set up for rainfall with yearly (or multi-yearly) files')
        disp('For files containing shorter periods, the script will have to be modified')
        
% List of years based on the file name (and associated file - and year-position - number):
RfileYears = NaN(length(fileList_rain)*2,3); 
RfileYears_cont = NaN(2000,2); % Complete list of years contained within files (and associated file number).
                               % For example, file '*2009_2011*' would contain years 2009 to 2011.

% fileList_rain = dir([in_dirRain,fileNames_rain]); % Obtain the full list of relevant rainfall files
% nameCheck = 0; % Check if the file name has too many (or too few) 4-digit values
countF = 0; % Count the position for the years-in-name matrix.
countC = 1; % Count the position for the continuous-years matrix.
for xF = 1:length(fileList_rain)
    % Extract the year(s) from the file name:
    nameTest = char(regexp(fileList_rain(xF).name,'\d{4}','Match')); 
    
    % Check whether there are too many (or too few) 4-digit values in the file name: 
    if size(nameTest,1) < 1
        error(['Your rainfall filenames contain no 4-digit number (== year)! See for example ',in_dirRain,fileList_rain(xF).name])
    elseif size(nameTest,1) > 2
        error(['Your rainfall filenames contain more than two 4-digit numbers! See for example ',in_dirRain,fileList_rain(xF).name])
    end
    
%     % Extract the start-position of the year(s) from the file name:
    yrs = str2num(nameTest);
    for xY = 1:size(nameTest,1) % length(yrs)
        countF = countF + 1;
        % yr = str2double(nameTest(xY,:)); % Extract the start-position of the year from the file name.
%         RfileYears(countF,:) = [yr xF strfind(fileList_rain(xF).name,nameTest(xY,:))]; 
        RfileYears(countF,:) = [yrs(xY) xF strfind(fileList_rain(xF).name,nameTest(xY,:))]; 
    end
    
    yrsCont = yrs(1):yrs(end);
    RfileYears_cont(countC:countC + length(yrsCont) - 1,:) = [yrsCont' xF*ones(length(yrsCont),1)];
    countC = countC + length(yrsCont);
end
RfileYears = RfileYears(1:countF,:);
RfileYears_cont(countC:end,:) = [];

%% Check for missing or duplicate data years (based on filenames)
if max(RfileYears(:,1)) - min(RfileYears(:,1)) + 1 > size(RfileYears_cont,1)
    warning(['Are you aware that you do not have data for all years between ',...
        num2str(min(RfileYears(:,1))),' and ',num2str(max(RfileYears(:,1))),' based on the filenames?!'])
    fullList = min(RfileYears(:,1)):max(RfileYears(:,1));
    disp('The missing years (based on filenames) are:')
    disp(fullList(~ismember(fullList,RfileYears_cont(:,1))))
end
if length(unique(RfileYears_cont(:,1))) < size(RfileYears_cont,1)
    warning('Are you aware that you seem to have duplicate data based on the filenames?!')
    [~, posUnique] = unique(RfileYears_cont(:,1));
    dups = unique(RfileYears_cont(not(ismember(1:numel(RfileYears_cont(:,1)),posUnique)),1));
    disp('The duplicate years (based on filenames) are:'); disp(dups)
    disp('For each of these years, only the first file (in alpha-numerical order) will be accessed!')
end