function [trainSet, valSet, testSet] = prepareDatastore(imageDir)
%PREPAREDATASTORE Load the class-balanced APTOS subset and split it.
%   [trainSet, valSet, testSet] = PREPAREDATASTORE(imageDir) expects
%   imageDir to contain one subfolder per ICDR class (0-4), as produced
%   by download_balanced.sh. Labels come from folder names. Split is
%   stratified 70/15/15 so each class is represented in all three sets
%   despite the small pilot dataset size (770 images).

imds = imageDatastore(imageDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

% Fixed seed: splitEachLabel's 'randomized' mode is unseeded by default,
% so without this every backbone trained separately would get a DIFFERENT
% train/val/test partition -- invalidating both per-backbone comparison
% and ensembling (which requires all backbones to share the same held-out
% test set).
rngState = rng(42, 'twister');
[trainSet, remainder] = splitEachLabel(imds, 0.7, 'randomized');
[valSet, testSet] = splitEachLabel(remainder, 0.5, 'randomized');
rng(rngState);

fprintf('train=%d val=%d test=%d\n', numel(trainSet.Files), numel(valSet.Files), numel(testSet.Files));
fprintf('train class counts:\n');
disp(countEachLabel(trainSet));

end
