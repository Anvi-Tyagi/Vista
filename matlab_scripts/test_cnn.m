function test_cnn(imagePath)
    % TEST_CNN - Test trained CNN on a new image
    %
    % Example:
    %   test_cnn('../processed_data/ndvi.tif')

    % ---- Locate project root ----
    script_path   = mfilename('fullpath');
    project_root  = fileparts(fileparts(script_path));

    % ---- Load trained network ----
    load(fullfile(project_root, 'trainedNet.mat'), 'net');

    % ---- Prepare input ----
    inputSize = net.Layers(1).InputSize;
    I = imread(imagePath);

    % Convert grayscale -> RGB if needed
    if size(I,3) == 1
        I = cat(3, I, I, I);
    end

    I_resized = imresize(I, inputSize(1:2));

    % ---- Classify ----
    label = classify(net, I_resized);

    % ---- Show result ----
    imshow(I, []);
    title(sprintf('Predicted: %s', string(label)));
    fprintf('✅ Prediction for %s: %s\n', imagePath, string(label));
end
