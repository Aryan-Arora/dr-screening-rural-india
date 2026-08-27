%TRAIN_MODULE3_ALL Fine-tune all three PRD-specified backbones under a
%   fixed train/val/test split, then evaluate the softmax-averaged
%   ensemble against the PRD's success metrics.
%
%   Run headless via: matlab -batch "run('train_module3_all.m')"
%   Retrains efficientnetb0 (the earlier pilot run used an unseeded split
%   that doesn't match what resnet50/densenet201 need for valid
%   ensembling) plus resnet50 and densenet201. Expect roughly 2-2.5 hours
%   total on CPU for all three plus evaluation.

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'modules', 'module3_grading'));

dataDir = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'train_data', 'images');
outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'train_data', 'trained_models');

backbones = {'efficientnetb0', 'resnet50', 'densenet201'};
allResults = struct();

for i = 1:numel(backbones)
    name = backbones{i};
    fprintf('\n\n########## [%d/%d] %s ##########\n\n', i, numel(backbones), name);
    r = trainAndEvaluate(name, dataDir, outDir);
    allResults.(name) = r;
end

fprintf('\n\n########## ENSEMBLE ##########\n\n');
ensembleResults = ensembleGrade(dataDir, outDir);

fprintf('\n=== ALL TRAINING + ENSEMBLE EVALUATION COMPLETE ===\n');
