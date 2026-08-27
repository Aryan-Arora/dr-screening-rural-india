function run_pipeline(inputImagePath, outputDir)
%RUN_PIPELINE Single-image entry point for the bridge server.
%   RUN_PIPELINE(inputImagePath, outputDir) runs whatever pipeline
%   stages currently exist (Module 1 quality gate, Module 2 segmentation,
%   Module 3 severity grading if trained models are present) on one
%   image, and writes result.json to outputDir matching the PRD's fixed
%   JSON contract (docs/PRD_DR_Screening.docx, section 10).
%
%   Called from bridge-server as:
%     matlab -batch "addpath('.../scripts'); run_pipeline('input.jpg','outdir')"
%   -batch evaluates the statement directly, so the function is called
%   with real arguments rather than through `run` (which is for scripts).
%
%   Fields for pipeline stages not yet implemented (lesions, gradcam,
%   report) are explicitly null rather than fabricated -- see README.

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'modules', 'module1_quality'));
addpath(fullfile(thisDir, '..', 'modules', 'module2_segmentation'));
addpath(fullfile(thisDir, '..', 'modules', 'module3_grading'));
addpath(fullfile(thisDir, '..', 'modules', 'module4_explainability'));

if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

result = struct();
result.quality_check = struct('status', '', 'reason', [], 'scores', struct());
result.severity = [];
result.lesions = [];
result.images = struct('enhanced_url', [], 'segmentation_overlay_url', [], 'gradcam_url', []);
result.report_url = [];

img = imread(inputImagePath);

% ---- Module 1: quality gate ----
qc = qualityGate(img);
result.quality_check.status = qc.status;
result.quality_check.reason = qc.reason;
result.quality_check.scores = qc.scores;

if strcmp(qc.status, 'rejected')
    writeResult(result, outputDir);
    fprintf('run_pipeline: rejected (%s), stopping before segmentation/grading.\n', qc.reason);
    return;
end

% Module 1's CLAHE enhancement helps human/grading legibility, but every
% downstream algorithmic stage below runs on the ORIGINAL image, not this
% one. Found during testing: CLAHE normalizes away exactly the local
% contrast that top-hat-based lesion detection depends on (an exudate
% detector went from finding a real, visible lesion cluster to finding
% nothing at all once fed the enhanced version), and separately, Module
% 3's CNNs were trained on raw dataset images with no enhancement step in
% the training pipeline -- feeding them the enhanced version at inference
% would be a real train/inference distribution mismatch. Disc/fovea
% localization confidence was empirically unaffected either way, but
% there's no reason to risk it. Enhancement is for display only.
gatedImage = qc.image;
enhancedPath = fullfile(outputDir, 'enhanced.png');
imwrite(gatedImage, enhancedPath);
result.images.enhanced_url = 'enhanced.png';

% ---- Module 2: segmentation (on the original image, see note above) ----
try
    seg = segmentStructures(img);
    REF_SIZE = size(seg.vessels.mask, 1);
    overlayBase = imresize(img, [REF_SIZE, REF_SIZE]);
    discColor = 'yellow';
    if strcmp(seg.disc.confidence, 'low'), discColor = 'red'; end
    foveaColor = 'cyan';
    if strcmp(seg.fovea.confidence, 'low'), foveaColor = 'magenta'; end
    overlay = insertShape(overlayBase, 'Circle', [seg.disc.center, seg.disc.radius], 'LineWidth', 3, 'Color', discColor);
    overlay = insertShape(overlay, 'Circle', [seg.fovea.center, round(seg.disc.radius*0.6)], 'LineWidth', 3, 'Color', foveaColor);
    vesselTint = zeros(size(overlay), 'like', overlay);
    vesselTint(:, :, 2) = im2uint8(seg.vessels.mask);
    overlay = imlincomb(0.75, overlay, 0.25, vesselTint);
    overlayPath = fullfile(outputDir, 'segmentation_overlay.png');
    imwrite(overlay, overlayPath);
    result.images.segmentation_overlay_url = 'segmentation_overlay.png';

    % Microaneurysm count is a real classical-CV output but UNVALIDATED
    % against ground truth (see detectMicroaneurysms.m) -- included since
    % the fixed contract expects a number here, not because it's been
    % shown trustworthy. Hemorrhages/exudates/neovascularization are
    % genuinely not implemented, left null rather than guessed.
    result.lesions = struct( ...
        'microaneurysms', seg.microaneurysms.count, ...
        'hemorrhages', seg.hemorrhages.count, ...
        'exudates', seg.exudates.count, ...
        'neovascularization', []);
catch segErr
    fprintf('run_pipeline: segmentation failed, continuing without it: %s\n', segErr.message);
end

% ---- Module 3: severity grading, on the original image (see note above) ----
modelsDir = fullfile(thisDir, '..', 'data', 'train_data', 'trained_models');
backbones = {'efficientnetb0', 'resnet50', 'densenet201'};
modelFiles = cellfun(@(n) fullfile(modelsDir, [n '_net.mat']), backbones, 'UniformOutput', false);
haveAllModels = all(cellfun(@(f) exist(f, 'file') == 2, modelFiles));

if haveAllModels
    try
        classNames = {'0', '1', '2', '3', '4'};
        allProbs = zeros(1, 5, numel(backbones));
        perBackboneClass = zeros(1, numel(backbones));
        % Densenet201 is the designated "explainability backbone" (see
        % generateGradCAM.m) -- kept out of the loop var so it survives
        % for Module 4 below regardless of backbone iteration order.
        explainNet = [];
        for i = 1:numel(backbones)
            loaded = load(modelFiles{i}, 'trainedNet');
            net = loaded.trainedNet;
            if strcmp(backbones{i}, 'densenet201')
                explainNet = net;
            end
            inputSize = net.Layers(1).InputSize;

            % Test-time augmentation: average this backbone's prediction
            % over several augmented views (ttaViews.m) instead of a
            % single forward pass. This is a genuine variance-reduction
            % technique -- distinct from picking whichever single
            % backbone happens to be most confident on one view, which
            % would select for overconfidence rather than accuracy (see
            % README's Module 3 confidence-improvement discussion). Costs
            % 4x the forward passes per backbone; acceptable at
            % single-image inference latency, would NOT be acceptable
            % scaled up to full-dataset training or batch evaluation.
            views = ttaViews(img);
            viewProbs = zeros(numel(views), 5);
            for v = 1:numel(views)
                resized = imresize(views{v}, inputSize(1:2));
                if size(resized, 3) == 1
                    resized = repmat(resized, 1, 1, 3);
                end
                viewProbs(v, :) = predict(net, resized);
            end
            probs = mean(viewProbs, 1);
            allProbs(1, :, i) = probs;
            [~, idx] = max(probs);
            perBackboneClass(i) = idx - 1;
        end
        avgProbs = mean(allProbs, 3);

        % Temperature scaling (calibrateEnsemble.m, post-hoc, no retraining
        % involved): rescales the averaged softmax so confidence values
        % are less overconfident/underconfident relative to true accuracy.
        % Falls back to T=1 (no-op) and the pre-calibration threshold if
        % calibration.mat hasn't been generated yet. log(P)/T is the exact
        % equivalent of temperature-scaling the underlying logits here --
        % see calibrateEnsemble.m's header comment for why.
        REFERABLE_PROB_THRESHOLD = 0.375;
        calFile = fullfile(modelsDir, 'calibration.mat');
        if exist(calFile, 'file') == 2
            calLoaded = load(calFile, 'calResult');
            temperature = calLoaded.calResult.temperature;
            if ~isempty(calLoaded.calResult.referableThreshold)
                REFERABLE_PROB_THRESHOLD = calLoaded.calResult.referableThreshold;
            end
        else
            temperature = 1;
        end
        logProbs = log(max(avgProbs, eps));
        avgProbs = exp(logProbs / temperature - max(logProbs / temperature));
        avgProbs = avgProbs / sum(avgProbs);

        [confidence, idx] = max(avgProbs);
        icdrLevel = idx - 1;
        ensembleAgreement = numel(unique(perBackboneClass)) == 1;

        % referable uses a tuned probability threshold, not a naive
        % argmax-derived "icdr_level >= 2" -- see calibrateEnsemble.m for
        % how REFERABLE_PROB_THRESHOLD above was (re-)derived.
        pReferable = sum(avgProbs(3:5)); % classes '2','3','4' = indices 3-5

        % 4-2-1 rule: hemorrhage-count criterion only (see apply421Rule.m
        % for why venous beading / IRMA aren't implemented). Needs
        % Module 2's segmentation to have succeeded.
        ruleBasedGrade = [];
        if exist('seg', 'var')
            rule421 = apply421Rule(seg.hemorrhages.centroids, seg.disc.center, icdrLevel);
            ruleBasedGrade = rule421.ruleBasedGrade;
        end

        % Needs-review flag: surface genuine uncertainty instead of
        % silently resolving it. Two independent triggers -- backbones
        % disagreeing on the argmax class, or the winning class not
        % clearing a real plurality of the probability mass -- either one
        % means this reading shouldn't be treated as a confident,
        % unqualified result. Deliberately NOT "fall back to whichever
        % single backbone is most confident": that would select for
        % overconfidence, not accuracy (see README's Module 3
        % confidence-improvement discussion for the full reasoning).
        LOW_CONFIDENCE_THRESHOLD = 0.5;
        reviewReasons = {};
        if ~ensembleAgreement
            reviewReasons{end+1} = 'the 3 backbones disagree on the ICDR level';
        end
        if confidence < LOW_CONFIDENCE_THRESHOLD
            reviewReasons{end+1} = sprintf('ensemble confidence (%.0f%%) is below %.0f%%', confidence*100, LOW_CONFIDENCE_THRESHOLD*100);
        end
        needsReview = ~isempty(reviewReasons);
        if needsReview
            reviewReason = ['Needs specialist review: ', strjoin(reviewReasons, '; '), '.'];
        else
            reviewReason = [];
        end

        result.severity = struct( ...
            'icdr_level', icdrLevel, ...
            'referable', pReferable > REFERABLE_PROB_THRESHOLD, ...
            'confidence', confidence, ...
            'ensemble_agreement', ensembleAgreement, ...
            'rule_based_grade', ruleBasedGrade, ... % only ever confirms Severe NPDR via hemorrhage count -- see apply421Rule.m
            'needs_review', needsReview, ...
            'review_reason', reviewReason);

        % ---- Module 4: explainability ----
        % Grad-CAM explains ONE backbone's reasoning (densenet201), not a
        % true ensemble explanation -- see generateGradCAM.m for why.
        % Uses the ensemble's predicted class so the heatmap matches the
        % severity number actually reported, even though it technically
        % reflects one member's internal reasoning.
        try
            gc = generateGradCAM(explainNet, img, idx);
            gradcamPath = fullfile(outputDir, 'gradcam.png');
            imwrite(gc.heatmapOverlay, gradcamPath);
            result.images.gradcam_url = 'gradcam.png';

            if exist('seg', 'var')
                corr = gradCAMLesionCorrelation(gc.rawMap, seg.exudates.mask, seg.hemorrhages.centroids, seg.microaneurysms.centroids);
                fprintf('run_pipeline: Grad-CAM/lesion attention -- at lesions=%.3f, overall=%.3f (higher-at-lesions = agreement between two independent methods, not ground-truth validation)\n', ...
                    corr.meanAttentionAtLesions, corr.meanAttentionOverall);
            end
        catch explainErr
            fprintf('run_pipeline: Grad-CAM failed, continuing without it: %s\n', explainErr.message);
        end
    catch gradeErr
        fprintf('run_pipeline: severity grading failed, continuing without it: %s\n', gradeErr.message);
    end
else
    fprintf('run_pipeline: trained Module 3 models not found in %s, skipping severity grading.\n', modelsDir);
end

% report_url (auto-generated annotated report, PRD Module 4) not
% implemented -- left null, not faked.

writeResult(result, outputDir);
fprintf('run_pipeline: done, wrote %s\n', fullfile(outputDir, 'result.json'));

end

function writeResult(result, outputDir)
jsonStr = jsonencode(result, 'PrettyPrint', true);
fid = fopen(fullfile(outputDir, 'result.json'), 'w');
fwrite(fid, jsonStr);
fclose(fid);
end
