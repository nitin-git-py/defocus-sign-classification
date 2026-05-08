function generateLMSDataset(inputFolders, defocusD, sphUM, pupilMM, targetSize, outputDir)
% generateLMSDataset - Generate LMS retinal images using ISETBio
%
% Inputs:
%   inputFolders - cell array of folder paths containing input images
%   defocusD     - vector of defocus values in dioptres e.g. [-1, 1]
%   sphUM        - single spherical aberration value in um e.g. 0.03
%   pupilMM      - pupil diameter in mm e.g. 4
%   targetSize   - output image size e.g. [256 256]
%   outputDir    - output directory for saved .mat files
%
% Example:
%   inputFolders = {
%       'C:\Users\lenovo\OneDrive\Documents\Docs\RIT\PhD\Project\images\train',
%       'C:\Users\lenovo\OneDrive\Documents\Docs\RIT\PhD\Project\images\test',
%       'C:\Users\lenovo\OneDrive\Documents\Docs\RIT\PhD\Project\images\val'
%   };
%   generateLMSDataset(inputFolders, [-1,1], 0.03, 4, [256 256], ...
%       'C:\Users\lenovo\OneDrive\Documents\Docs\RIT\PhD\Project\Python images');

if ~isfolder(outputDir), mkdir(outputDir); end

% Collect all image files from all folders
allFiles = [];
for f = 1:numel(inputFolders)
    files = dir(fullfile(inputFolders{f}, '*.jpg'));
    allFiles = [allFiles; files];
end

totalImages = numel(allFiles);
totalFiles  = totalImages * numel(defocusD);
counter     = 0;

fprintf('Found %d images across %d folders\n', totalImages, numel(inputFolders));
fprintf('Will generate %d LMS files\n', totalFiles);

% Fixed Zernike coefficients (sph only, defocus set per iteration)
z12 = sphUM;

for i = 1:totalImages
    for j = 1:numel(defocusD)

        defocus = defocusD(j);
        counter = counter + 1;

        imgPath = fullfile(allFiles(i).folder, allFiles(i).name);
        [~, imgName, ~] = fileparts(allFiles(i).name);

        fprintf('\nProgress: %d/%d | Image: %s | Defocus: %+.1f D\n', ...
            counter, totalFiles, imgName, defocus);

        % --- Filename ---
        if defocus > 0
            defocusStr = sprintf('p%d', abs(defocus));
        else
            defocusStr = sprintf('m%d', abs(defocus));
        end
        fname = sprintf('%s_def_%s_sph_%.2f.mat', imgName, defocusStr, sphUM);
        fpath = fullfile(outputDir, fname);

        % Skip if already exists
        if isfile(fpath)
            fprintf('Skipping — already exists\n');
            continue;
        end

        % --- Load image and check ---
        imgData = imread(imgPath);
        if size(imgData, 3) == 1
            imgData = cat(3, imgData, imgData, imgData);   % grayscale to RGB
        end

        % --- Scene ---
        scene = sceneFromFile(imgData, 'rgb', 100, 'LCD-Apple');
        scene = sceneSet(scene, 'fov', 5);
        scene = sceneSet(scene, 'resize', targetSize);

        wave = sceneGet(scene, 'wave');
        fprintf('Scene: %d x %d | Wavelengths: %d | Range: %d-%d nm\n', ...
            targetSize(1), targetSize(2), numel(wave), wave(1), wave(end));

        % --- Wavefront ---
        z4          = wvfDefocusDioptersToMicrons(defocus, pupilMM);
        zCoeffs     = zeros(1, 21);
        zCoeffs(5)  = z4;
        zCoeffs(13) = z12;

        wvf = wvfCreate('wave', wave);
        wvf = wvfSet(wvf, 'calc pupil diameter', pupilMM);
        wvf = wvfSet(wvf, 'measured pupil diameter', pupilMM);
        wvf = wvfSet(wvf, 'zcoeffs', zCoeffs);
        wvf = wvfSet(wvf, 'lcaMethod', 'human');
        wvf = wvfCompute(wvf);

        % --- Optics ---
        oi = wvf2oi(wvf);
        oi = oiCompute(oi, scene, 'pad value', 'mean');
        oi = oiCrop(oi, 'border');

        oiSize = oiGet(oi, 'size');
        fprintf('OI size: %d x %d | Wavelengths: %d\n', ...
            oiSize(1), oiSize(2), numel(oiGet(oi, 'wave')));

        if ~isequal(oiSize, targetSize)
            warning('OI size mismatch for %s!', imgName);
        end

        % --- Extract photons ---
        photons = oiGet(oi, 'photons');
        wave    = oiGet(oi, 'wave');

        % --- LMS Conversion ---
        coneSpectra = ieReadSpectra('stockman', wave);
        [r, c, w]   = size(photons);
        photons2D   = reshape(photons, r*c, w);
        LMS2D       = photons2D * coneSpectra;
        LMS         = reshape(LMS2D, r, c, 3);

        for ch = 1:3
            chData      = LMS(:,:,ch);
            LMS(:,:,ch) = chData / max(chData(:));
        end

        % --- Save ---
        save(fpath, 'LMS', 'wave', 'defocus', 'sphUM', ...
            'pupilMM', 'zCoeffs', 'imgName');
        fprintf('Saved: %s\n', fname);

    end
end

fprintf('\nDone. %d files saved to: %s\n', counter, outputDir);

end