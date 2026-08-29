function [trainSet, valSet, testSet] = prepareHRDCDatastore(imageDir)
%PREPAREHRDCDATASTORE Load the HRDC-style hypertensive-retinopathy set
%   and split it, mirroring module3_grading/prepareDatastore.m's pattern.
%   [trainSet, valSet, testSet] = PREPAREHRDCDATASTORE(imageDir) expects
%   imageDir to contain one subfolder per binary label (e.g. '0'
%   non-hypertensive, '1' hypertensive), as produced by
%   download_hrdc_dataset.sh + its label-sorting step. Split is
%   stratified 70/15/15, same fixed seed convention as Module 3 so
%   results are directly comparable and reproducible.
%
%   NOT YET RUN -- this is part of the draft plan pending review, see
%   docs/module7_hypertensive_retinopathy_plan.md.

imds = imageDatastore(imageDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

rngState = rng(42, 'twister');
[trainSet, remainder] = splitEachLabel(imds, 0.7, 'randomized');
[valSet, testSet] = splitEachLabel(remainder, 0.5, 'randomized');
rng(rngState);

fprintf('train=%d val=%d test=%d\n', numel(trainSet.Files), numel(valSet.Files), numel(testSet.Files));
fprintf('train class counts:\n');
disp(countEachLabel(trainSet));

end
