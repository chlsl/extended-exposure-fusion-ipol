function [v, int, fun] = eef(u, beta, nScales, improve, M, lambda)
% eef applied the Extended Exposure Fusion to a bracketed exposure sequence.
%
% Usage:
%   v = eef(u);
% or
%   [v, int, fun] = eef(u, beta nSCales, M, med, lambda)
%
% Only the first parameter is mandatory.
% Replace the optional values by []: the order matters.
% Example: v = eef(u, 0.3, [], [], 0.01) set beta and lambda. The other empty
% values are set to the default.
%
% Inputs:
%   - u      : 4D matrix containing the sequence of color images (concatenated
%              in the fourth dimension), in double precision, in [0, 1]
%   - beta   : (default: 0.3) reduced dynamic range (0 < beta <= 1)
%   - nScales: (default: 0) number of scales used in the fusion.
%              0,-1, and -2 mean auto. 0 will compute the depth in the same way
%              as Mertens et al. implementation. The residual is often a few
%              pixels wide in both dimensions. (-1) will make the smallest
%              dimension be of size 1 in the residual; with (-2) this will be
%              the largest (and thus the smallest too).
%
% Supplementary inputs (advanced):
%   - improve: (default: 1) use improved weights as described in the IPOL paper.
%              The well-exposedness weights are reduced outside the restrained
%              range to ensure that these regions aren't used in the fusion.
%              Set to 0 to deactivate.
%   - M      : (default: 0, i.e. auto) use this to force a specific number of
%              images in the sequence.
%   - lambda : (default: 0.125) a constant used to control the remapping
%              functions' shape (controls the speed of the decay outside the
%              restrained range). Not recommended to change it.
%
% Outputs:
%   - v  : fused output
%   - int: struct:
%          - int.uh: generated input sequence (\hat{u})
%          - int.wh: associated weights (\hat{w})
%   - fun: struct containing all used functions and N* and N:
%          - fun.g:  remapping function (for restrained range, Equation 2.)
%          - fun.M:  number of images in the extended sequence
%
% Charles Hessel, CMLA, ENS Paris-Saclay.
% December 2019


%%% options handling

% number of inputs and outputs
narginchk(1,5)
nargoutchk(1,3)

% defaults parameters
if ~exist('beta','var')    || isempty(beta),    beta = .3;        end
if ~exist('nScales','var') || isempty(nScales), nScales = 0;      end
if ~exist('improve','var') || isempty(improve), improve = 1;      end
if ~exist('M','var')       || isempty(M),       M = ceil(1/beta); end
if ~exist('lambda','var')  || isempty(lambda),  lambda = .125;    end

% check bounds
if beta <= 0 || beta > 1, error('sef requires 0 < beta <= 1'); end
if M <= 0,                error('sef requires M > 0');         end

% check if input images are gray (1 channels or 3 identical ones)
[H,W,D,L] = size(u); % L is the number of images in the original sequence.
color = true; % flag for the saturation metric
if (D == 1) || (D == 3) && isequal(u(:,:,1,:), u(:,:,2,:), u(:,:,3,:))
  color = false; % do not measure saturation
  fprintf('WARNING! Gray sequence! The saturation metric was set to zero.\n');
elseif (D ~= 1) && (D ~= 3)
  error('Cannot fuse images with %d channels', D);
end


%%% Compute remapping functions

[g, dg] = remapFun(beta, lambda, M);


%%% Simulate a sequence from image u

seq = zeros(H,W,D,L*M);
if improve, wr = zeros(H,W,L*M); end
for n = 1:L
    for k = 0:M-1
        m = k+1 + (n-1)*M; % index in seq
        seq(:,:,:,m) = max(0,min(1, g(u(:,:,:,n), k)));
        if improve, wr(:,:,m) = prod(dg(u(:,:,:,n), k), 3); end
    end
end


%%% Compute the weights, then normalize them

wc = contrast( seq );
if color, ws = saturation( seq ); else ws = ones(H,W,1,L*M); end
we = well_exposedness( seq );

if improve, w = wc .* ws .* we .* wr + eps;
else        w = wc .* ws .* we + eps; end
w = w ./ sum(w,3);


%%% multiscale blending

v = multiscaleBlendingColor(seq, w, nScales);


%%% Other outputs

int.uh = seq;   % \hat{u} in the paper
int.wh = w;     % \hat{w} in the paper
fun.g = g;      % g in the paper
fun.M = M;      % M in the paper


%%% Mertens' contrast measure +++ handling of gray images

function C = contrast(I)
h = [0 1 0; 1 -4 1; 0 1 0]; % laplacian filter
N = size(I,4);
C = zeros(size(I,1),size(I,2),N);
for i = 1:N
    if size(I,3)==3
        mono = rgb2gray(I(:,:,:,i));
    else
        mono = I(:,:,1,i);
        warning('Contrast measure on gray image');
    end
    C(:,:,i) = abs(imfilter(mono,h,'replicate'));
end


%%% Mertens' saturation measure +++ handling of gray images

function C = saturation(I)
N = size(I,4);
C = ones(size(I,1),size(I,2),N);
if size(I,3)==1
    warning('Skipping saturation measure of gray image.');
    return
end
for i = 1:N
    % saturation is computed as the standard deviation of the color channels
    R = I(:,:,1,i);
    G = I(:,:,2,i);
    B = I(:,:,3,i);
    mu = (R + G + B)/3;
    C(:,:,i) = sqrt(((R - mu).^2 + (G - mu).^2 + (B - mu).^2)/3);
end


%%% Mertens' well-exposedness measure +++ handling of gray images

function C = well_exposedness(I)
sig = .2;
N = size(I,4);
C = zeros(size(I,1),size(I,2),N);
for i = 1:N
    if size(I,3)==3
        R = exp(-.5*(I(:,:,1,i) - .5).^2/sig.^2);
        G = exp(-.5*(I(:,:,2,i) - .5).^2/sig.^2);
        B = exp(-.5*(I(:,:,3,i) - .5).^2/sig.^2);
        C(:,:,i) = R.*G.*B;
    else
        C(:,:,i) = exp(-.5*(I(:,:,1,i) - .5).^2/sig.^2);
        warning('Well Exposedness on gray image.');
    end
end
