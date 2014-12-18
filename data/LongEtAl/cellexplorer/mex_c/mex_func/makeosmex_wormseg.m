%% by Hanchuan Peng. All rights reserved.
% 2009-Feb-16
% This .m batch file is used to compile all the mex functions needed for
% the worm segmentation pipeline in Matlab codes

echo on

%% compile the IO 

mex loadRaw2Stack_c.cpp mg_image_lib.cpp mg_utilities.cpp -ltiff
mex saveStack2File_c.cpp mg_image_lib.cpp mg_utilities.cpp -ltiff

%% check the Endian of machine

mex checkMachineEndian.cpp

%%  graph algorithms

mex bfs.cpp
mex bfs_1root.cpp
mex dfs.cpp
mex mst_prim.cpp
mex hungarianC.cpp

%% image processing

mex straight_nearestfill.cpp
mex reslice_Z.cpp


%%

echo off






