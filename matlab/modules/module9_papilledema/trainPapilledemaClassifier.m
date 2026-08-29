function results = trainPapilledemaClassifier(backboneName, dataDir, outDir)
%TRAINPAPILLEDEMACLASSIFIER Fine-tune one backbone for 3-class
%   Papilledema/Pseudopapilledema/Normal classification.
%   Mirrors trainAndEvaluate.m/trainHypertensiveClassifier.m's structure.
%
%   NOT YET RUN -- draft pending review, see
%   docs/module9_papilledema_plan.md. Queued behind Module 3's (and any
%   other approved modules') training -- CPU contention, no GPU here.
%
%   Class imbalance note: Normal (779) outnumbers Papilledema (295) and
%   Pseudopapilledema (295) roughly 2.6:1 -- weighted cross-entropy
%   (inverse class frequency) compensates, same pattern as every other
%   module here.

if ~exist(outDir, 'dir')
    mkdir(outDir);
end

addpath(fileparts(mfilename('fullpath')));

fprintf('=== %s: preparing data ===\n', backboneName);
[trainSet, valSet, testSet] = preparePapilledemaDatastore(dataDir);

counts = countEachLabel(trainSet);
classNames = counts.Label;
freq = counts.Count;
classWeights = sum(freq) ./ (numel(freq) * freq);
classWeights = classWeights(:)';
fprintf('class weights (inverse frequency): %s\n', mat2str(classWeights, 3));

fprintf('=== %s: building network ===\n', backboneName);
[lgraph, inputSize] = buildPapilledemaBackbone(backboneName, classWeights, classNames);

% NO horizontal flip here, unlike every other module's augmenter --
% Papilledema/pseudopapilledema differentiation can depend on disc
% contour details that a flip wouldn't corrupt clinically (left/right
% laterality isn't diagnostic either way), so this mirrors Module 3's
% augmentation set for consistency, but flagged for reconsideration once
% real results come in -- unlike DR grading, there's no strong prior
% either way on whether flipping helps or hurts this specific task.
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

checkpointDir = fullfile(outDir, [backboneName '_pap_checkpoints']);
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

% The clinically critical distinction is TRUE papilledema vs. everything
% else (pseudopapilledema + normal) -- a missed true papilledema means a
% missed brain-disease referral, while pseudopapilledema-as-papilledema
% is a false alarm, not a missed diagnosis. Reporting sensitivity/
% specificity on THIS framing, not the raw 3-class accuracy, since that's
% what actually matters for the referral decision.
truePap = trueLabels == 'Papilledema';
predPap = predLabels == 'Papilledema';
tp = sum(truePap & predPap);
fn = sum(truePap & ~predPap);
tn = sum(~truePap & ~predPap);
fp = sum(~truePap & predPap);
sensitivity = tp / max(tp + fn, 1);
specificity = tn / max(tn + fp, 1);

results.backbone = backboneName;
results.trainElapsedSec = trainElapsed;
results.testAccuracy = acc;
results.confusionMatrix = confMat;
results.papilledemaSensitivity = sensitivity;
results.papilledemaSpecificity = specificity;
results.numTrain = numel(trainSet.Files);
results.numVal = numel(valSet.Files);
results.numTest = numel(testSet.Files);

fprintf('\n--- %s RESULTS ---\n', backboneName);
fprintf('test accuracy (3-class):        %.3f\n', acc);
fprintf('papilledema-vs-rest sensitivity: %.3f  (missed true papilledema = missed brain-disease referral)\n', sensitivity);
fprintf('papilledema-vs-rest specificity: %.3f  (pseudopapilledema false alarms count against this)\n', specificity);
fprintf('confusion matrix (rows=true, cols=pred, order=%s):\n', strjoin(cellstr(classNames), ','));
disp(confMat);

save(fullfile(outDir, [backboneName '_pap_net.mat']), 'trainedNet', 'results', 'trainInfo', '-v7.3');
fprintf('Saved trained network + results to %s\n', fullfile(outDir, [backboneName '_pap_net.mat']));

rmdir(checkpointDir, 's');

end
