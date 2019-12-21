function [g, dg, M] = remapFun(beta, lambda, M)
% remapFunc creates functions to remap the intensity of the input images of the
% input bracketed exposure sequence, so as to generate a "better" sequence to
% fuse with exposure fusion. (better in the sense that the fused images will
% have drastically less out-of-range artifacts)
%
% [g, M] = remapFun(beta, lambda, M)
%
% Charles Hessel, CMLA, ENS Paris-Saclay

% check inputs and bounds
if ~exist('M','var') || isempty(M), M = ceil(1/beta); end
if beta <= 0 || beta > 1, error(['Incorrect value for beta. ' ...
                                 'Correct range: 0 < beta <= 1.']);
end
if lambda < 0 || lambda >= 1, error(['Incorrect value for parameter lambda. '...
                                     'Correct range: 0 <= lambda < 1']);
end
if M <= 1, error('Incorrect value for parameter M. Use M > 1.\n'); end

%%% Offset for the dynamic range reduction (with function "g" below)
fprintf('M = %d\n', M);
r = @(k) (1-beta/2) - k*(1-beta)/(M-1);

%%% Reduce dynamic (using offset function "r")
a  = beta/2 + lambda;
b  = beta/2 - lambda;
g  = @(t,k) (abs(t-r(k)) <= beta/2) .* t ...
          + (abs(t-r(k)) >  beta/2) .* (sign(t-r(k)) .* (a - lambda^2 ./ ...
                                       (abs(t-r(k)) - b + (abs(t-r(k))==b))) ...
                                       + r(k));

%%% derivative of g with respect to t
dg  = @(t,k) (abs(t-r(k)) <= beta/2) .* 1 ...
           + (abs(t-r(k)) >  beta/2) .* ...
                        (lambda^2 ./ (abs(t-r(k)) - b + (abs(t-r(k))==b)).^2);


%%% Warning: k \in \{0,...,M-1\}
