%% by Hanchuan Peng
%% Jan 2007
%% made for Stuart Kim's server at Stanford
 
echo on;

funcroot = 'C:\Documents and Settings\Stuart Kim\My Documents\MATLAB';


if 1,
diproot = [funcroot '\dipimage'];

% addpath([diproot, '\dipimage'], ...
%        [diproot, '\diplib'],...
%        '-begin');


addpath([diproot, '\'], ...
        [diproot, '\diplib'],...
        '-begin');

dip_initialise
dipsetpref('imagefilepath',[diproot '\images']);
end;

addpath(funcroot, '-begin');

echo off;
% clc;