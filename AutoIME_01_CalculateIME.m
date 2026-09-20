% this script
% 1. read vertically integrated data and calculated IME rates
% SFCdat.mat should be already available
% Haofei Yu, 2025-12-7

clear; clc; close all; fclose all; format compact; format longG;

inPath  = [pwd,'\','VerticalIntegration_SmallArea'];

allDays = [2020,6,1, 2020,6,30;
           2021,6,1, 2021,6,30;
           2022,6,1, 2022,6,30
           2023,6,1, 2023,6,30
           2024,6,1, 2024,6,30];

loopYear = 5;
startDay = allDays(loopYear,1:3);
endDay   = allDays(loopYear,4:6);

dayRange = [startDay; endDay];

% load surface wind data
load('SurfaceWind.mat');

% % here hour needs to be add one
% % SurfaceWindData.Hour = SurfaceWindData.Hour + 1;

gSize  = 25;     % grid size in meters
vGrid  = 61;     % vertical number of grids
repNum = 100;    % how many repetation each step

% assume background 1250 ug/m3 --> 1900 ppbv, example"
% at 1.5 km, 10 v grid, background: 1250 * 10^3 / 1E9 * 15
% unit is kg per grid cell
dBackground = 1250 * gSize^3 / 1E9 * vGrid;

startDay = datetime(dayRange(1,:));
endDay   = datetime(dayRange(2,:));
nDays    = caldays(between(startDay,endDay,'days')) + 1;

% scaFac is scaling factor for emissions. 1=100kg/h; 2=200kg/h
% noiseAdd is amount of nosie to add. 0.01=1%
scaFacLst   = [0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4,...
    4.5, 5, 6, 7, 8, 10, 15, 20]';

noiseAddLst = [0.05]';
scaFacNum   = size(scaFacLst,1);
noiseAddNum = size(noiseAddLst,1);

for s = 1:scaFacNum
    scaFac = scaFacLst(s);

    outPath = [pwd,'\','RepTest_SmallArea'];
    outPath = sprintf('%s\\%dkgh',outPath,scaFac*100);

    if ~exist(outPath, 'dir')
        mkdir(outPath);
    end

    for n = 1:noiseAddNum
        noiseAdd = noiseAddLst(n);
        for dNum = 1:nDays
            [y,m,d] = ymd(startDay+dNum-1);

            % store output data for all repetations
            dayIME = array2table(zeros(0,12));
            dayIME.Properties.VariableNames = {'Year','Mth','Day','Hr',...
                'Scale','Noise','RepID','U10','Ueff','IME','L','Q'};
            outFile = sprintf('%d%2.2d%2.2d_%dkgh_N%d_100rep.mat',...
                y,m,d,scaFac*100,noiseAdd*100);

            dFileName = sprintf('Y%dM%2.2dD%2.2d.mat',y,m,d);
            dayD  = load([inPath,'\',dFileName]);
            dayD  = dayD.satSim;

            for h = 7:18
                a = dayD(:,:,h);
                % skip this hour is all concentrations are zero
                if sum(sum(a)) == 0
                    continue;
                end

                % find U10 from surface wind data
                U10windAll = SurfaceWind.ReferenceWindSpeedms;
                U10Year  = SurfaceWind.Year + 2000;
                U10Month = SurfaceWind.Mth;
                U10Day   = SurfaceWind.Day;
                U10Hour  = SurfaceWind.Hour;

                U10WindIdx = U10Year==y & U10Month==m & U10Day==d & U10Hour==h;
                if sum(U10WindIdx) ~= 1
                    error('Found no wind or more than 1 wind record\n');
                end
                U10wind = U10windAll(U10WindIdx);
                % skip this hour is u10 wind is zero
                if U10wind==0
                    continue;
                end

                for r = 1:repNum
                    fprintf('%d %d %d %d %dkgh noise %d rep %d of %d\n',...
                        y,m,d,h,scaFac*100,noiseAdd*100,r,repNum);

                    [Ueff,IME,L,Q] = estimateIME(a,scaFac,dBackground,...
                        noiseAdd,U10wind,gSize);

                    thisRepIME = table(y,m,d,h,scaFac,noiseAdd,r,...
                        U10wind,Ueff,IME,L,Q,...
                        'VariableNames',{'Year','Mth','Day','Hr','Scale',...
                        'Noise','RepID','U10','Ueff','IME','L','Q'});

                    dayIME = [dayIME;thisRepIME];
                end
            end
            save2file([outPath,'\',outFile],dayIME);
        end
    end
end


% enable this for parallel computing
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function save2file(fPath,dayIME)
save(fPath,'dayIME');
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


