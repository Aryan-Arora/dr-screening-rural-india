%TRAIN_MODULE3_APTOS_RETRAIN Retrain all 5 backbones (the original 3 plus
%   xception + inceptionresnetv2, added after the APTOS+IDRiD+DDR
%   experiment below) on APTOS-ONLY data, then ensemble.
%
%   Context: the APTOS+IDRiD+DDR blend (train_module3_multi_dataset.m)
%   was tried to boost class-3/4 volume, but the per-source breakdown
%   showed a real domain gap (aptos 82.2% vs. ddr 68.1%/idrid 68.0% on
%   the same blended test set) -- the same failure mode as the earlier
%   EyePACS experiment. Every backbone's individual accuracy dropped
%   4-8pp relative to the original APTOS-only run, and the 5-way
%   ensemble (75.6% acc / 89.3% sens / 93.8% spec) fell below both the
%   old 3-backbone ensemble (82.5%/90.5%/95.8%) AND the PRD's referable
%   sensitivity target. That run's results are preserved in
%   trained_models_aptos_idrid_ddr_experiment/ for the record, not
%   deleted -- a real, honest negative result, not something to hide.
%
%   This script reverts to APTOS-only (the previously-proven-good data),
%   keeping all 5 backbones (Xception/InceptionResNetV2 weren't in the
%   original 3-backbone APTOS-only run, so this is also a genuine chance
%   to see if they help on the cleaner data, not just a rollback).
%
%   Run headless via: matlab -batch "run('train_module3_aptos_retrain.m')"

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'modules', 'module3_grading'));

dataDir = fullfile(thisDir, '..', 'data', 'train_data', 'images_aptos_retrain');
outDir = fullfile(thisDir, '..', 'data', 'train_data', 'trained_models');

if ~exist(dataDir, 'dir')
    error('train_module3_aptos_retrain:noData', ...
        '%s does not exist.', dataDir);
end

backbones = {'efficientnetb0', 'resnet50', 'densenet201', 'xception', 'inceptionresnetv2'};
trained = {};
skipped = {};

for i = 1:numel(backbones)
    name = backbones{i};
    fprintf('\n\n########## [%d/%d] %s (APTOS-only retrain) ##########\n\n', i, numel(backbones), name);
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
    fprintf('\nLess than 2 backbones trained successfully -- skipping ensemble evaluation.\n');
else
    fprintf('\n\n########## ENSEMBLE (%d backbones) ##########\n\n', numel(trained));
    ensembleResults = ensembleGrade(dataDir, outDir, trained); %#ok<NASGU>
end

fprintf('\n=== APTOS-ONLY RETRAIN + ENSEMBLE EVALUATION COMPLETE ===\n');
fprintf('Compare against trained_models_aptos_idrid_ddr_experiment/ensemble_results.mat\n');
fprintf('and the original 3-backbone result (README: 82.5%%/90.5%%/95.8%%).\n');
fprintf('NEXT STEP (do not skip): re-run calibrateEnsemble.m before wiring up the frontend --\n');
fprintf('the current calibration.mat was fit against a different ensemble entirely.\n');
