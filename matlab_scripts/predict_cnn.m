function [labelStr, scoreVal] = predict_cnn(regionName)
    % PREDICT_CNN - Predict crop health using CNN model and export for Power BI
    %
    % Example:
    %   [label, score] = predict_cnn('Rabupura')

    % ---- Locate project root ----
    script_path  = mfilename('fullpath');
    project_root = fileparts(fileparts(script_path));

    % ---- Load trained model ----
    modelPath = fullfile(project_root, 'models', ['trainedNet_' regionName '.mat']);
    if ~isfile(modelPath)
        error('❌ CNN model not found: %s. Run train_cnn first.', modelPath);
    end
    load(modelPath, 'net');

    % ---- Load RGB image ----
    rgbPath = fullfile(project_root, 'processed_data', regionName, 'rgb.tif');
    if ~isfile(rgbPath)
        error('❌ RGB image not found for %s. Run pipeline first.', regionName);
    end
    I = imread(rgbPath);

    % ---- Preprocess ----
    inputSize = net.Layers(1).InputSize;
    I = imresize(I, inputSize(1:2));

    % ---- Predict with confidence ----
    [label, scores] = classify(net, I);
    labelStr = char(label);
    scoreVal = max(scores); % confidence of predicted class

    % ---- Print result ----
    fprintf('🌱 Crop Health for %s: %s (%.2f confidence)\n', regionName, labelStr, scoreVal);

    % ---- Save results in processed_data ----
    outCSV = fullfile(project_root, 'processed_data', regionName, 'crop_health.csv');
    T = table({regionName}, datetime("now"), {labelStr}, scoreVal, ...
        'VariableNames', {'Region','Date','CropHealth_Label','HealthScore'});
    writetable(T, outCSV);

    fprintf('✅ Crop health saved to %s\n', outCSV);
end
