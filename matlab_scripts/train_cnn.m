function train_cnn(regionName)
% TRAIN_CNN - Train a CNN classifier for processed Sentinel-2 data of a region
%
% Example:
%   train_cnn('Rabupura')

%% ---- Paths ----
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
dataset_path = fullfile(project_root, 'processed_data', regionName);

if ~exist(dataset_path, 'dir')
    error('❌ Processed data not found for region %s. Run pipeline first.', regionName);
end

%% ---- Load dataset ----
imds = imageDatastore(dataset_path, ...
    'IncludeSubfolders', true, ...
    'LabelSource', 'foldernames', ...
    'FileExtensions', {'.tif','.png','.jpg'});

disp('📊 Dataset Summary:');
disp(countEachLabel(imds));

%% ---- Preprocess ----
inputSize = [128 128 3];
augimds = augmentedImageDatastore(inputSize, imds, ...
    'ColorPreprocessing','gray2rgb');

%% ---- Define CNN ----
layers = [
    imageInputLayer(inputSize)
    convolution2dLayer(3,8,'Padding','same')
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2,'Stride',2)

    convolution2dLayer(3,16,'Padding','same')
    batchNormalizationLayer
    reluLayer
    maxPooling2dLayer(2,'Stride',2)

    fullyConnectedLayer(numel(categories(imds.Labels)))
    softmaxLayer
    classificationLayer];

options = trainingOptions('adam', ...
    'MaxEpochs', 10, ...
    'MiniBatchSize', 8, ...
    'Verbose', false, ...
    'Plots','training-progress');

%% ---- Train ----
net = trainNetwork(augimds, layers, options);

%% ---- Save ----
out_path = fullfile(project_root, 'models', ['trainedNet_' regionName '.mat']);
if ~exist(fullfile(project_root, 'models'),'dir')
    mkdir(fullfile(project_root, 'models'));
end
save(out_path, 'net');

disp(['✅ CNN training complete! Model saved as ' out_path]);

end
