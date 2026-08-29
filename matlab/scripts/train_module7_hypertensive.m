%TRAIN_MODULE7_HYPERTENSIVE Fine-tune the same 5 backbones Module 3 uses
%   for BINARY hypertensive-retinopathy classification, on the HRDC
%   dataset, then ensemble.
%
%   NOT YET RUN. This is a draft pending review (see
%   docs/module7_hypertensive_retinopathy_plan.md) -- do not run until:
%     1. The plan doc has been read and approved.
%     2. download_hrdc_dataset.sh has been run and its output folder
%        structure confirmed/reconciled with prepareHRDCDatastore.m's
%        expected layout (class-named subfolders '0'/'1') -- HRDC's real
%        label format wasn't inspected as part of this draft.
%     3. train_module3_multi_dataset.m (the DR ensemble run) has
%        finished -- this machine has no GPU/Parallel Computing Toolbox,
%        so running both at once would slow both down unpredictably.
%
%   Run headless via: matlab -batch "run('train_module7_hypertensive.m')"

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'modules', 'module7_hypertensive_grading'));

dataDir = fullfile(thisDir, '..', 'data', 'train_data', 'hrdc_sorted');
outDir = fullfile(thisDir, '..', 'data', 'train_data', 'trained_models');

if ~exist(dataDir, 'dir')
    error('train_module7_hypertensive:noData', ...
        '%s does not exist -- run download_hrdc_dataset.sh and sort into class folders first.', dataDir);
end

backbones = {'efficientnetb0', 'resnet50', 'densenet201', 'xception', 'inceptionresnetv2'};
trained = {};
skipped = {};

for i = 1:numel(backbones)
    name = backbones{i};
    fprintf('\n\n########## [%d/%d] %s (hypertensive) ##########\n\n', i, numel(backbones), name);
    try
        r = trainHypertensiveClassifier(name, dataDir, outDir); %#ok<NASGU>
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

fprintf('\n=== MODULE 7 (HYPERTENSIVE RETINOPATHY) TRAINING COMPLETE ===\n');
fprintf('Next: wire the best/ensembled model into classifyHypertensiveRetinopathy.m\n');
fprintf('as an optional learned-model path, falling back to the current AVR-threshold\n');
fprintf('heuristic when no trained model is present -- see the plan doc for the wiring design.\n');
