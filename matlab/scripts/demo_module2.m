%DEMO_MODULE2 Run Module 2 (vessel segmentation + disc/fovea localization)
%   on sample fundus images and write annotated overlays.
%
%   Uses the same matlab/data/sample_images/ used by demo_module1 -- in a
%   real pipeline run, Module 2 receives Module 1's accepted/enhanced
%   output, but this demo runs directly on the raw samples since Module 1
%   only rejected 1 of 15 during calibration.

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'modules', 'module2_segmentation'));

sampleDir = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'sample_images');
files = [dir(fullfile(sampleDir, '*.jpg')); dir(fullfile(sampleDir, '*.jpeg')); dir(fullfile(sampleDir, '*.png'))];
isOutput = contains({files.name}, {'_out', '_structures', '_vessels'});
files = files(~isOutput);

if isempty(files)
    fprintf('No sample images found in %s\n', sampleDir);
    return;
end

for i = 1:numel(files)
    imgPath = fullfile(files(i).folder, files(i).name);
    img = imread(imgPath);

    result = segmentStructures(img);

    fprintf('\n--- %s ---\n', files(i).name);
    fprintf('vessel density: %.3f\n', result.vessels.density);
    fprintf('disc:  center=(%d,%d) radius=%.0f confidence=%s\n', ...
        result.disc.center(1), result.disc.center(2), result.disc.radius, result.disc.confidence);
    fprintf('fovea: center=(%d,%d) confidence=%s (contrast=%.2f)\n', ...
        result.fovea.center(1), result.fovea.center(2), result.fovea.confidence, result.fovea.contrast);
    fprintf('lesions (UNVALIDATED, see detectMicroaneurysms.m/detectExudates.m/detectHemorrhages.m): microaneurysm-like=%d exudate-like=%d hemorrhage-like=%d\n', ...
        result.microaneurysms.count, result.exudates.count, result.hemorrhages.count);

    REF_SIZE = size(result.vessels.mask, 1);
    imgResized = imresize(img, [REF_SIZE, REF_SIZE]);

    overlay = imgResized;
    discColor = 'yellow';
    if strcmp(result.disc.confidence, 'low')
        discColor = 'red';
    end
    overlay = insertShape(overlay, 'Circle', [result.disc.center, result.disc.radius], ...
        'LineWidth', 4, 'Color', discColor);

    foveaColor = 'cyan';
    if strcmp(result.fovea.confidence, 'low')
        foveaColor = 'magenta';
    end
    overlay = insertShape(overlay, 'Circle', [result.fovea.center, round(result.disc.radius * 0.6)], ...
        'LineWidth', 3, 'Color', foveaColor);

    vesselOverlay = imgResized;
    vesselTint = zeros(size(vesselOverlay), 'like', vesselOverlay);
    vesselTint(:, :, 2) = im2uint8(result.vessels.mask);
    vesselOverlay = imlincomb(0.6, vesselOverlay, 0.4, vesselTint);

    [~, name] = fileparts(files(i).name);
    imwrite(overlay, fullfile(sampleDir, sprintf('%s_structures.png', name)));
    imwrite(vesselOverlay, fullfile(sampleDir, sprintf('%s_vessels.png', name)));
end
