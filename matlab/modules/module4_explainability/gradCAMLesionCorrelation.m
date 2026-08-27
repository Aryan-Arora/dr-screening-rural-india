function result = gradCAMLesionCorrelation(rawMap, exudateMask, hemorrhageCentroids, maCentroids)
%GRADCAMLESIONCORRELATION Spatial agreement between a Grad-CAM attention
%   map and Module 2's independently-detected lesion locations.
%   result = GRADCAMLESIONCORRELATION(rawMap, exudateMask,
%   hemorrhageCentroids, maCentroids) where rawMap is
%   generateGradCAM's normalized [0,1] attention map, exudateMask is
%   detectExudates' binary mask, and the centroids are from
%   detectHemorrhages/detectMicroaneurysms (all resized to rawMap's
%   resolution by the caller).
%
%   Returns a struct:
%       fractionLesionInHighAttention - fraction of detected-lesion pixels
%           (exudate mask + small disks at hemorrhage/MA centroids) that
%           fall within the top 25% of attention values. High = the CNN's
%           reasoning and the classical lesion detectors agree on WHERE
%           the evidence is, not just on a final number -- meaningful
%           corroboration between two independently-built methods.
%       meanAttentionAtLesions - mean attention value at lesion locations
%       meanAttentionOverall   - mean attention value over the whole map,
%           for comparison (lesion locations should score higher than
%           this if the correlation is real and not coincidental)
%
%   This is a diagnostic/reporting signal, not a validation of either
%   method against ground truth -- two unvalidated methods agreeing with
%   each other is corroborating evidence, not proof either is correct.

REF_SIZE = size(rawMap, 1);
lesionMask = imresize(exudateMask, [REF_SIZE, REF_SIZE]) > 0.5;

[X, Y] = meshgrid(1:REF_SIZE, 1:REF_SIZE);
allCentroids = [hemorrhageCentroids; maCentroids];
for k = 1:size(allCentroids, 1)
    c = allCentroids(k, :);
    lesionMask = lesionMask | ((X - c(1)).^2 + (Y - c(2)).^2 <= 6^2);
end

attentionThreshold = prctile(rawMap(:), 75);
highAttentionMask = rawMap >= attentionThreshold;

if any(lesionMask(:))
    result.fractionLesionInHighAttention = sum(lesionMask(:) & highAttentionMask(:)) / sum(lesionMask(:));
    result.meanAttentionAtLesions = mean(rawMap(lesionMask));
else
    result.fractionLesionInHighAttention = [];
    result.meanAttentionAtLesions = [];
end
result.meanAttentionOverall = mean(rawMap(:));

end
