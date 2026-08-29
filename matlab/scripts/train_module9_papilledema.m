%TRAIN_MODULE9_PAPILLEDEMA Fine-tune all 5 backbones for 3-class
%   Papilledema/Pseudopapilledema/Normal classification.
%
%   NOT YET RUN. Draft pending review (docs/module9_papilledema_plan.md).
%   Prerequisites: plan approved, download_papilledema_dataset.sh run,
%   Module 3 (and any other approved modules') training finished.

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'modules', 'module9_papilledema'));

dataDir = fullfile(thisDir, '..', 'data', 'train_data', 'images_papilledema');
outDir = fullfile(thisDir, '..', 'data', 'train_data', 'trained_models');

if ~exist(dataDir, 'dir')
    error('train_module9_papilledema:noData', ...
        '%s does not exist -- run download_papilledema_dataset.sh first.', dataDir);
end

backbones = {'efficientnetb0', 'resnet50', 'densenet201', 'xception', 'inceptionresnetv2'};
trained = {};
skipped = {};

for i = 1:numel(backbones)
    name = backbones{i};
    fprintf('\n\n########## [%d/%d] %s (papilledema) ##########\n\n', i, numel(backbones), name);
    try
        r = trainPapilledemaClassifier(name, dataDir, outDir); %#ok<NASGU>
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

fprintf('\n=== MODULE 9 (PAPILLEDEMA) TRAINING COMPLETE ===\n');
