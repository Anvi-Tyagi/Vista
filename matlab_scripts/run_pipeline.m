function run_pipeline(regionName, weatherData)
    if nargin < 2
        weatherData = [30 70 0.5]; % default [temp, humidity, soilMoisture]
    end

    %% ---- Paths ----
    project_root   = '/Users/adityamehrotra/Desktop/VistaProject';
    raw_root       = fullfile(project_root,'raw_data',regionName);
    processed_root = fullfile(project_root,'processed_data',regionName);
    reports_root   = fullfile(project_root,'reports');

    if ~exist(processed_root,'dir'), mkdir(processed_root); end
    if ~exist(reports_root,'dir'), mkdir(reports_root); end

    %% ---- Load Bands ----
    try
        red   = double(imread(fullfile(raw_root, 'B04.tif')));
        nir   = double(imread(fullfile(raw_root, 'B08.tif')));
        green = double(imread(fullfile(raw_root, 'B03.tif')));
        blue  = double(imread(fullfile(raw_root, 'B02.tif')));
        swir1 = double(imread(fullfile(raw_root, 'B11.tif')));
        swir2 = double(imread(fullfile(raw_root, 'B12.tif')));
    catch ME
        error('❌ Missing band in %s: %s', raw_root, ME.message);
    end

    % Resize SWIRs to match NIR resolution
    swir1_resized = imresize(swir1, size(nir));
    swir2_resized = imresize(swir2, size(nir));
    swir_combined = (swir1_resized + swir2_resized) / 2;

    %% ---- Cloud Mask ----
    cloud_mask = (blue > 0.25 | green > 0.25);

    %% ---- Vegetation Indices ----
    ndvi = (nir - red) ./ (nir + red + eps);
    ndvi(cloud_mask) = NaN; 
    save_with_preview(ndvi, fullfile(processed_root,'ndvi'));

    ndwi = (green - nir) ./ (green + nir + eps);
    ndwi(cloud_mask) = NaN; 
    save_with_preview(ndwi, fullfile(processed_root,'ndwi'));

    savi = (1.5 * (nir - red)) ./ (nir + red + 0.5);
    savi(cloud_mask) = NaN; 
    save_with_preview(savi, fullfile(processed_root,'savi'));

    soil_moisture = (nir - swir_combined) ./ (nir + swir_combined + eps);
    soil_moisture(cloud_mask) = NaN; 
    save_with_preview(soil_moisture, fullfile(processed_root,'soil_moisture'));

    %% ---- RGB Composite ----
    rgb = cat(3, stretch(red), stretch(green), stretch(blue));
    rgb(repmat(cloud_mask,[1,1,3])) = 1; % clouds → white
    imwrite(im2uint8(rgb), fullfile(processed_root,'rgb.tif'));

    %% ---- Risk Assessment ----
    avgNDVI = mean(ndvi(:),'omitnan');
    avgNDWI = mean(ndwi(:),'omitnan');
    avgSAVI = mean(savi(:),'omitnan');
    avgSoil = mean(soil_moisture(:),'omitnan');

    pestRisk = "low";
    if avgNDVI < 0.4 && weatherData(2) > 70
        pestRisk = "high";
    end

    action = "Continue monitoring";
    if avgSoil < 0.3
        action = "Irrigation recommended";
    elseif pestRisk == "high"
        action = "Pest management required";
    end

    %% ---- Save Masks ----
    water_mask = ndwi > 0.3;
    pest_map   = ndvi < (nanmean(ndvi(:)) - 0.1);
    stress_map = savi < (nanmean(savi(:)) - 0.1);

    save_mask(water_mask, processed_root, 'water_map');
    save_mask(pest_map, processed_root, 'pest_map');
    save_mask(stress_map, processed_root, 'stress_map');

    %% ---- Excel Report ----
    reportFile = fullfile(reports_root,'farmer_reports.xlsx');
    T = table({regionName}, datetime("now"), avgNDVI, avgNDWI, avgSAVI, avgSoil, {pestRisk}, {action}, ...
        'VariableNames', {'Region','Date','AvgNDVI','AvgNDWI','AvgSAVI','AvgSoilMoisture','PestRisk','Action'});

    if isfile(reportFile)
        existingT = readtable(reportFile);
        T = [existingT; T];
    end
    writetable(T, reportFile);

    %% ---- Logging for Backend Parsing ----
    fprintf('✅ Pipeline finished for %s\n', regionName);
    fprintf('📊 Report updated: %s\n', reportFile);
    fprintf('NDVI mean: %.4f\n', avgNDVI);
    fprintf('NDWI mean: %.4f\n', avgNDWI);
    fprintf('SAVI mean: %.4f\n', avgSAVI);
    fprintf('Soil Moisture mean: %.4f\n', avgSoil);
    fprintf('Pest Risk: %s\n', pestRisk);
    fprintf('Recommended Action: %s\n', action);
end

%% ---- Utilities ----
function save_with_preview(img, basepath)
    img = double(img); img(isnan(img)) = 0;

    % Safe scaling
    vmin = min(img(:)); vmax = max(img(:));
    if isempty(vmin) || isempty(vmax) || vmin == vmax
        scaled = zeros(size(img));
    else
        scaled = mat2gray(img, [vmin, vmax]);
    end

    % Save TIFF
    imwrite(im2uint16(scaled), [basepath '.tif']);

    % Save preview (robust)
    try
        fig = figure('visible','off');
        imagesc(img); axis off; axis image; colormap(parula); colorbar;
        exportgraphics(gca, [basepath '.jpg'], 'Resolution',150);
        close(fig);
    catch
        warning('⚠️ Could not export preview for %s', basepath);
    end
end

function save_mask(mask, folder, name)
    mask = uint8(mask * 255);
    imwrite(mask, fullfile(folder,[name '.png']));

    try
        fig = figure('visible','off');
        imagesc(mask); axis off; axis image; colormap(hot); colorbar;
        exportgraphics(gca, fullfile(folder,[name '.jpg']), 'Resolution',150);
        close(fig);
    catch
        warning('⚠️ Could not export preview for %s', name);
    end
end

function out = stretch(img)
    img = double(img); img(isnan(img)) = 0;
    p2 = prctile(img(:),2); p98 = prctile(img(:),98);
    if p2 >= p98
        out = mat2gray(img);
    else
        out = imadjust(mat2gray(img), [p2 p98]/max(img(:)), []);
    end
end
