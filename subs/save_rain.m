function rain_output = save_rain(rain_options,unitConv,rainRadius,sideWin,timeZones,lonR,latR,...
    trackIDs,event_rain,peakIntensity,rain_fullRes,dateRange,out_dir,rainSource,outName_suffix)
%% save_rain.m
% Save the relevant rainfall data.
%
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 10 Jan 2022

%% Apply unit conversions
% Note: The conversion was already applied for rain_fullRes (raw) data (if relevant) in rain_subdaily.
%       Daily data have not incorporated this yet.
event_rain = event_rain*unitConv; peakIntensity = peakIntensity*unitConv;

%% Data preparation
read_tmp = {'unitConv:      The scaling factor applied to rainfall for unit conversion.';
          'rainRadius:      The applied radius from the centre of the low.';
          'sideWin:         The applied side window for each track position.';
          'timeZones:       Assigned time zones for TC tracks (position 1) vs rainfall (position 2).';
          'lonR:            Longitude vector from rainfall data.'; 
          'latR:            Latitude vector from rainfall data.'};

%% Save the compiled rainfall of each TC event
if length(trackIDs) > 1 % ndims(event_rain) == 3
    header_rain = {'Longitude','Latitude','Track'}; 
else
    header_rain = {'Longitude','Latitude'}; 
end
if strcmp(rain_options,'total') % Event rain, i.e. sum of all rainfall over the period of the track.
    prefix = 'eventRain';
    readme = [read_tmp; 
        {'event_rain:      3D matrix that contains the slices of total rainfall per track and grid point.';
        'header_event_rain:  Descriptor of each dimension of the 3D event_rain matrix.';
        'trackIDs:   List of unique low-pressure system IDs.'}];
    header_event_rain = header_rain; rain_output = event_rain;
    save([out_dir,prefix,'_',rainSource,'_',outName_suffix,'.mat'],'readme',...
        'unitConv','rainRadius','sideWin','timeZones','lonR','latR','trackIDs',...
        'event_rain','header_event_rain','-mat');   
elseif strcmp(rain_options,'maximum') % Maximum rainfall intensity per grid point
    prefix = 'peakIntensity';
    readme = [read_tmp; 
                {'peakIntensity:      3D matrix that contains the slices of peak rainfall intensity per track and grid point.';
                'header_peakIntensity:  Descriptor of each dimension of the 3D peakIntensity matrix.';
                'trackIDs:   List of unique low-pressure system IDs.'}];
    header_peakIntensity = header_rain; rain_output = peakIntensity;
    save([out_dir,prefix,'_',rainSource,'_',outName_suffix,'.mat'],'readme',...
        'unitConv','rainRadius','sideWin','timeZones','lonR','latR','trackIDs',...
        'peakIntensity','header_peakIntensity','-mat');   
elseif strcmp(rain_options,'raw') % Raw rain data (i.e. slice for each rainfall period). 
    prefix = 'rawData';
    readme = [read_tmp; 
                {'rain_fullRes:   The raw data (i.e. individual rain slices)'}
                'header_rain:  Descriptor of each dimension within each cell of the 1D rain_fullRes cell matrix.';
                'dateRange:  Applicable (end-)time for each rain slice and track';
                {'trackIDs:   List of unique low-pressure system IDs.'}];
    header_rain = {'Longitude','Latitude','All rain slices for each TC'};
    rain_output = rain_fullRes;
    save([out_dir,prefix,'_',rainSource,'_',outName_suffix,'.mat'],'readme',...
        'unitConv','rainRadius','sideWin','timeZones','lonR','latR','trackIDs',...
        'rain_fullRes','header_rain','dateRange','-mat'); % ,'dims_radiusArea','radiusArea','dailyRain');    
end
