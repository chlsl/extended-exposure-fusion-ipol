function runeef(varargin)
% Read, write images and run eef.m (Extended Exposure Fusion) with Octave or
% Matlab.
%
% function runeef(inputName, outputName, alpha, beta, bClip, wClip)
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
addpath(scriptPath, [scriptPath '/exposureFusion'])

%%% Read/Check parameters
usage = sprintf([...
  'Usage: octave -W -qf runeef.m Beta Wsat Bsat nScales improve image0 image1 [image2 ... imageN]\n' ...
  '- Beta: restrained dynamic range in (0,1] (recommended: 0.3)\n' ...
  '- Wsat: maximal percentage of white-saturated pixels (recommended: 1)\n' ...
  '- Bsat: maximal percentage of black-saturated pixels (recommended: 1)\n' ...
  '- nScales: number of scales (recommended: 0). Use\n' ...
  '    - n for n scales,\n' ...
  '    - 0 for standard depth (as in Mertens et al.),\n' ...
  '    - -1 for autoMin (smallest dimension has size 1 in the residual), and\n' ...
  '    - -2 for autoMax (largest dimension has size 1 in the residual).\n' ...
  '- improve: 1 to use the improved weights, as described in the IPOL paper.\n' ...
  '           0 to use the "normal" weights, as described in the WACV paper. (recommended: 1)\n' ...
  '- image0: first mandatory image of the sequence\n' ...
  '- image1: second mandatory image of the sequence\n' ...
  '- image2..imageN: (optional) following images of the sequence.\n' ...
  '\n' ...
  'This script can be run with Matlab too. Please refer to the README file.\n']);

if isempty(arg_list), fprintf(usage); quit; end
if length(arg_list) < 7
  recap = sprintf('Note: received %d arguments:\n',length(arg_list));
  for k = 1:length(arg_list), recap = [recap sprintf('%d) %s\n',k,arg_list{k})];
  end
  error('Missing argument(s).\n%s\n%s', usage, recap);
else
  beta    = str2double(arg_list{1});        % restrained dynamic range
  Wsat    = str2double(arg_list{2});        % percentage of white saturation
  Bsat    = str2double(arg_list{3});        % percentage of black saturation
  nScales = str2double(arg_list{4});        % Pyramid depth
  improve = str2double(arg_list{5});        % Better weights (IPOL paper)
end

%%% load braketed exposure sequence
tic
N = length(arg_list) - 5;                   % number of input images
J = imread(arg_list{5+1});                  % load the (mandatory) 1st image
% imwrite(J,'input_0.png');                 % save image for IPOL
[H,W,D] = size(J);                          % get size of images
I = cat(4,im2double(J),zeros(H,W,D,N-1));   % allocate memory of 4D array I
for n = 2:N                                 % load the N-1 remaining images
  J = imread(arg_list{5+n});                     % load image
% imwrite(uint8(J),sprintf('input_%d.png',n-1)); % save for IPOL
  I(:,:,:,n) = im2double(J);                     % update I
end
fprintf('EEF === Read the input images (%.3f seconds)\n',toc);

%%% Apply Extended Exposure Fusion
tic
[R, int, fun] = eef(I, beta, nScales, improve);
fprintf('EEF === Applied extended exposure fusion (%.3f seconds)\n',toc);

tic
R = robustNormalization(R, Wsat, Bsat, 1);
fprintf('EEF === Normalized fused image (%.3f seconds)\n',toc);

tic
imwrite(uint8(255*R),'output_eef.png');
fprintf('EEF === Saved the fused image (%.3f seconds)\n',toc);

tic
for n = 1:fun.M*N
  imwrite(uint8(255*int.uh(:,:,:,n)),sprintf('input_%d_eef_simulated.png',n-1));
  imwrite(uint8(255*int.wh(:,:,n)),sprintf('input_%d_eef_weights.png',n-1));
end
fprintf('EEF === Saved the weights images (%.3f seconds)\n',toc);

%%% Prepaper remapping functions
x = (0:511)/511;
remap = NaN(512,fun.M);
legCont = cell(1,fun.M);
for k = 0:fun.M-1
    n = k + 1;
    remap(:,n) = fun.g(x, k);               % Apply remapping function
    legCont{n} = sprintf('k=%d',k);         % Legend of figure
end

%%% Print remaping functions
colororder = repmat([...                    % Octave
    0         0.4470    0.7410
    0.8500    0.3250    0.0980
    0.9290    0.6940    0.1250
    0.4940    0.1840    0.5560
    0.4660    0.6740    0.1880
    0.3010    0.7450    0.9330
    0.6350    0.0780    0.1840],[3 1]);
fh = figure('visible','off');
for n=1:fun.M, plot(x,remap(:,n),'Color',colororder(n,:),'LineWidth',2); hold on;
end; hold off; axis([0 1 0 1]); axis square
lh = legend(legCont,'Location','SouthEast'); set(lh,'FontSize',10);
set(gca,'position',[0 0 1 1],'units','normalized')
set(gcf,'PaperUnits','Inches','PaperPosition',[0 0 5.12 5.12])
print('-dpng','remapFun.png','-r100');

%%% Give ipol the number of generated images
fileID = fopen('algo_info.txt','a');
fprintf(fileID,'nb_outputs_eef=%d',fun.M*N);
fclose(fileID);
