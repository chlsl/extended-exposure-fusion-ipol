#! /usr/bin/octave -qfW
%%% function composeHomographies ( f_B2A, f_C2B, f_C2A )

%%% If Octave, get arg_list with argv.
if exist('OCTAVE_VERSION', 'builtin')
  arg_list = argv();
  f_B2A = arg_list{1};
  f_C2B = arg_list{2};
  f_C2A = arg_list{3};
else
  %%% With Matlab, replace the first line by
  %%% function composeHomographies ( f_B2A, f_C2B, f_C2A )
end

%%% get values of 3x3 matrix shaped as h_11 h_12 h_13 h_21 h_22 etc.
file_A2B = fopen(f_B2A, 'r');
B2A = fscanf(file_A2B, '%f');
B2A = reshape(B2A, [3 3])';

%%% get values of 3x3 matrix shaped as h_11 h_12 h_13 h_21 h_22 etc.
file_B2C = fopen(f_C2B, 'r');
C2B = fscanf(file_B2C, '%f');
C2B = reshape(C2B, [3 3])';

%%% compose homographies
C2A = B2A * C2B;

%%% save new matrix with same precision
C2A = C2A'; % because it must be saved line by line, not column by column
file_comp = fopen(f_C2A, 'w');
fprintf(file_comp, ...
    '%.13e %.13e %.13e %.13e %.13e %.13e %.13e %.13e %.13e\n', C2A(:)');
