function [trainSet, valSet, testSet] = preparePapilledemaDatastore(imageDir)
%PREPAREPAPILLEDEMADATASTORE Load the Papilledema/Pseudopapilledema/Normal
%   set and split it, same 70/15/15 fixed-seed pattern as every other
%   module in this project.
%
%   NOT YET RUN -- draft pending review, see docs/module9_papilledema_plan.md.
%   Expects imageDir with subfolders exactly named 'Papilledema',
%   'Pseudopapilledema', 'Normal' (the Kaggle mirror's real folder names,
%   confirmed by downloading and inspecting it directly: 295/295/779
%   images respectively, 1,369 total).

imds = imageDatastore(imageDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');

rngState = rng(42, 'twister');
[trainSet, remainder] = splitEachLabel(imds, 0.7, 'randomized');
[valSet, testSet] = splitEachLabel(remainder, 0.5, 'randomized');
rng(rngState);

fprintf('train=%d val=%d test=%d\n', numel(trainSet.Files), numel(valSet.Files), numel(testSet.Files));
fprintf('train class counts:\n');
disp(countEachLabel(trainSet));

end
