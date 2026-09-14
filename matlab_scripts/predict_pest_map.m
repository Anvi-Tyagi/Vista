function predict_pest_map(regionName)
% PREDICT_PEST_MAP - Apply trained pestModel_<region>.mat to latest NDVI and save map
% Usage:
%   predict_pest_map('Rabupura')

script_path  = mfilename('fullpath');
project_root = fileparts(fileparts(script_path));
region_folder = fullfile(project_root, 'processed_data', regionName);
modelFile = fullfile(project_root,'models', sprintf('pestModel_%s.mat', regionName));
if ~exist(modelFile,'file')
    error('Model file not found: %s. Run train_pest_model first.', modelFile);
end
S = load(modelFile,'model');
model = S.model;

% find most recent NDVI
d = dir(fullfile(region_folder, '**', 'ndvi.tif'));
if isempty(d)
    error('No ndvi.tif found under %s', region_folder);
end
[~, idx] = max([d.datenum]);
ndviPath = fullfile(d(idx).folder, d(idx).name);
fprintf('📂 Using NDVI: %s\n', ndviPath);

ndvi = im2double(imread(ndviPath));
[h,w] = size(ndvi);
patchSize = 32;
stride = patchSize; % non-overlapping; reduce stride for smoother map

% attempt to load optional indices for the same folder
ndwiPath = fullfile(d(idx).folder,'ndwi.tif'); hasNDWI = isfile(ndwiPath);
if hasNDWI, ndwi = im2double(imread(ndwiPath)); end
saviPath = fullfile(d(idx).folder,'savi.tif'); hasSAVI = isfile(saviPath);
if hasSAVI, savi = im2double(imread(saviPath)); end

pest_map = zeros(h,w);

fprintf('🔍 Sliding window prediction (patch %d x %d)...\n', patchSize, patchSize);
for y = 1:stride:(h-patchSize+1)
    for x = 1:stride:(w-patchSize+1)
        pNDVI = ndvi(y:y+patchSize-1, x:x+patchSize-1);
        meanNDVI = mean(pNDVI(:),'omitnan');
        stdNDVI  = std(pNDVI(:),'omitnan');

        if hasNDWI
            pNDWI = ndwi(y:y+patchSize-1, x:x+patchSize-1);
            meanNDWI = mean(pNDWI(:),'omitnan');
        else
            meanNDWI = nan;
        end
        if hasSAVI
            pSAVI = savi(y:y+patchSize-1, x:x+patchSize-1);
            meanSAVI = mean(pSAVI(:),'omitnan');
        else
            meanSAVI = nan;
        end

        feat = [meanNDVI, stdNDVI, meanNDWI, meanSAVI];
        % replace nan with model-acceptable value
        feat(isnan(feat)) = 0;

        try
            lbl = predict(model, feat);
        catch
            % fitctree/ensemble accept row vectors; if not, transpose
            lbl = predict(model, feat);
        end

        if categorical(lbl) == categorical("pest")
            pest_map(y:y+patchSize-1, x:x+patchSize-1) = 1;
        end
    end
end

% save preview and .mat
outPNG = fullfile(d(idx).folder, 'pest_map.png');
outMAT = fullfile(d(idx).folder, 'pest_map.mat');
imwrite(uint8(pest_map*255), outPNG);
save(outMAT, 'pest_map');

fprintf('✅ Pest map saved: %s and %s\n', outPNG, outMAT);

end
