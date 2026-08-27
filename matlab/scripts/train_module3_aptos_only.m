%TRAIN_MODULE3_APTOS_ONLY Retrain all 3 backbones on the APTOS-only
%   expanded dataset (dropping EyePACS after diagnosing a real domain-gap
%   problem: EyePACS images dragged accuracy from 60%->36% and specificity
%   from 85%->67% on a per-source breakdown, while APTOS-only performance
%   was the best result of the whole project). Retrains EfficientNet-B0
%   too (it was previously trained on the mixed set) so all 3 ensemble
%   members share the same training distribution.
%
%   Run headless via: matlab -batch "run('train_module3_aptos_only.m')"

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'modules', 'module3_grading'));

dataDir = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'train_data', 'images_aptos_only');
outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'train_data', 'trained_models');

backbones = {'resnet50', 'densenet201', 'efficientnetb0'};
allResults = struct();

for i = 1:numel(backbones)
    name = backbones{i};
    fprintf('\n\n########## [%d/%d] %s ##########\n\n', i, numel(backbones), name);
    r = trainAndEvaluate(name, dataDir, outDir);
    allResults.(name) = r;
end

fprintf('\n\n########## ENSEMBLE ##########\n\n');
ensembleResults = ensembleGrade(dataDir, outDir);

fprintf('\n=== ALL TRAINING + ENSEMBLE EVALUATION COMPLETE (APTOS-only) ===\n');
