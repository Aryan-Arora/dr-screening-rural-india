%TRAIN_MODULE3_MULTI_DATASET Fine-tune 5 backbones (the original 3 plus
%   xception + inceptionresnetv2) on the combined APTOS+IDRiD+DDR
%   training set, then evaluate the ensemble including a per-source
%   domain-gap breakdown.
%
%   Run headless via: matlab -batch "run('train_module3_multi_dataset.m')"
%   Expect several hours on CPU for all 5 backbones plus evaluation --
%   longer than the original 3-backbone run (train_module3_all.m), both
%   because there are 2 more backbones and because xception/
%   inceptionresnetv2 are themselves larger networks.
%
%   Robustness, since this is meant to run fully unattended: each
%   backbone trains inside its own try/catch. If xception/
%   inceptionresnetv2's Deep Learning Toolbox Add-Ons aren't installed
%   yet when this reaches them, that backbone is skipped (logged clearly,
%   not silently) rather than the whole run dying -- the other backbones'
%   results are still real and usable, and ensembleGrade.m at the end
%   only ensembles over whichever backbones actually produced a
%   <name>_net.mat file.

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'modules', 'module3_grading'));

dataDir = fullfile(thisDir, '..', 'data', 'train_data', 'images_combined');
outDir = fullfile(thisDir, '..', 'data', 'train_data', 'trained_models');

if ~exist(dataDir, 'dir')
    error('train_module3_multi_dataset:noData', ...
        '%s does not exist -- run combine_datasets.sh first.', dataDir);
end

backbones = {'efficientnetb0', 'resnet50', 'densenet201', 'xception', 'inceptionresnetv2'};
trained = {};
skipped = {};

for i = 1:numel(backbones)
    name = backbones{i};
    fprintf('\n\n########## [%d/%d] %s ##########\n\n', i, numel(backbones), name);
    fg = freeGB();
    fprintf('free disk: %.1f GB\n', fg);
    if fg < 2
        fprintf('SKIPPING %s: free disk (%.1f GB) below 2 GB safety floor.\n', name, fg);
        skipped{end+1} = sprintf('%s (low disk: %.1fGB free)', name, fg); %#ok<AGROW>
        continue;
    end
    try
        r = trainAndEvaluate(name, dataDir, outDir); %#ok<NASGU>
        trained{end+1} = name; %#ok<AGROW>
    catch err
        fprintf('SKIPPING %s: %s\n', name, err.message);
        skipped{end+1} = sprintf('%s (%s)', name, err.message); %#ok<AGROW>
    end
end

fprintf('\n\n########## SUMMARY ##########\n');
fprintf('trained: %s\n', strjoin(trained, ', '));
if ~isempty(skipped)
    fprintf('skipped:\n');
    for i = 1:numel(skipped)
        fprintf('  - %s\n', skipped{i});
    end
end

if numel(trained) < 2
    fprintf('\nLess than 2 backbones trained successfully -- skipping ensemble evaluation (nothing meaningful to average).\n');
else
    fprintf('\n\n########## ENSEMBLE (%d backbones) ##########\n\n', numel(trained));
    ensembleResults = ensembleGrade(dataDir, outDir, trained); %#ok<NASGU>
end

fprintf('\n=== MULTI-DATASET TRAINING + ENSEMBLE EVALUATION COMPLETE ===\n');

function gb = freeGB()
[~, out] = system('df -g / | tail -1');
parts = strsplit(strtrim(out));
gb = str2double(parts{4});
end
