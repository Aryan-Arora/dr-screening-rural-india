%DEMO_MODULE1 Run the Module 1 quality gate on sample fundus images and
%   print the resulting JSON contract fragment.
%
%   Drop one or more .jpg/.png fundus images into
%   matlab/data/sample_images/ before running. If IDRiD/APTOS/Messidor
%   samples aren't available yet, this will just report that the folder
%   is empty.

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'modules', 'module1_quality'));

sampleDir = fullfile(fileparts(mfilename('fullpath')), '..', 'data', 'sample_images');
files = [dir(fullfile(sampleDir, '*.jpg')); dir(fullfile(sampleDir, '*.jpeg')); dir(fullfile(sampleDir, '*.png'))];
% Exclude this script's own output and Module 2's overlay outputs, which
% otherwise get picked up as if they were new input samples.
isOutput = contains({files.name}, {'_out', '_structures', '_vessels'});
files = files(~isOutput);

if isempty(files)
    fprintf('No sample images found in %s\n', sampleDir);
    fprintf('Add a few fundus images (e.g. from IDRiD) and re-run.\n');
    return;
end

for i = 1:numel(files)
    imgPath = fullfile(files(i).folder, files(i).name);
    img = imread(imgPath);

    report = qualityGate(img);

    fprintf('\n--- %s ---\n', files(i).name);
    fprintf('status: %s\n', report.status);
    if isempty(report.reason)
        fprintf('reason: null\n');
    else
        fprintf('reason: %s\n', report.reason);
    end
    fprintf('scores: focus=%.2f illumination=%.2f fov=%.2f\n', ...
        report.scores.focus, report.scores.illumination, report.scores.fov);

    if isfield(report, 'image')
        [~, name] = fileparts(files(i).name);
        outPath = fullfile(sampleDir, sprintf('%s_out.png', name));
        imwrite(report.image, outPath);
        fprintf('output image written to: %s\n', outPath);
    end
end
