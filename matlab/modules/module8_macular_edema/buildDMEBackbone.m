function [lgraph, inputSize] = buildDMEBackbone(name, classWeights, classNames)
%BUILDDMEBACKBONE Load a pretrained backbone and swap its head for
%   3-class Diabetic Macular Edema (DME) risk grading (IDRiD's "Risk of
%   macular edema" column: 0/1/2).
%
%   Separate from buildBackbone.m/buildHypertensiveBackbone.m for the
%   same reason as the latter (see its header comment) -- written while
%   Module 3's training run was active, not yet approved to run. Same
%   flagged cleanup: merge all three into one numClasses-parameterized
%   function once approved.
%
%   [lgraph, inputSize] = BUILDDMEBACKBONE(name, classWeights, classNames)
%   name is one of the same 5 backbones used elsewhere in this project.

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
        lgraph = replaceLayer(lgraph, 'fc1000', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_dme', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_fc1000', outputLayer('output'));
    case 'densenet201'
        net = densenet201;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'fc1000', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_dme', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_fc1000', outputLayer('output'));
    case 'efficientnetb0'
        net = efficientnetb0;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'efficientnet-b0|model|head|dense|MatMul', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_dme', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'classification', outputLayer('output'));
    case 'xception'
        net = xception;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'predictions', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_dme', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', outputLayer('output'));
    case 'inceptionresnetv2'
        net = inceptionresnetv2;
        lgraph = toLayerGraph(net);
        lgraph = replaceLayer(lgraph, 'predictions', fullyConnectedLayer(NUM_CLASSES, 'Name', 'fc_dme', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10));
        lgraph = replaceLayer(lgraph, 'ClassificationLayer_predictions', outputLayer('output'));
    otherwise
        error('buildDMEBackbone:unknownName', 'Unknown backbone "%s"', name);
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
