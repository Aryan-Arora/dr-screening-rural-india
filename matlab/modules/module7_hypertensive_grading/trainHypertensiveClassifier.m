function results = trainHypertensiveClassifier(backboneName, dataDir, outDir)
%TRAINHYPERTENSIVECLASSIFIER Fine-tune one backbone for binary
%   hypertensive-retinopathy classification, mirroring
%   module3_grading/trainAndEvaluate.m's structure and evaluation
%   pattern (weighted cross-entropy, checkpointing, held-out test eval).
%
%   NOT YET RUN -- draft pending review, see
%   docs/module7_hypertensive_retinopathy_plan.md. Queued to start only
%   after Module 3's multi-dataset training run finishes (CPU
%   contention -- this machine has no GPU/Parallel Computing Toolbox).
%
%   results = TRAINHYPERTENSIVECLASSIFIER(backboneName, dataDir, outDir)
%   where dataDir has class-labeled subfolders ('0'/'1') and outDir is
%   where the trained network + results get saved.

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(fileparts(mfilename('fullpath')));

fprintf('=== %s: preparing data ===\n', backboneName);
[trainSet, valSet, testSet] = prepareHRDCDatastore(dataDir);

counts = countEachLabel(trainSet);
classNames = counts.Label;
freq = counts.Count;
classWeights = sum(freq) ./ (numel(freq) * freq);
classWeights = classWeights(:)';
fprintf('class weights (inverse frequency): %s\n', mat2str(classWeights, 3));

fprintf('=== %s: building network ===\n', backboneName);
[lgraph, inputSize] = buildHypertensiveBackbone(backboneName, classWeights, classNames);

% Same fundus-safe augmentation set as Module 3 (buildBackbone.m's
% reasoning applies identically here: none of it changes what the
% retina "is" -- see trainAndEvaluate.m's header comment).
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

checkpointDir = fullfile(outDir, [backboneName '_htn_checkpoints']);
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

% Binary sensitivity/specificity: '1' = hypertensive retinopathy present.
tp = sum(trueLabels == '1' & predLabels == '1');
fn = sum(trueLabels == '1' & predLabels == '0');
tn = sum(trueLabels == '0' & predLabels == '0');
fp = sum(trueLabels == '0' & predLabels == '1');
sensitivity = tp / max(tp + fn, 1);
specificity = tn / max(tn + fp, 1);

results.backbone = backboneName;
results.trainElapsedSec = trainElapsed;
results.testAccuracy = acc;
results.confusionMatrix = confMat;
results.sensitivity = sensitivity;
results.specificity = specificity;
results.numTrain = numel(trainSet.Files);
results.numVal = numel(valSet.Files);
results.numTest = numel(testSet.Files);

fprintf('\n--- %s RESULTS ---\n', backboneName);
fprintf('test accuracy:  %.3f\n', acc);
fprintf('sensitivity:    %.3f\n', sensitivity);
fprintf('specificity:    %.3f\n', specificity);
fprintf('confusion matrix (rows=true, cols=pred, classes 0/1):\n');
disp(confMat);

save(fullfile(outDir, [backboneName '_htn_net.mat']), 'trainedNet', 'results', 'trainInfo', '-v7.3');
fprintf('Saved trained network + results to %s\n', fullfile(outDir, [backboneName '_htn_net.mat']));

rmdir(checkpointDir, 's');

end
