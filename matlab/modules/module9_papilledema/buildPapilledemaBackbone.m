function [lgraph, inputSize] = buildPapilledemaBackbone(name, classWeights, classNames)
%BUILDPAPILLEDEMABACKBONE Load a pretrained backbone and swap its head
%   for 3-class papilledema classification: Papilledema / Pseudopapilledema
%   / Normal.
%
%   Same near-duplication pattern as buildHypertensiveBackbone.m and
%   buildDMEBackbone.m, same reasoning (written without touching shared
%   files while Module 3's training was active; merge candidate once
%   approved). See docs/module9_papilledema_plan.md.
%
%   [lgraph, inputSize] = BUILDPAPILLEDEMABACKBONE(name, classWeights, classNames)

NUM_CLASSES = 3;

if nargin < 2 || isempty(classWeights)
    outputLayer = @(nm) classificationLayer('Name', nm);
else
    outputLayer = @(nm) classificationLayer('Name', nm, 'ClassWeights', classWeights, 'Classes', classNames);
end

switch name
    case 'resnet50'
        net = resnet50;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'fc1000', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_pap', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_fc1000', outputLayer('output'));
    case 'densenet201'
        net = densenet201;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'fc1000', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_pap', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_fc1000', outputLayer('output'));
    case 'efficientnetb0'
        net = efficientnetb0;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'efficientnet-b0|model|head|dense|MatMul', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_pap', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'classification', outputLayer('output'));
    case 'xception'
        net = xception;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'predictions', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_pap', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', outputLayer('output'));
    case 'inceptionresnetv2'
        net = inceptionresnetv2;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'predictions', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_pap', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', outputLayer('output'));
    otherwise
        error('buildPapilledemaBackbone:unknownName', 'Unknown backbone "%s"', name);
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
