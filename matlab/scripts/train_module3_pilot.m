%TRAIN_MODULE3_PILOT Fine-tune the first (fastest) backbone as a pilot run
%   to validate the whole Module 3 training pipeline before committing to
%   all three backbones in the PRD's ensemble.
%
%   Run headless via: matlab -batch "run('train_module3_pilot.m')"
%   Designed to run in the background for ~1 hour (CPU-only fine-tuning);
%   do not run this interactively expecting immediate output.

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'modules', 'module3_grading'));

dataDir = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'train_data', 'images');
outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'train_data', 'trained_models');

results = trainAndEvaluate('efficientnetb0', dataDir, outDir);

fprintf('\n=== PILOT RUN COMPLETE ===\n');
