function soil_moisture_model(regionName)
% SOIL_MOISTURE_MODEL - Train soil moisture regression model using NDWI + SAVI
%
% Example:
%   soil_moisture_model('Rabupura')

%% ---- Paths ----
script_path = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
region_folder = fullfile(project_root, 'processed_data', regionName);

ndwi_path = fullfile(region_folder, 'ndwi.tif');
savi_path = fullfile(region_folder, 'savi.tif');

if ~isfile(ndwi_path) || ~isfile(savi_path)
    error('❌ Missing NDWI or SAVI for region %s. Run pipeline first.', regionName);
end

ndwi = im2double(imread(ndwi_path));
savi = im2double(imread(savi_path));

%% ---- Prepare features ----
X = [ndwi(:), savi(:)];

%% ---- Synthetic labels (replace with ground truth if available) ----
Y = 0.2 + 0.6*rand(size(ndwi(:))); % 0.2–0.8 range

%% ---- Train regression model ----
model = fitrlinear(X, Y);

%% ---- Predict ----
YPred = predict(model, X);
soilMoistureMap = reshape(YPred, size(ndwi));

%% ---- Save results ----
out_tif = fullfile(region_folder, 'soil_moisture_model.tif');
imwrite(mat2gray(soilMoistureMap), out_tif);

out_model = fullfile(project_root, 'models', ['soilMoistureModel_' regionName '.mat']);
if ~exist(fullfile(project_root, 'models'),'dir')
    mkdir(fullfile(project_root, 'models'));
end
save(out_model, 'model');

disp(['✅ Soil moisture model complete! Model saved in ' out_model]);

end
