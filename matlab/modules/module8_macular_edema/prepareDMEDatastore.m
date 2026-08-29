function [trainSet, valSet, testSet] = prepareDMEDatastore(imageDir)
%PREPAREDMEDATASTORE Load the IDRiD DME-risk-labeled set and split it,
%   mirroring module3_grading/prepareDatastore.m's pattern exactly
%   (stratified 70/15/15, fixed seed 42).
%
%   NOT YET RUN -- draft pending review, see
%   docs/module8_macular_edema_plan.md. Expects imageDir with subfolders
%   '0'/'1'/'2' as produced by sort_idrid_dme_labels.py.
%
%   Honest caveat stated up front: IDRiD's DME task has only 455 images
%   total, smaller than any other training set in this project (Module 3's
%   combined set is 5,434). A 70/15/15 split leaves a ~68-image test set
%   -- results here will be far noisier than Module 3's, and should be
%   reported with that in mind, not treated as equally solid.

imds = imageDatastore(imageDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

rngState = rng(42, 'twister');
[trainSet, remainder] = splitEachLabel(imds, 0.7, 'randomized');
[valSet, testSet] = splitEachLabel(remainder, 0.5, 'randomized');
rng(rngState);

fprintf('train=%d val=%d test=%d\n', numel(trainSet.Files), numel(valSet.Files), numel(testSet.Files));
fprintf('train class counts:\n');
disp(countEachLabel(trainSet));

end
