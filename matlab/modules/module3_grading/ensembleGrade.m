function results = ensembleGrade(dataDir, modelsDir)
%ENSEMBLEGRADE Load all three trained backbones, average their softmax
%   predictions on the shared held-out test set, and evaluate the
%   ensemble against the PRD's success metrics.
%   results = ENSEMBLEGRADE(dataDir, modelsDir) where modelsDir holds
%   <backbone>_net.mat files from trainAndEvaluate, each trained on the
%   same fixed-seed train/val/test split from prepareDatastore.

addpath(fileparts(mfilename('fullpath')));

backbones = {'efficientnetb0', 'resnet50', 'densenet201'};

[~, ~, testSet] = prepareDatastore(dataDir);
trueLabels = testSet.Labels;
classNames = categories(trueLabels);
numClasses = numel(classNames);
numSamples = numel(testSet.Files);

allProbs = zeros(numSamples, numClasses, numel(backbones));
perBackboneLabels = cell(1, numel(backbones));

for i = 1:numel(backbones)
    name = backbones{i};
    modelFile = fullfile(modelsDir, [name '_net.mat']);
    if ~exist(modelFile, 'file')
        error('ensembleGrade:missingModel', 'Missing trained model: %s', modelFile);
    end
    loaded = load(modelFile, 'trainedNet');
    net = loaded.trainedNet;
    inputSize = net.Layers(1).InputSize;
    augTest = augmentedImageDatastore(inputSize(1:2), testSet, 'ColorPreprocessing', 'gray2rgb');

    probs = predict(net, augTest);
    allProbs(:, :, i) = probs;
    [~, idx] = max(probs, [], 2);
    perBackboneLabels{i} = categorical(classNames(idx), classNames);

    acc = mean(perBackboneLabels{i} == trueLabels);
    fprintf('%-15s standalone test accuracy: %.3f\n', name, acc);
end

% Ensemble: average softmax probabilities across backbones (per PRD:
% "combined via averaged/voted predictions"), then argmax.
avgProbs = mean(allProbs, 3);
[~, ensembleIdx] = max(avgProbs, [], 2);
ensembleLabels = categorical(classNames(ensembleIdx), classNames);

% Agreement: fraction of samples where all 3 backbones' individual
% top-1 predictions agree with each other -- useful downstream as a
% per-case confidence signal for Module 4/explainability review triage.
allAgree = perBackboneLabels{1} == perBackboneLabels{2} & perBackboneLabels{2} == perBackboneLabels{3};

ensembleAcc = mean(ensembleLabels == trueLabels);
confMat = confusionmat(trueLabels, ensembleLabels);

trueReferable = double(string(trueLabels)) >= 2;
predReferable = double(string(ensembleLabels)) >= 2;
tp = sum(trueReferable & predReferable);
fn = sum(trueReferable & ~predReferable);
tn = sum(~trueReferable & ~predReferable);
fp = sum(~trueReferable & predReferable);
sensitivity = tp / max(tp + fn, 1);
specificity = tn / max(tn + fp, 1);

results.ensembleAccuracy = ensembleAcc;
results.confusionMatrix = confMat;
results.referableSensitivity = sensitivity;
results.referableSpecificity = specificity;
results.agreementRate = mean(allAgree);
results.numTest = numSamples;

fprintf('\n=== ENSEMBLE RESULTS (avg of %s) ===\n', strjoin(backbones, ', '));
fprintf('test accuracy (5-class):     %.3f\n', ensembleAcc);
fprintf('referable sensitivity:       %.3f  (PRD target: >0.90)\n', sensitivity);
fprintf('referable specificity:       %.3f  (PRD target: >0.85)\n', specificity);
fprintf('3-way agreement rate:        %.3f\n', results.agreementRate);
fprintf('confusion matrix (rows=true, cols=pred, classes 0-4):\n');
disp(confMat);

save(fullfile(modelsDir, 'ensemble_results.mat'), 'results');

end
