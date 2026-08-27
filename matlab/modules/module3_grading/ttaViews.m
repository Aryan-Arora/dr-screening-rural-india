function views = ttaViews(img)
%TTAVIEWS Generate a small set of augmented views of one fundus image for
%   test-time augmentation, matching the geometric transforms
%   trainAndEvaluate.m's augmenter can produce (reflection, small
%   rotation) so inference-time variance reduction stays consistent with
%   what the networks were trained to be robust to.
%
%   Deliberately no vertical flip and no color/brightness jitter here,
%   same reasoning as trainAndEvaluate.m: vertical flip inverts
%   clinically-meaningful superior/inferior anatomy, and untested color
%   jitter risks shifting illumination-sensitive lesion appearance in a
%   way that hasn't been validated.
%
%   Kept to 4 views (identity, horizontal flip, +/-10 deg rotation) as a
%   deliberate latency tradeoff: this runs per-image at inference time on
%   CPU, not once at training time, so each additional view costs real
%   wall-clock time on every single analysis request.

views = arrayfun(@(v) ttaSingleView(img, v), 1:4, 'UniformOutput', false);

end
