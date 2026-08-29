function results = trainDMEClassifier(backboneName, dataDir, outDir)
%TRAINDMECLASSIFIER Fine-tune one backbone for 3-class DME risk grading.
%   Mirrors trainAndEvaluate.m/trainHypertensiveClassifier.m's structure.
%
%   NOT YET RUN -- draft pending review, see
%   docs/module8_macular_edema_plan.md. Queued behind Module 3's and
%   Module 7's training (CPU contention, no GPU on this machine).

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(fileparts(mfilename('fullpath')));

fprintf('=== %s: preparing data ===\n', backboneName);
[trainSet, valSet, testSet] = prepareDMEDatastore(dataDir);

counts = countEachLabel(trainSet);
classNames = counts.Label;
freq = counts.Count;
classWeights = sum(freq) ./ (numel(freq) * freq);
classWeights = classWeights(:)';
fprintf('class weights (inverse frequency): %s\n', mat2str(classWeights, 3));

fprintf('=== %s: building network ===\n', backboneName);
[lgraph, inputSize] = buildDMEBackbone(backboneName, classWeights, classNames);

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

checkpointDir = fullfile(outDir, [backboneName '_dme_checkpoints']);
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

% "Referable" DME reframe, analogous to Module 3's referable-DR framing:
% grade >=1 (any edema risk) needs closer follow-up per IDRiD's own scale.
trueReferable = double(string(trueLabels)) >= 1;
predReferable = double(string(predLabels)) >= 1;
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

fprintf('\n--- %s RESULTS (n=%d test images -- small, expect noisy numbers) ---\n', backboneName, results.numTest);
fprintf('test accuracy (3-class):  %.3f\n', acc);
fprintf('referable sensitivity:    %.3f\n', sensitivity);
fprintf('referable specificity:    %.3f\n', specificity);
fprintf('confusion matrix (rows=true, cols=pred, classes 0-2):\n');
disp(confMat);

save(fullfile(outDir, [backboneName '_dme_net.mat']), 'trainedNet', 'results', 'trainInfo', '-v7.3');
fprintf('Saved trained network + results to %s\n', fullfile(outDir, [backboneName '_dme_net.mat']));

rmdir(checkpointDir, 's');

end
