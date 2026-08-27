function [lgraph, inputSize] = buildBackbone(name, classWeights, classNames)
%BUILDBACKBONE Load a pretrained backbone and swap its head for 5-class
%   ICDR grading.
%   [lgraph, inputSize] = BUILDBACKBONE(name, classWeights, classNames)
%   where name is one of 'resnet50', 'efficientnetb0', 'densenet201'.
%   Each network's final classification layer name differs, so the swap
%   is per-network rather than a generic loop over the last N layers.
%
%   classWeights/classNames are optional; when supplied, the replacement
%   classification layer uses weighted cross-entropy (inverse class
%   frequency) instead of uniform weighting -- needed once the training
%   set stops being perfectly balanced across classes.

NUM_CLASSES = 5;

if nargin < 2 || isempty(classWeights)
    outputLayer = @(nm) classificationLayer('Name', nm);
else
    outputLayer = @(nm) classificationLayer('Name', nm, 'ClassWeights', classWeights, 'Classes', classNames);
end

switch name
    case 'resnet50'
        net = resnet50;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'fc1000', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_dr', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_fc1000', outputLayer('output'));
    case 'densenet201'
        net = densenet201;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'fc1000', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_dr', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_fc1000', outputLayer('output'));
    case 'efficientnetb0'
        net = efficientnetb0;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'efficientnet-b0|model|head|dense|MatMul', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_dr', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'classification', outputLayer('output'));
    otherwise
        error('buildBackbone:unknownName', 'Unknown backbone "%s"', name);
end

inputSize = lgraph.Layers(1).InputSize;

end

function lgraph = toLayerGraph(net)
%TOLAYERGRAPH Pretrained-weight networks come back as DAGNetwork objects,
%   which replaceLayer can't operate on directly -- LayerGraph can.
%   'Weights','none' calls return a LayerGraph already, hence the check.
if isa(net, 'nnet.cnn.LayerGraph')
    lgraph = net;
else
    lgraph = layerGraph(net);
end
end
