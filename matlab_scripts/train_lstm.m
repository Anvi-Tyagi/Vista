function train_lstm(regionName)
% TRAIN_LSTM - Train an LSTM model for NDVI time-series prediction
%
% Example:
%   train_lstm('Rabupura')

%% ---- Paths ----
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
region_folder = fullfile(project_root, 'processed_data', regionName);
ndvi_path = fullfile(region_folder, 'ndvi.tif');

if ~isfile(ndvi_path)
    error('❌ NDVI not found for region %s. Run pipeline first.', regionName);
end

%% ---- Load NDVI ----
ndvi = im2double(imread(ndvi_path));

% Convert spatial NDVI into a synthetic time series
ndvi_values = mean(ndvi, 2, 'omitnan'); 
time = 1:numel(ndvi_values);

%% ---- Normalize ----
mu = mean(ndvi_values);
sigma = std(ndvi_values);
ndvi_norm = (ndvi_values - mu) / sigma;

%% ---- Train/Test ----
XTrain = num2cell(ndvi_norm(1:end-1));
YTrain = num2cell(ndvi_norm(2:end));

%% ---- Define LSTM ----
layers = [ ...
    sequenceInputLayer(1)
    lstmLayer(100,'OutputMode','sequence')
    fullyConnectedLayer(1)
    regressionLayer];

options = trainingOptions('adam', ...
    'MaxEpochs',200, ...
    'GradientThreshold',1, ...
    'Verbose',0, ...
    'Plots','training-progress');

%% ---- Train ----
netLSTM = trainNetwork(XTrain, YTrain, layers, options);

%% ---- Save ----
out_path = fullfile(project_root, 'models', ['lstmNet_' regionName '.mat']);
if ~exist(fullfile(project_root, 'models'),'dir')
    mkdir(fullfile(project_root, 'models'));
end
save(out_path, 'netLSTM','mu','sigma');

disp(['✅ LSTM training complete! Model saved as ' out_path]);

end
