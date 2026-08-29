function results = ensembleGrade(dataDir, modelsDir, backbones)
%ENSEMBLEGRADE Load all trained backbones, average their softmax
%   predictions on the shared held-out test set, and evaluate the
%   ensemble against the PRD's success metrics.
%   results = ENSEMBLEGRADE(dataDir, modelsDir, backbones) where
%   modelsDir holds <backbone>_net.mat files from trainAndEvaluate, each
%   trained on the same fixed-seed train/val/test split from
%   prepareDatastore. `backbones` is optional, defaults to the original
%   PRD-specified 3; pass a longer cell array (e.g. adding 'xception',
%   'inceptionresnetv2') to ensemble over more.
%
%   When dataDir was built by combining multiple source datasets (see
%   train_module3_multi_dataset.m), filenames are expected to carry a
%   source prefix (e.g. 'aptos_', 'idrid_', 'ddr_') so this can also
%   report PER-SOURCE test accuracy -- the same domain-gap check that
%   caught EyePACS being incompatible with APTOS earlier in this project
%   (60% APTOS-only vs. 36% EyePACS-only on the same blended test set).
%   Sources without a recognized prefix are grouped under 'unknown'.

if nargin < 3 || isempty(backbones)
    backbones = {'efficientnetb0', 'resnet50', 'densenet201'};
end

addpath(fileparts(mfilename('fullpath')));

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
    fprintf('%-20s standalone test accuracy: %.3f\n', name, acc);
end

% Ensemble: average softmax probabilities across backbones (per PRD:
% "combined via averaged/voted predictions"), then argmax.
avgProbs = mean(allProbs, 3);
[~, ensembleIdx] = max(avgProbs, [], 2);
ensembleLabels = categorical(classNames(ensembleIdx), classNames);

% N-way agreement: fraction of samples where EVERY backbone's individual
% top-1 prediction agrees with all the others -- generalized from the
% original hardcoded 3-way check so this works for any ensemble size.
allAgree = true(numSamples, 1);
for i = 2:numel(backbones)
    allAgree = allAgree & (perBackboneLabels{i} == perBackboneLabels{1});
end

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
results.backbones = backbones;

fprintf('\n=== ENSEMBLE RESULTS (avg of %s) ===\n', strjoin(backbones, ', '));
fprintf('test accuracy (5-class):     %.3f\n', ensembleAcc);
fprintf('referable sensitivity:       %.3f  (PRD target: >0.90)\n', sensitivity);
fprintf('referable specificity:       %.3f  (PRD target: >0.85)\n', specificity);
fprintf('%d-way agreement rate:       %.3f\n', numel(backbones), results.agreementRate);
fprintf('confusion matrix (rows=true, cols=pred, classes 0-4):\n');
disp(confMat);

% --- Per-source domain-gap check (see header comment) ---
[~, baseNames] = cellfun(@fileparts, testSet.Files, 'UniformOutput', false);
sourceOf = @(n) regexp(n, '^(aptos|idrid|ddr)_', 'tokens', 'once');
sourceTags = cellfun(@(n) firstOrDefault(sourceOf(n), 'unknown'), baseNames, 'UniformOutput', false);
uniqueSources = unique(sourceTags);

fprintf('\n--- per-source test accuracy (domain-gap check) ---\n');
perSource = struct();
for i = 1:numel(uniqueSources)
    src = uniqueSources{i};
    mask = strcmp(sourceTags, src);
    srcAcc = mean(ensembleLabels(mask) == trueLabels(mask));
    fprintf('%-10s n=%-4d ensemble accuracy: %.3f\n', src, sum(mask), srcAcc);
    perSource.(src) = struct('n', sum(mask), 'accuracy', srcAcc);
end
results.perSourceAccuracy = perSource;

save(fullfile(modelsDir, 'ensemble_results.mat'), 'results');

end

function v = firstOrDefault(tok, default)
if isempty(tok)
    v = default;
else
    v = tok{1};
end
end
