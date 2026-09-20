% Use ReceptorMeta and InputMeta to:
%   - For each day & layer, create a temporary run directory,
%     write receptor file (DistCart_LL.txt) and aermod.inp,
%     copy aermod.exe + met files, run AERMOD, and read RawData.DAT
%     using readAERMODunformatDat (unformatted POSTFILE).
%   - Aggregate layer-wise outputs into a 4D concentration array:
%       ConcXYZ [nX x nY x nZ x nRecs]
%     plus X/Y/Z grids and metadata for each day.
%   - Save one .mat per day in the "AERMODoutput" folder.
%
% Requires:
%   AERMODinputs/ReceptorMeta.mat   (from AERMOD_01_GenReceptors)
%   AERMODinputs/InputMeta.mat      (from AERMOD_02_GenInputs)
%   aermod.exe                      (in current directory)
%   readAERMODunformatDat.m         (in current directory)
%   Met files named: <metBaseName>_YYYY.SFC and .PFL in current directory
%
% Output:
%   AERMODoutput/YyyyyMmmDdd.mat  containing struct "DayOut"
%
% DayOut fields (per day):
%   date       - [Y M D]
%   runTitle   - from InputMeta
%   srcType, srcID, srcX, srcY, source parameters
%   recSpacing - from ReceptorMeta
%   X, Y, Z    - [nX x nY x nZ] single
%   EndDate    - [1 x nRecs] YYMMDDHH from AERMOD POSTFILE
%   ConcXYZ    - [nX x nY x nZ x nRecs] single
%
% Haofei Yu, 2025-12-06

clear; clc; close all; fclose all; format compact; format longG;


%% Parallel workers
%%%%%%%%%%%%%%%%%%%%%%%
% parpool('Processes',51);
%%%%%%%%%%%%%%%%%%%%%%%

%% ------------------------------------------------------------------------
%  Paths and inputs
% -------------------------------------------------------------------------
basePath   = pwd;
inpFolder  = fullfile(basePath, 'AERMODinputs');
% outFolder  = fullfile(basePath, 'AERMODoutput');

% Load meta files
recMatFile = fullfile(inpFolder, 'ReceptorMeta.mat');
load(recMatFile, 'ReceptorMeta');

% inMetaFile = fullfile(inpFolder, 'InputMeta.mat');
% inMetaFileList = 'InputMeta_KMIA_2024.mat';
inMetaFile = fullfile(inpFolder, 'InputMeta_KMIA_2024.mat');
% outFolderList  = 'KMIA_pt_2024';
% for metFileIdx = 1:size(inMetaFileList,1)
outFolder  = fullfile(basePath, 'AERMODoutput', 'KMIA_pt_2024');
% outFolder  = fullfile(basePath, 'AERMODoutput', outFolderList{metFileIdx,1});
load(inMetaFile, 'InputMeta');

RM = ReceptorMeta;
IM = InputMeta;

%% ------------------------------------------------------------------------
%  Unpack receptor meta and build coordinate grids
% -------------------------------------------------------------------------
recSpacing = RM.recSpacing;
zLevels    = RM.zLevels;
nZ         = RM.nZ;
xVals      = RM.xVals;
yVals      = RM.yVals;
nX         = numel(xVals);
nY         = numel(yVals);

ReceptorMat = RM.ReceptorMat;   % {L} : [nRec x 5] = [X Y Z Elev Hill]
hasZdata    = RM.hasZdata;

% Build X/Y/Z grids from ReceptorMat (for output; we do this once)
Xgrid = zeros(nX, nY, nZ);
Ygrid = zeros(nX, nY, nZ);
Zgrid = zeros(nX, nY, nZ);

for L = 1:nZ
    M = ReceptorMat{L};  % [nRec x 5]
    nReceptors_L = size(M,1);

    if nReceptors_L ~= nX*nY
        error('Layer %d has %d receptors, expected %d = nX*nY.', ...
            L, nReceptors_L, nX*nY);
    end

    Xgrid(:,:,L) = reshape(M(:,1), [nY, nX]);
    Ygrid(:,:,L) = reshape(M(:,2), [nY, nX]);
    Zgrid(:,:,L) = reshape(M(:,3), [nY, nX]);
end

nReceptors = nX * nY;

%% ------------------------------------------------------------------------
%  Unpack InputMeta
% -------------------------------------------------------------------------
runTitle   = IM.runTitle;
allDays    = IM.allDays;
loopYear   = IM.loopYear;
dates      = IM.dates;          % [runDayN x 3]
nDays      = size(dates,1);
nZ_inMeta  = IM.nZ;

if nZ_inMeta ~= nZ
    error('nZ mismatch between ReceptorMeta (%d) and InputMeta (%d).', ...
        nZ, nZ_inMeta);
end

% Source info (for DayOut metadata)
srcType = IM.srcType;
srcID   = IM.srcID;
srcX    = IM.srcX;
srcY    = IM.srcY;

Ptemis  = IM.Ptemis;
Stkhgt  = IM.Stkhgt;
Stktmp  = IM.Stktmp;
Stkvel  = IM.Stkvel;
Stkdia  = IM.Stkdia;

Aremis  = IM.Aremis;
Relhgt  = IM.Relhgt;
Xinit   = IM.Xinit;
Yinit   = IM.Yinit;

metBaseName = IM.metBaseName;

InpLines    = IM.InpLines;      % cell(nDays, nZ): each cell = {lines}

%% ------------------------------------------------------------------------
%  Check required executables and met files
% -------------------------------------------------------------------------
% We expect met files named <metBaseName>_YYYY.SFC/PFL for all unique years.
if ~isfile(fullfile(basePath, 'aermod.exe'))
    error('aermod.exe not found in %s', basePath);
end

yearsNeeded = unique(dates(:,1));
for iY = 1:numel(yearsNeeded)
    y = yearsNeeded(iY);
    sfcFile = sprintf('%s_%d.SFC', metBaseName, y);
    pflFile = sprintf('%s_%d.PFL', metBaseName, y);

    if ~isfile(fullfile(basePath, sfcFile))
        error('Surface file %s not found in %s', sfcFile, basePath);
    end
    if ~isfile(fullfile(basePath, pflFile))
        error('Upper air file %s not found in %s', pflFile, basePath);
    end
end

if ~isfile(fullfile(basePath, 'readAERMODunformatDat.m'))
    error('readAERMODunformatDat.m not found in %s', basePath);
end

%% ------------------------------------------------------------------------
%  Loop over days; for each day, run all layers and then consolidate
% -------------------------------------------------------------------------
for dNum = 1:nDays
    y = dates(dNum,1);
    m = dates(dNum,2);
    d = dates(dNum,3);

    % For this day, determine the correct met file names (for copying)
    sfcFile = sprintf('%s_%d.SFC', metBaseName, y);
    pflFile = sprintf('%s_%d.PFL', metBaseName, y);

    % To hold per-layer AERMOD outputs in memory for this day
    AERMOD_layers = cell(nZ,1);

    parfor L = 1:nZ
        zHeight = zLevels(L);
        fprintf('Running %04d-%02d-%02d Layer %d of %d (Z = %.1f m)\n',...
            y, m, d, L, nZ, zHeight);

        % Temporary run directory for this day & layer
        runDirName = sprintf('Run_Y%04dM%02dD%02d_L%02d', y, m, d, L);
        runDirPath = fullfile(basePath, runDirName);
        mkdir(runDirPath);

        % Copy executables, met files, and reader function
        copyfile(fullfile(basePath,'aermod.exe'),          runDirPath);
        copyfile(fullfile(basePath,sfcFile),               runDirPath);
        copyfile(fullfile(basePath,pflFile),               runDirPath);
        copyfile(fullfile(basePath,'readAERMODunformatDat.m'), runDirPath);

        % Change into run directory
        cd(runDirPath);

        % --------------------------------------------------------------
        % 1) Create receptor file in this run directory from ReceptorMat
        % --------------------------------------------------------------
        recFileName = sprintf('DistCart_%2.2d.txt', L);
        fidRec = fopen(recFileName, 'w');
        if fidRec == -1
            error('Unable to open receptor file %s for writing.', recFileName);
        end

        M = ReceptorMat{L};   % [nReceptors x 5] = [X Y Z Elev Hill]

        if hasZdata
            % Write: RE DISCCART X Y Z ELEV HILLSCL
            fprintf(fidRec, 'RE ELEVUNIT METERS\n');
            for i = 1:size(M,1)
                fprintf(fidRec, '   DISCCART %7.2d %7.2d %6.2f %6.2f %d\n', ...
                    M(i,1), M(i,2), M(i,4), M(i,5), M(i,3));
            end
        else
            % Write: RE DISCCART X Y Z
            for i = 1:size(M,1)
                fprintf(fidRec, 'RE DISCCART %d %d %d\n', ...
                    M(i,1), M(i,2), M(i,3));
            end
        end

        fclose(fidRec);

        % --------------------------------------------------------------
        % 2) Create aermod.inp from InputMeta.InpLines{dNum, L}
        % --------------------------------------------------------------
        lines = InpLines{dNum, L};
        if isempty(lines)
            error('InpLines{%d,%d} is empty. Check Script 2 configuration.', dNum, L);
        end

        fidInp = fopen('aermod.inp', 'w');
        if fidInp == -1
            error('Unable to open aermod.inp for writing.');
        end
        fprintf(fidInp, '%s\n', lines{:});
        fclose(fidInp);

        % --------------------------------------------------------------
        % 3) Run AERMOD and read unformatted POSTFILE output
        % --------------------------------------------------------------
        !aermod.exe

        % Read RawData.DAT (unformatted POSTFILE)
        if ~isfile('RawData.DAT')
            error('RawData.DAT not created by AERMOD in %s', runDirPath);
        end

        AERMODout = readAERMODunformatDat('RawData.DAT', nReceptors);

        % Store in memory for this day/layer
        AERMOD_layers{L} = AERMODout;

        % --------------------------------------------------------------
        % 4) Clean up and go back
        % --------------------------------------------------------------
        delete *.*          % delete all files in run directory
        cd(basePath);
        rmdir(runDirPath);  % remove empty run directory
    end

    % ------------------------------------------------------------------
    % After all layers for this day: build 4D concentration outputs
    % ConcXYZ: [nX, nY, nZ, nHrs] (single precision)
    % X, Y, Z: [nX, nY, nZ] (single precision)
    % ------------------------------------------------------------------
    nHrs = numel(AERMOD_layers{1});
    for L = 2:nZ
        if numel(AERMOD_layers{L}) ~= nHrs
            error('Number of records differs between layers (Layer 1 vs Layer %d).', L);
        end
    end

    EndDate = zeros(1, nHrs);
    ConcXYZ = zeros(nX, nY, nZ, nHrs, 'single');

    for r = 1:nHrs
        EndDate(r) = AERMOD_layers{1}(r).EndDate;

        for L = 1:nZ
            Conc_vec = AERMOD_layers{L}(r).Conc;  % 1 x nReceptors

            if numel(Conc_vec) ~= nReceptors
                error('Record %d, layer %d: expected %d receptors, found %d.', ...
                    r, L, nReceptors, numel(Conc_vec));
            end

            % Receptors were written with X outer, Y inner:
            %   idx = (ix-1)*nY + iy
            % So reshape to [nY x nX]' to get [nX x nY]
            ConcXY = reshape(Conc_vec, [nY, nX]);   % [nX, nY]
            ConcXYZ(:,:,L,r) = single(ConcXY);
        end
    end

    % ------------------------------------------------------------------
    % Consolidate: one output struct per day and save
    % ------------------------------------------------------------------
    DayOut = struct();
    DayOut.date       = [y m d];
    DayOut.runTitle   = runTitle;

    % Source info
    DayOut.srcType = srcType;
    DayOut.srcID   = srcID;
    DayOut.srcX    = srcX;
    DayOut.srcY    = srcY;

    if strcmpi(srcType,'POINT')
        DayOut.Ptemis = Ptemis;
        DayOut.Stkhgt = Stkhgt;
        DayOut.Stktmp = Stktmp;
        DayOut.Stkvel = Stkvel;
        DayOut.Stkdia = Stkdia;
    else
        DayOut.Aremis = Aremis;
        DayOut.Relhgt = Relhgt;
        DayOut.Xinit  = Xinit;
        DayOut.Yinit  = Yinit;
    end

    DayOut.recSpacing = recSpacing;

    % Coordinate grids in single precision
    DayOut.X = single(Xgrid);
    DayOut.Y = single(Ygrid);
    DayOut.Z = single(Zgrid);

    % Record metadata
    DayOut.EndDate = EndDate;          % YYMMDDHH, double

    % 4D concentration array [X, Y, Z, record] in single precision
    DayOut.ConcXYZ = ConcXYZ;

    outName = fullfile(outFolder, sprintf('Y%04dM%02dD%02d.mat', y, m, d));
    save(outName, 'DayOut', '-v7.3');

    fprintf('   Saved daily output: %s\n', outName);
end
% end
fprintf('\nAll daily outputs written to folder: %s\n', outFolder);
