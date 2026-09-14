function train_pest_model(regionName)
    % TRAIN_PEST_MODEL - Train a pest risk model using NDVI + weather data
    %
    % Example:
    %   train_pest_model('Rabupura')

    % ---- Locate project root ----
    script_path  = mfilename('fullpath');
    project_root = fileparts(fileparts(script_path));
    region_folder = fullfile(project_root, 'processed_data', regionName);

    % ---- Load NDVI ----
    ndvi_path = fullfile(region_folder, 'ndvi.tif');
    if ~exist(ndvi_path, 'file')
        error('❌ NDVI file not found for region %s', regionName);
    end
    ndvi = im2double(imread(ndvi_path));
    baseNDVI = mean(ndvi(:),'omitnan');

    % ---- Dataset sizes ----
    n = 100; % no_pest samples
    m = 100; % pest samples

    % ---- Generate no_pest samples ----
    meanNDVI_no   = baseNDVI + 0.2 + 0.05*randn(n,1);
    humidity_no   = 50 + 10*rand(n,1);
    temp_no       = 25 + 5*rand(n,1);
    rainfall_no   = 0 + 5*rand(n,1);

    % ---- Generate pest samples ----
    meanNDVI_pest = baseNDVI - 0.3 + 0.05*randn(m,1);
    humidity_pest = 75 + 10*rand(m,1);
    temp_pest     = 25 + 5*rand(m,1);
    rainfall_pest = 5 + 10*rand(m,1);

    % ---- Combine ----
    X_no   = [meanNDVI_no, temp_no, humidity_no, rainfall_no];
    X_pest = [meanNDVI_pest, temp_pest, humidity_pest, rainfall_pest];
    X = [X_no; X_pest];

    Y = [repmat("no_pest", n,1); repmat("pest", m,1)];
    Y = categorical(Y, ["no_pest","pest"]);  % ✅ force both classes

    % ---- Debugging ----
    disp('Unique classes in Y:');
    disp(categories(Y));
    disp('Class counts:');
    disp(countcats(Y));

    % ---- Define ANN classifier ----
    layers = [
        featureInputLayer(size(X,2))
        fullyConnectedLayer(8)
        reluLayer
        fullyConnectedLayer(2)   % pest vs no_pest
        softmaxLayer
        classificationLayer];

    % ---- Training Options ----
    options = trainingOptions('adam', ...
        'MaxEpochs', 10, ... % reduce for debug
        'MiniBatchSize', 16, ...
        'Verbose', true);

    % ---- Train Network ----
    netPest = trainNetwork(X, Y, layers, options);

    % ---- Save Trained Model ----
    modelDir = fullfile(project_root, 'models');
    if ~exist(modelDir, 'dir'); mkdir(modelDir); end
    save(fullfile(modelDir, 'pestNet.mat'), 'netPest');

    disp('✅ Pest risk training complete. Model saved as pestNet.mat');
end
