% 1) Read daily AERMOD outputs from AERMOD_03_RunAndCollect (DayOut structs)
% 2) Convert concentrations from ug/m^3 to kg per 10 m cube
% 3) Vertically integrate to get column totals: satSim [nX x nY x nRecs]
% Haofei Yu, 2025-12-07

clear; clc; close all; fclose all; format compact; format longG;

%% Paths
basePath   = pwd;
inpFolder  = fullfile(basePath, 'AERMODinputs');
inPath     = fullfile(basePath, 'AERMODoutput');       % from AERMOD_03_RunAndCollect
outPath    = fullfile(basePath, 'VerticalIntegration'); % new vertical integration outputs

if ~exist(inPath, 'dir')
    error('Input folder not found: %s', inPath);
end
if ~exist(outPath, 'dir')
    mkdir(outPath);
end

%% Load InputMeta to get the list of days actually run
inMetaFile = fullfile(inpFolder, 'InputMeta.mat');
if ~isfile(inMetaFile)
    error('InputMeta.mat not found in %s. Run Scripts 1–3 first.', inpFolder);
end

load(inMetaFile, 'InputMeta');
IM = InputMeta;

if ~isfield(IM, 'dates')
    error('InputMeta does not contain "dates". Cannot determine run days.');
end

dates = IM.dates;      % [nDays x 3] = [Y M D]
recSpacing = IM.recSpacing;
nDays = size(dates,1);

fprintf('Found %d run days in InputMeta.\n', nDays);

%% Loop over each day and vertically integrate
for dNum = 1:nDays
    y = dates(dNum,1);
    m = dates(dNum,2);
    d = dates(dNum,3);

    fprintf('Now processing %04d-%02d-%02d\n', y, m, d);

    inFile  = fullfile(inPath, sprintf('Y%04dM%02dD%02d.mat', y, m, d));
    outFile = fullfile(outPath, sprintf('Y%04dM%02dD%02d.mat', y, m, d));

    if ~isfile(inFile)
        warning('Input file not found: %s. Skipping this day.', inFile);
        continue;
    end

    S = load(inFile, 'DayOut');
    if ~isfield(S, 'DayOut')
        error('File %s does not contain variable "DayOut".', inFile);
    end
    DayOut = S.DayOut;

    if ~isfield(DayOut, 'ConcXYZ')
        error('DayOut in %s does not contain "ConcXYZ".', inFile);
    end

    % ConcXYZ: [nX x nY x nZ x nRecs], units: ug/m^3
    D = double(DayOut.ConcXYZ);

    % Convert ug/m^3 to kg. Example: for a 10 m cube
    % mass[kg] = conc[ug/m^3] * (10 m * 10 m * 10 m) * (1e-9 kg/ug)
    %          = conc * 1e-6
    D = D .* recSpacing^3 * 1e-9;

    % Vertically integrate: sum over Z (3rd dimension)
    % Result satSim: [nX x nY x nRecs] column total (kg per 10 m x 10 m cell)
    satSim = squeeze(sum(D, 3));
    satSim = single(satSim);  % keep storage smaller

    % Save only satSim
    save(outFile, 'satSim', '-v7.3');

    fprintf('   Saved vertically integrated file: %s\n', outFile);
end

fprintf('\nAll vertical integrations written to folder: %s\n', outPath);
