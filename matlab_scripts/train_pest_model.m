function train_pest_model(regionName)
    % TRAIN_PEST_MODEL - Train a pest risk model using NDVI + weather data
    % Uses Random Forest (fitcensemble) instead of trainNetwork
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

    % ---- Generate synthetic dataset ----
    numSamples = 200;

    % no_pest samples
    meanNDVI_no   = baseNDVI + 0.2 + 0.05*randn(numSamples/2,1);
    humidity_no   = 50 + 10*rand(numSamples/2,1);
    temp_no       = 25 + 5*rand(numSamples/2,1);
    rainfall_no   = 0 + 5*rand(numSamples/2,1);

    % pest samples
    meanNDVI_pest = baseNDVI - 0.3 + 0.05*randn(numSamples/2,1);
    humidity_pest = 75 + 10*rand(numSamples/2,1);
    temp_pest     = 25 + 5*rand(numSamples/2,1);
    rainfall_pest = 5 + 10*rand(numSamples/2,1);

    % Combine features
    X = [
        meanNDVI_no, temp_no, humidity_no, rainfall_no;
        meanNDVI_pest, temp_pest, humidity_pest, rainfall_pest
    ];

    % Labels
    Y = [repmat("no_pest", numSamples/2,1);
         repmat("pest", numSamples/2,1)];
    Y = categorical(Y, ["no_pest","pest"]);

    % ---- Train Random Forest classifier ----
    fprintf('⚙️ Training Random Forest model...\n');
    t = templateTree('MaxNumSplits',20);
    model = fitcensemble(X, Y, ...
        'Method','Bag', ...
        'Learners', t, ...
        'NumLearningCycles', 100);

    % ---- Save model ----
    modelDir = fullfile(project_root, 'models');
    if ~exist(modelDir,'dir'); mkdir(modelDir); end
    save(fullfile(modelDir, sprintf('pestModel_%s.mat', regionName)), 'model');

    disp('✅ Pest risk training complete (Random Forest).');
end
