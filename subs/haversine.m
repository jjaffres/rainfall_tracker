function dist = haversine(lonRad,latRad,pos2_lon,pos1_lat,pos2_lat,R)
%% haversine.m
% This function applies the haversine formula with respect to a fixed reference point.
%
% Note: Beware if you want to apply this subsidiary code for external use:
%       One of the longitude (lonRad) positions is fixed in this code, with
%       only the second longitudinal position permitted to change.
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%     J. Jaffrés & J. Gray - 26 Jul 2021

% Calcualte the square of half the chord length between the points:
A = sin((latRad(pos2_lat) - (latRad(pos1_lat)))/2)^2 + cos(latRad(pos1_lat)) * ...
    cos(latRad(pos2_lat)) * sin((lonRad(pos2_lon) - (lonRad(1)))/2)^2;
C_sin = 2 * R * asin(sqrt(A)); % The angular distance in radians.
dist = C_sin/1000.0; % Output in kilometers.
