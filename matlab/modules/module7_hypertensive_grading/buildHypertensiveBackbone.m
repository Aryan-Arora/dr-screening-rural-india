function [lgraph, inputSize] = buildHypertensiveBackbone(name, classWeights, classNames)
%BUILDHYPERTENSIVEBACKBONE Load a pretrained backbone and swap its head
%   for BINARY hypertensive-retinopathy classification (hypertensive vs.
%   non-hypertensive, per the HRDC/ODIR-5K label convention -- see
%   docs/module7_hypertensive_retinopathy_plan.md for dataset choice).
%
%   Deliberately a SEPARATE function from module3_grading/buildBackbone.m
%   rather than a shared one generalized over NUM_CLASSES, for two
%   reasons: (1) this was written while Module 3's multi-dataset training
%   run was actively using buildBackbone.m -- editing a shared function
%   mid-run risked destabilizing hours of in-progress training for a
%   feature that hadn't been approved yet; (2) this whole module is a
%   DRAFT pending review (see the plan doc), not yet approved to run.
%   Once approved, the natural cleanup is to merge this back into
%   buildBackbone.m with a numClasses parameter instead of carrying two
%   near-identical copies long-term -- flagged here so that's not
%   forgotten.
%
%   [lgraph, inputSize] = BUILDHYPERTENSIVEBACKBONE(name, classWeights, classNames)
%   where name is one of 'resnet50', 'efficientnetb0', 'densenet201',
%   'xception', 'inceptionresnetv2' -- same 5 backbones Module 3 uses,
%   reusing whichever Add-Ons are already installed rather than
%   introducing a 6th architecture. classWeights/classNames optional,
%   same weighted-cross-entropy pattern as buildBackbone.m.

NUM_CLASSES = 2;

if nargin < 2 || isempty(classWeights)
    outputLayer = @(nm) classificationLayer('Name', nm);
else
    outputLayer = @(nm) classificationLayer('Name', nm, 'ClassWeights', classWeights, 'Classes', classNames);
end

switch name
    case 'resnet50'
        net = resnet50;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'fc1000', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_htn', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_fc1000', outputLayer('output'));
    case 'densenet201'
        net = densenet201;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'fc1000', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_htn', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_fc1000', outputLayer('output'));
    case 'efficientnetb0'
        net = efficientnetb0;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'efficientnet-b0|model|head|dense|MatMul', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_htn', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'classification', outputLayer('output'));
    case 'xception'
        net = xception;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'predictions', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_htn', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', outputLayer('output'));
    case 'inceptionresnetv2'
        net = inceptionresnetv2;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'predictions', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_htn', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', outputLayer('output'));
    otherwise
        error('buildHypertensiveBackbone:unknownName', 'Unknown backbone "%s"', name);
end

inputSize = lgraph.Layers(1).InputSize;

end

function lgraph = toLayerGraph(net)
if isa(net, 'nnet.cnn.LayerGraph')
    lgraph = net;
else
    lgraph = layerGraph(net);
end
end
