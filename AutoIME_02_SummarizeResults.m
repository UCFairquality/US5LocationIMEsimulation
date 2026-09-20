% this script
% 1. read IME results and summarize
% SFCdat.mat should be already available

clear; clc; close all; fclose all; format compact; format longG;

% inPath  = [pwd,'\','VerticalIntergration'];
% note that this is for 3% noise and 100 kg/h true rate
% the 100 kg/h rate should be the rate used to run AERMOD
% outPath = [pwd,'\','IMEtesting_10m_1noise_100kgh'];

dayRange = [2023,10,28;
            2024,1,25];

inPath   = [pwd,'\','IMEtesting_10m_1noise_100kgh'];
outDatName = 'IMEtesting_10m_1noise_100kgh.mat';

startDay = datetime(dayRange(1,:));
endDay   = datetime(dayRange(2,:));
nDays    = caldays(between(startDay,endDay,'days'));

IMEdat = [];

for dNum = 1:nDays
    [y,m,d] = ymd(startDay+dNum-1);
    fprintf('Now running %d %d %d\n',y,m,d);

    outName = sprintf('%s\\Y%dM%dD%d.mat',inPath,y,m,d);
    load(outName);

    IMEdat = [IMEdat;hrIME];
end
save(outDatName,'IMEdat');




