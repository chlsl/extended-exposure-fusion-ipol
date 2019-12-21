function run_ef(varargin)
% Read images, run exposure_fusion.m and write results. With Octve or Matlab.
%
% function run_ef(varargin)
%
% For help, call the function without parameters.
% The output image, as well as intermediary results, are saved in the current
% directory.
%
% Charles Hessel, CMLA, ENS Paris-Saclay -- December 2019.
% Associated to an IPOL paper (http://www.ipol.im/pub/pre/278/), see README.

if exist('OCTAVE_VERSION', 'builtin')       % we're in Octave
    pkg load image
    arg_list = argv();
    warning('off', 'Octave:legacy-function');
else                                        % we're in Matlab
    arg_list = varargin;
end

%%% Add files to path (so that script can be called from outside its directory)
[scriptPath, scriptName, scriptExt] = fileparts(mfilename('fullpath'));
addpath( scriptPath, [scriptPath '/exposureFusion'])

%%% Read/Check parameters
usage = sprintf([...
  'Usage: octave -W -qf run_ef.m Wsat Bsat nScales image0 image1 [image2 ... imageN]\n' ...
  '- Wsat: maximal percentage of white-saturated pixels (recommended: 1)\n' ...
  '- Bsat: maximal percentage of black-saturated pixels (recommended: 1)\n' ...
  '- nScales: number of scales (recommended: 0). Use\n' ...
  '    - n for n scales,\n' ...
  '    - 0 for standard depth (as in Mertens et al.),\n' ...
  '    - -1 for autoMin (smallest dimension has size 1 in the residual), and\n' ...
  '    - -2 for autoMax (largest dimension has size 1 in the residual).\n' ...
  '- image0: first and mandatory image of the sequence\n' ...
  '- image1: second mandatory image of the sequence\n' ...
  '- image2..imageN: (optional) following images of the sequence.\n' ...
  '\n' ...
  'This script can be run with Matlab too. Please refer to the README file.\n']);

if isempty(arg_list), fprintf(usage); quit; end
if length(arg_list) < 5, error('Missing argument(s).\nUsage:\n%s\n', usage);
else
  Wsat = str2double(arg_list{1});       % percentage of white saturation
  Bsat = str2double(arg_list{2});       % percentage of black saturation
  nScales = str2double(arg_list{3});    % pyramid depth
end
omegas = [1 1 1];                       % Exposure Fusion parameters, resp.:
                                        % \omega_c, \omega_s, \omega_e

%%% load braketed exposure sequence
tic
N = length(arg_list) - 3;                       % number of input images
J = imread(arg_list{3+1});                      % load the (mandatory) 1st image
imwrite(J,'input_0.png');                       % save image for IPOL
[H,W,D] = size(J);                              % get size of images
I = cat(4,im2double(J),zeros(H,W,D,N-1));       % allocate memory of 4D array I
for n = 2:N                                     % load the N-1 remaining images
  J = imread(arg_list{3+n});                            % load image
  imwrite(uint8(J),sprintf('input_%d.png',n-1));        % save for IPOL
  I(:,:,:,n) = im2double(J);                            % update I
end
if D == 1                                       % gray sequence
  I = repmat(I, [1 1 3 1]);                     % add required channels
  omegas = [1 0 1];                             % do not measure saturation
  warning('Gray sequence! The saturation metric was set to zero.');
elseif (D == 3) && isequal(I(:,:,1,:), I(:,:,2,:), I(:,:,3,:))
  omegas = [1 0 1];                             % do not measure saturation
  warning('Gray sequence! The saturation metric was set to zero.');
elseif (D ~= 1) && (D ~= 3)
  error('Cannot fuse images with %d channels', D);
end
fprintf('EF  === Read the input images (%.3f seconds)\n',toc);

%%% Compute pyramid depth
if nScales ==  0, autoRef = true; else autoRef = false; end
if nScales == -1, autoMin = true; else autoMin = false; end
if nScales == -2, autoMax = true; else autoMax = false; end
[h,w,d,n] = size(I);
if autoRef || autoMin || autoMax                % automatic setting of parameter
    nScRef = floor( log(min(h,w)) / log(2) );   % Mertens's et al. value
    nScales = 1;                                % Initializations
    hp = h;
    wp = w;
    while autoRef && (nScales < nScRef) || ...  % stops at nScRef
          autoMin && (hp > 1 && wp > 1) || ...  % stops at min(hp,wp)==1
          autoMax && (hp > 1 || wp > 1)         % stops at max(hp,wp)==1
        nScales = nScales + 1;
        hp = ceil(hp/2);
        wp = ceil(wp/2);
    end
    fprintf('Number of scales: %d; residual''s size: %dx%d\n', ...
        nScales, hp, wp);
end

tic
[R, W] = exposure_fusion(I, omegas, nScales);
fprintf('EF  === Apply exposure fusion (%.3f seconds)\n',toc);

tic
if omegas(2) == 0, R = R(:,:,1); end            % The 3 channels are identical
R = robustNormalization(R, Wsat, Bsat, 1);
fprintf('EF  === Normalize fused image (%.3f seconds)\n',toc);

tic
imwrite(uint8(255*R),'output_ef.png');
fprintf('EF  === Save the fused image (%.3f seconds)\n',toc);

tic
for n = 1:N
  imwrite(uint8(255*W(:,:,n)),sprintf('input_%d_ef_weights.png',n-1));
end
fprintf('EF  === Save the weights images (%.3f seconds)\n',toc);

