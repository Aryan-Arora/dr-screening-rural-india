%TRAIN_MODULE8_DME Fine-tune all 5 backbones for 3-class Diabetic Macular
%   Edema (DME) risk grading, using IDRiD's "Risk of macular edema" labels.
%
%   NOT YET RUN. Draft pending review (docs/module8_macular_edema_plan.md).
%   Prerequisites before running:
%     1. Plan doc read and approved.
%     2. sort_idrid_dme_labels.py run to build images_idrid_dme/.
%     3. Module 3's (and, if also approved, Module 7's) training finished
%        -- CPU contention, no GPU on this machine.

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'modules', 'module8_macular_edema'));

dataDir = fullfile(thisDir, '..', 'data', 'train_data', 'images_idrid_dme');
outDir = fullfile(thisDir, '..', 'data', 'train_data', 'trained_models');

if ~exist(dataDir, 'dir')
    error('train_module8_dme:noData', ...
        '%s does not exist -- run sort_idrid_dme_labels.py first.', dataDir);
end

backbones = {'efficientnetb0', 'resnet50', 'densenet201', 'xception', 'inceptionresnetv2'};
trained = {};
skipped = {};

for i = 1:numel(backbones)
    name = backbones{i};
    fprintf('\n\n########## [%d/%d] %s (DME) ##########\n\n', i, numel(backbones), name);
    try
        r = trainDMEClassifier(name, dataDir, outDir); %#ok<NASGU>
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

fprintf('\n=== MODULE 8 (DME) TRAINING COMPLETE ===\n');
fprintf('Only 455 total images (IDRiD) -- results will be noisier than Module 3/7.\n');
