function img2 = ttaSingleView(img, viewIdx)
%TTASINGLEVIEW One of ttaViews.m's 4 augmented views, selected by index.
%   Factored out so calibrateEnsemble.m can apply the identical transform
%   set image-by-image during calibration, keeping the calibrated
%   temperature/threshold consistent with what run_pipeline.m actually
%   does at inference time (TTA-averaged, not single-view) predictions.

switch viewIdx
    case 1
        img2 = img;
    case 2
        img2 = fliplr(img);
    case 3
        img2 = imrotate(img, 10, 'bilinear', 'crop');
    case 4
        img2 = imrotate(img, -10, 'bilinear', 'crop');
    otherwise
        error('ttaSingleView:badIndex', 'viewIdx must be 1-4.');
end

end
