function result = generateGradCAM(net, img, classIdx)
%GENERATEGRADCAM Grad-CAM attention map for one trained backbone's
%   prediction on one image.
%   result = GENERATEGRADCAM(net, img, classIdx) where net is a trained
%   DAGNetwork (as saved by Module 3's trainAndEvaluate.m), img is the
%   ORIGINAL (non-CLAHE-enhanced) fundus image -- see run_pipeline.m's
%   note on why lesion detection and grading both need the original image,
%   the same reasoning applies here -- and classIdx is the 1-based class
%   index to explain (typically the ensemble's predicted class, so the
%   heatmap matches the severity number actually reported).
%
%   Returns a struct:
%       heatmapOverlay - REF_SIZE x REF_SIZE x 3 uint8 image, the network
%                        input overlaid with a jet colormap attention map
%       rawMap         - the raw Grad-CAM score map at network input
%                        resolution, before colormap/overlay (useful for
%                        the spatial-correlation check against lesion
%                        masks)
%
%   Design note: the PRD's ensemble averages 3 architecturally different
%   backbones (different final conv layer shapes/names), so there's no
%   single well-defined "ensemble Grad-CAM" without extra registration
%   work. This computes Grad-CAM from ONE designated backbone (see
%   run_pipeline.m for which) as the shown explanation, while the
%   severity NUMBER still comes from the full ensemble average -- a
%   common, defensible simplification, but means the heatmap technically
%   explains one member's reasoning, not the ensemble's.

dlnet = dag2dlnetwork(net);
inputSize = net.Layers(1).InputSize;

resized = imresize(img, inputSize(1:2));
if size(resized, 3) == 1
    resized = repmat(resized, 1, 1, 3);
end
X = dlarray(single(resized), 'SSCB');

rawMap = gradCAM(dlnet, X, classIdx);
rawMap = extractdata(rawMap);

% Grad-CAM maps can be all-negative/near-zero for a low-confidence or
% "nothing distinctive found" prediction (e.g. a confidently-healthy
% class 0 case) -- normalize defensively rather than dividing by zero.
mapRange = max(rawMap(:)) - min(rawMap(:));
if mapRange < eps
    normMap = zeros(size(rawMap));
else
    normMap = (rawMap - min(rawMap(:))) / mapRange;
end

heatmapRGB = ind2rgb(im2uint8(normMap), jet(256));
heatmapRGB = imresize(heatmapRGB, inputSize(1:2));
baseRGB = im2double(resized);
overlay = 0.55 * baseRGB + 0.45 * heatmapRGB;

result.heatmapOverlay = im2uint8(overlay);
result.rawMap = imresize(normMap, inputSize(1:2));

end
