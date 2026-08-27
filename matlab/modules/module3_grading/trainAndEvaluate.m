function results = trainAndEvaluate(backboneName, dataDir, outDir)
%TRAINANDEVALUATE Fine-tune one backbone for 5-class ICDR grading and
%   evaluate it on a held-out test split.
%   results = TRAINANDEVALUATE(backboneName, dataDir, outDir) where
%   backboneName is 'resnet50' | 'efficientnetb0' | 'densenet201',
%   dataDir contains class-labeled subfolders (0-4) of the balanced
%   training set, and outDir is where the trained network (.mat) and a
%   results struct get saved.
%
%   Training set is not perfectly class-balanced (class 2 -- the
%   referable/non-referable boundary and the identified confusion
%   bottleneck -- is intentionally over-sampled relative to others), so
%   weighted cross-entropy (inverse class frequency) compensates rather
%   than letting the loss implicitly favor whichever classes are larger.

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(fileparts(mfilename('fullpath')));

fprintf('=== %s: preparing data ===\n', backboneName);
[trainSet, valSet, testSet] = prepareDatastore(dataDir);

counts = countEachLabel(trainSet);
classNames = counts.Label;
freq = counts.Count;
classWeights = sum(freq) ./ (numel(freq) * freq);
classWeights = classWeights(:)';
fprintf('class weights (inverse frequency): %s\n', mat2str(classWeights, 3));

fprintf('=== %s: building network ===\n', backboneName);
[lgraph, inputSize] = buildBackbone(backboneName, classWeights, classNames);

% Fundus images tolerate this augmentation set because none of it
% changes what the retina "is": horizontal flip mirrors left/right eye,
% small rotation/translation/scale mimic normal camera-positioning
% variance during capture, all well within what a real second capture of
% the same eye would look like. No vertical flip -- that would invert
% superior/inferior anatomy, which IS clinically meaningful (unlike
% left/right laterality, which this project doesn't track anyway).
augmenter = imageDataAugmenter( ...
    'RandXReflection', true, ...
    'RandRotation', [-15, 15], ...
    'RandXTranslation', [-15, 15], ...
    'RandYTranslation', [-15, 15], ...
    'RandXScale', [0.9, 1.1], ...
    'RandYScale', [0.9, 1.1]);
augTrain = augmentedImageDatastore(inputSize(1:2), trainSet, ...
    'ColorPreprocessing', 'gray2rgb', 'DataAugmentation', augmenter);
augVal = augmentedImageDatastore(inputSize(1:2), valSet, 'ColorPreprocessing', 'gray2rgb');
augTest = augmentedImageDatastore(inputSize(1:2), testSet, 'ColorPreprocessing', 'gray2rgb');

% Checkpointing restored after a real crash (laptop rebooted mid-run and
% lost ~40 min of ResNet50 progress with no way to recover it). Disk has
% more headroom now -- checkpoints get deleted after this function
% finishes successfully, so the steady-state cost is one in-progress
% backbone's worth, not all three accumulated.
checkpointDir = fullfile(outDir, [backboneName '_checkpoints']);
if ~exist(checkpointDir, 'dir')
    mkdir(checkpointDir);
end

opts = trainingOptions('sgdm', ...
    'InitialLearnRate', 1e-4, ...
    'MiniBatchSize', 16, ...
    'MaxEpochs', 12, ...
    'Shuffle', 'every-epoch', ...
    'ValidationData', augVal, ...
    'ValidationFrequency', 20, ...
    'Verbose', true, ...
    'VerboseFrequency', 10, ...
    'ExecutionEnvironment', 'cpu', ...
    'Plots', 'none', ...
    'CheckpointPath', checkpointDir, ...
    'CheckpointFrequency', 2, ...
    'CheckpointFrequencyUnit', 'epoch');

fprintf('=== %s: training (this will take a while, CPU only) ===\n', backboneName);
trainStart = tic;
[trainedNet, trainInfo] = trainNetwork(augTrain, lgraph, opts);
trainElapsed = toc(trainStart);
fprintf('=== %s: training done in %.1f min ===\n', backboneName, trainElapsed/60);

fprintf('=== %s: evaluating on held-out test set ===\n', backboneName);
predLabels = classify(trainedNet, augTest);
trueLabels = testSet.Labels;

acc = mean(predLabels == trueLabels);
confMat = confusionmat(trueLabels, predLabels);

% Referable/non-referable reframe: ICDR >= 2 is referable, per PRD success
% metric (sensitivity/specificity on referable DR).
trueReferable = double(string(trueLabels)) >= 2;
predReferable = double(string(predLabels)) >= 2;
tp = sum(trueReferable & predReferable);
fn = sum(trueReferable & ~predReferable);
tn = sum(~trueReferable & ~predReferable);
fp = sum(~trueReferable & predReferable);
sensitivity = tp / max(tp + fn, 1);
specificity = tn / max(tn + fp, 1);

results.backbone = backboneName;
results.trainElapsedSec = trainElapsed;
results.testAccuracy = acc;
results.confusionMatrix = confMat;
results.referableSensitivity = sensitivity;
results.referableSpecificity = specificity;
results.numTrain = numel(trainSet.Files);
results.numVal = numel(valSet.Files);
results.numTest = numel(testSet.Files);

fprintf('\n--- %s RESULTS ---\n', backboneName);
fprintf('test accuracy (5-class):     %.3f\n', acc);
fprintf('referable sensitivity:       %.3f  (PRD target: >0.90)\n', sensitivity);
fprintf('referable specificity:       %.3f  (PRD target: >0.85)\n', specificity);
fprintf('confusion matrix (rows=true, cols=pred, classes 0-4):\n');
disp(confMat);

save(fullfile(outDir, [backboneName '_net.mat']), 'trainedNet', 'results', 'trainInfo', '-v7.3');
fprintf('Saved trained network + results to %s\n', fullfile(outDir, [backboneName '_net.mat']));

% Training succeeded and the final model is saved -- the checkpoints were
% only insurance against a mid-run crash, safe to reclaim the disk now.
rmdir(checkpointDir, 's');

end
