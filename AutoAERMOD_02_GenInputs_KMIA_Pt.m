% -------------------------------------------------------------------------
% Define AERMOD run configuration and source parameters, and:
%   1) Save them as InputMeta.mat in the AERMODinputs folder.
%   2) Pre-generate, in memory, the text lines for AERMOD input files
%      (.inp) for each day and layer, and store them in InputMeta.InpLines.
%
% This script does NOT write any .inp files to disk. Script 3 will read
% InputMeta.InpLines{iday, ilayer} and write those lines to aermod.inp
% in each temporary run directory.
%
% Requires:
%   AERMODinputs/ReceptorMeta.mat       (from AERMOD_01_GenReceptors)
%
% Output:
%   AERMODinputs/InputMeta.mat
%
% Key fields in InputMeta:
%   runTitle      - title string for CO pathway
%   allDays       - [nYears x 6] matrix: [Y1 M1 D1  Y2 M2 D2]
%   loopYear      - which row of allDays is used
%   dates         - [nDays x 3] matrix of [Y M D] for the chosen period
%   zLevels       - [1 x nZ] vector of layer heights (from ReceptorMeta)
%   nZ            - number of Z layers
%   srcType, srcID, srcX, srcY, etc. - source parameters
%   metBaseName   - base name for met files (<metBaseName>_YYYY.SFC/PFL)
%   InpLines      - cell(nDays, nZ), each cell = cell array of strings
%                   representing the contents of an AERMOD .inp file
%
% Haofei Yu, 2025-12-06

clear; clc; close all; fclose all; format compact; format longG;

%% ------------------------------------------------------------------------
%  Shared input folder (same as Script 1)
% -------------------------------------------------------------------------
inpFolder = fullfile(pwd, 'AERMODinputs');
if ~exist(inpFolder, 'dir')
    error('AERMODinputs folder not found. Run AERMOD_01_GenReceptors first.');
end

% Load receptor meta to know zLevels, etc.
recMatFile = fullfile(inpFolder, 'ReceptorMeta.mat');
if ~isfile(recMatFile)
    error('ReceptorMeta.mat not found in %s. Run AERMOD_01_GenReceptors first.', ...
          inpFolder);
end

S = load(recMatFile, 'ReceptorMeta');
ReceptorMeta = S.ReceptorMeta;

zLevels    = ReceptorMeta.zLevels;
nZ         = ReceptorMeta.nZ;
recSpacing = ReceptorMeta.recSpacing;   % for documentation / consistency

%% ------------------------------------------------------------------------
%  General run settings
% -------------------------------------------------------------------------
runTitle = 'KMIA';

% Simulation period options (rows: [Y1 M1 D1  Y2 M2 D2])
allDays = [2020,1,1, 2020,12,31;
           2021,1,1, 2021,12,31;
           2022,1,1, 2022,12,31;
           2023,1,1, 2023,12,31;
           2024,1,1, 2024,12,31];

% Choose which row to run
loopYear = 5;  

startDay = allDays(loopYear, 1:3);
endDay   = allDays(loopYear, 4:6);

startDate = datetime(startDay);
endDate   = datetime(endDay);
runDayN   = days(endDate - startDate) + 1;

% Vector of dates for this run
dates = zeros(runDayN, 3);
for dNum = 1:runDayN
    dt = startDate + days(dNum-1);
    [yy, mm, dd] = ymd(dt);
    dates(dNum,:) = [yy mm dd];
end

%% ------------------------------------------------------------------------
%  Source definition (POINT or AREA)
% -------------------------------------------------------------------------
srcType = 'POINT';     % 'POINT' or 'AREA'
srcID   = 'Src1';

% Source coordinates X and Y
%   POINT source: exact location of point source
%   AREA source : location of southwest corner
srcX = 0;
srcY = 1500;

% POINT source params: SRCPARAM Srcid Ptemis Stkhgt Stktmp Stkvel Stkdia
% Example: 100 kg/h = 27.778 g/s
Ptemis = 27.778;      % g/s
Stkhgt = 0;           % m
Stktmp = 287;         % K
Stkvel = 0.1;         % m/s
Stkdia = 1;           % m

% AREA source params: SRCPARAM Srcid Aremis Relhgt Xinit Yinit
% Example: 100 kg/h forZ 100m*100m = 0.002778 g/(s-m^2)
Aremis = 0.002778;    % g/(s-m^2)
Relhgt = 0;           % m
Xinit  = 100;         % m (X side length, east-west)
Yinit  = 100;         % m (Y side length, north-south)

%% ------------------------------------------------------------------------
%  Meteorology base name
% -------------------------------------------------------------------------
% AERMOD run script will expect met files named like:
%   <metBaseName>_YYYY.SFC
%   <metBaseName>_YYYY.PFL
% in the working directory at runtime.
metBaseName = 'US_KMIA';

%% ------------------------------------------------------------------------
%  Pre-generate .inp text content in memory
% -------------------------------------------------------------------------
% InpLines{iday, iLayer} will be a cell array of strings. Script 3 will
% call:
%   lines = InputMeta.InpLines{iday, iLayer};
%   fprintf(fid, '%s\n', lines{:});
%
% We keep this in InputMeta to avoid writing many .inp files to disk.
InpLines = cell(runDayN, nZ);

for dNum = 1:runDayN
    y = dates(dNum,1);
    m = dates(dNum,2);
    d = dates(dNum,3);

    % Name of met files AERMOD will use at runtime
    sfcFile = sprintf('%s_%d.SFC', metBaseName, y);
    pflFile = sprintf('%s_%d.PFL', metBaseName, y);

    for L = 1:nZ
        % Receptor file name that will be created in the run directory
        recFileName = sprintf('DistCart_%2.2d.txt', L);

        % Build lines as a cell array of strings
        lines = {};

        % ---------------- CO pathway ----------------
        lines{end+1} = 'CO STARTING';
        lines{end+1} = sprintf('   TITLEONE  %s', runTitle);
        lines{end+1} = '   MODELOPT  CONC ELEV FASTALL';
        lines{end+1} = '   AVERTIME  1  PERIOD';
        lines{end+1} = '   POLLUTID  CH4';
        lines{end+1} = '   FLAGPOLE  0';
        lines{end+1} = '   RUNORNOT  RUN';
        lines{end+1} = '   ERRORFIL  Errors.TXT';
        lines{end+1} = 'CO FINISHED';

        % ---------------- SO pathway ----------------
        lines{end+1} = 'SO STARTING';
        lines{end+1} = sprintf('   LOCATION  %s %s %g %g', ...
                                srcID, upper(srcType), srcX, srcY);

        if strcmpi(srcType,'POINT')
            % SRCPARAM Srcid Ptemis Stkhgt Stktmp Stkvel Stkdia
            lines{end+1} = sprintf('   SRCPARAM  %s %g %g %g %g %g', ...
                                   srcID, Ptemis, Stkhgt, Stktmp, Stkvel, Stkdia);
        elseif strcmpi(srcType,'AREA')
            % SRCPARAM Srcid Aremis Relhgt Xinit Yinit
            lines{end+1} = sprintf('   SRCPARAM  %s %g %g %g %g', ...
                                   srcID, Aremis, Relhgt, Xinit, Yinit);
        else
            error('Unsupported srcType: %s (use ''POINT'' or ''AREA'')', srcType);
        end

        lines{end+1} = '   SRCGROUP  ALL';
        lines{end+1} = 'SO FINISHED';

        % ---------------- RE pathway ----------------
        lines{end+1} = 'RE STARTING';
        lines{end+1} = sprintf('   INCLUDED  %s', recFileName);
        lines{end+1} = 'RE FINISHED';

        % ---------------- ME pathway ----------------
        lines{end+1} = 'ME STARTING';
        lines{end+1} = sprintf('   SURFFILE  %s', sfcFile);
        lines{end+1} = sprintf('   PROFFILE  %s', pflFile);
        lines{end+1} = sprintf('   SURFDATA  12839  %d  Miami', y);
        lines{end+1} = sprintf('   UAIRDATA  12839  %d  Miami', y);
        lines{end+1} = '   PROFBASE  0  METERS';
        lines{end+1} = sprintf('   STARTEND  %d %d %d 9 %d %d %d 17', ...
                               y, m, d, y, m, d);
        lines{end+1} = 'ME FINISHED';

        % ---------------- OU pathway ----------------
        lines{end+1} = 'OU STARTING';
        lines{end+1} = '   POSTFILE  1  ALL UNFORM RawData.DAT';
        lines{end+1} = 'OU FINISHED';

        % Store in InpLines
        InpLines{dNum, L} = lines;
    end
end

%% ------------------------------------------------------------------------
%  Pack config + templates into InputMeta and save in AERMODinputs
% -------------------------------------------------------------------------
InputMeta = struct();
InputMeta.runTitle    = runTitle;

InputMeta.allDays     = allDays;
InputMeta.loopYear    = loopYear;
InputMeta.dates       = dates;       % [runDayN x 3]

% Geometry/reference (copied from ReceptorMeta for traceability)
InputMeta.xRange      = ReceptorMeta.xRange;
InputMeta.yRange      = ReceptorMeta.yRange;
InputMeta.zRange      = ReceptorMeta.zRange;
InputMeta.zLevels     = zLevels;
InputMeta.nZ          = nZ;
InputMeta.recSpacing  = recSpacing;

% Source info
InputMeta.srcType     = srcType;
InputMeta.srcID       = srcID;
InputMeta.srcX        = srcX;
InputMeta.srcY        = srcY;

InputMeta.Ptemis      = Ptemis;
InputMeta.Stkhgt      = Stkhgt;
InputMeta.Stktmp      = Stktmp;
InputMeta.Stkvel      = Stkvel;
InputMeta.Stkdia      = Stkdia;

InputMeta.Aremis      = Aremis;
InputMeta.Relhgt      = Relhgt;
InputMeta.Xinit       = Xinit;
InputMeta.Yinit       = Yinit;

% Meteorology naming
InputMeta.metBaseName = metBaseName;

% Pre-generated input text templates
InputMeta.InpLines    = InpLines;    % cell(runDayN, nZ): each cell = {lines}

inMetaFile = fullfile(inpFolder, 'InputMeta.mat');
save(inMetaFile, 'InputMeta', '-v7.3');

fprintf('InputMeta saved to: %s\n', inMetaFile);
fprintf('InpLines{iday,ilayer} holds the aermod.inp text for that day/layer.\n');
