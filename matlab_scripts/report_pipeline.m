function report_pipeline(regionName)
% REPORT_PIPELINE - Run all models and produce final CSV report (Power BI ready)
% Usage:
%   report_pipeline('Rabupura')

%% --- Setup paths ---
script_path  = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
processed_root = fullfile(project_root, 'processed_data', regionName);
reports_root = fullfile(project_root, 'reports');
models_root  = fullfile(project_root, 'models');
if ~exist(reports_root,'dir'), mkdir(reports_root); end

status = struct();
status.Region = regionName;
status.Date = string(datetime('now'));

%% 1) Process satellite indices
try
    process_satellite(regionName);
    status.Indices = "OK";
catch ME
    status.Indices = "ERROR: " + string(ME.message);
end

%% 2) Run pipeline
try
    run_pipeline(regionName);
    status.Pipeline = "OK";
catch ME
    status.Pipeline = "ERROR: " + string(ME.message);
end

%% 3) Soil moisture model
try
    if exist('soil_moisture_model','file')
        soil_moisture_model(regionName);
        status.SoilMoisture = "OK";
    else
        status.SoilMoisture = "MISSING";
    end
catch ME
    status.SoilMoisture = "ERROR: " + string(ME.message);
end

%% 4) Crop health CNN
try
    cnnModelPath = fullfile(models_root, ['trainedNet_' regionName '.mat']);
    if isfile(cnnModelPath) && exist('predict_cnn','file')
        [healthLabel, healthScore] = predict_cnn(regionName);
        status.CropHealth = string(healthLabel);
        status.HealthScore = healthScore;

        % Copy CSV for Power BI
        cropCSV = fullfile(processed_root, 'crop_health.csv');
        if isfile(cropCSV)
            copyfile(cropCSV, fullfile(reports_root, ['crop_health_' regionName '.csv']));
        end
    else
        status.CropHealth = "MISSING";
        status.HealthScore = NaN;
    end
catch ME
    status.CropHealth = "ERROR: " + string(ME.message);
    status.HealthScore = NaN;
end

%% 5) LSTM model
try
    if exist('train_lstm','file')
        train_lstm(regionName);
        status.LSTM = "OK";
    else
        status.LSTM = "MISSING";
    end
catch ME
    status.LSTM = "ERROR: " + string(ME.message);
end

%% 6) Pest risk
try
    pestModelPath = fullfile(models_root, sprintf('pestModel_%s.mat', regionName));
    if ~isfile(pestModelPath) && exist('train_pest_model','file')
        train_pest_model(regionName);
    end
    if exist('predict_pest_map','file')
        predict_pest_map(regionName);
        status.PestRisk = "OK";
    else
        status.PestRisk = "MISSING";
    end
catch ME
    status.PestRisk = "ERROR: " + string(ME.message);
end

%% --- Save Final Report (CSV) ---
T = struct2table(status);

outCSV = fullfile(reports_root, sprintf('final_report_%s.csv', regionName));
if isfile(outCSV)
    % append new row
    oldT = readtable(outCSV);
    T = [oldT; T];
end
writetable(T, outCSV);

fprintf('✅ Final report saved: %s\n', outCSV);

end
