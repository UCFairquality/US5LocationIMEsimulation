clear; clc; close all; fclose all; format compact; format longG;

baseDir = pwd;
aermodDir = fullfile(baseDir, 'AERMODinputs');
aermodOutputDir = fullfile(baseDir, 'AERMODoutput');

%%
cd(aermodDir);
copyfile('InputMeta_KMIA_2021.mat', 'InputMeta.mat');
cd(baseDir)
run('AutoAERMOD_03_RunAndCollect_KMIA_Pt.m');

clear; clc; fclose all; close all;
baseDir = pwd;
aermodDir = fullfile(baseDir, 'AERMODinputs');
aermodOutputDir = fullfile(baseDir, 'AERMODoutput');

targetFolder = fullfile(aermodOutputDir, 'KMIA_pt_2021');
movefile(fullfile(aermodOutputDir, '*.mat'), targetFolder);
%%
cd(aermodDir);
copyfile('InputMeta_KMIA_2022.mat', 'InputMeta.mat');
cd(baseDir)
run('AutoAERMOD_03_RunAndCollect_KMIA_Pt.m');

clear; clc; fclose all; close all;
baseDir = pwd;
aermodDir = fullfile(baseDir, 'AERMODinputs');
aermodOutputDir = fullfile(baseDir, 'AERMODoutput');

targetFolder = fullfile(aermodOutputDir, 'KMIA_pt_2022');
movefile(fullfile(aermodOutputDir, '*.mat'), targetFolder);
%%
cd(aermodDir);
copyfile('InputMeta_KMIA_2023.mat', 'InputMeta.mat');
cd(baseDir)
run('AutoAERMOD_03_RunAndCollect_KMIA_Pt.m');

clear; clc; fclose all; close all;
baseDir = pwd;
aermodDir = fullfile(baseDir, 'AERMODinputs');
aermodOutputDir = fullfile(baseDir, 'AERMODoutput');

targetFolder = fullfile(aermodOutputDir, 'KMIA_pt_2023');
movefile(fullfile(aermodOutputDir, '*.mat'), targetFolder);
%%
cd(aermodDir);
copyfile('InputMeta_KMIA_2024.mat', 'InputMeta.mat');
cd(baseDir)
run('AutoAERMOD_03_RunAndCollect_KMIA_Pt.m');

clear; clc; fclose all; close all;
baseDir = pwd;
aermodDir = fullfile(baseDir, 'AERMODinputs');
aermodOutputDir = fullfile(baseDir, 'AERMODoutput');

targetFolder = fullfile(aermodOutputDir, 'KMIA_pt_2024');
movefile(fullfile(aermodOutputDir, '*.mat'), targetFolder);