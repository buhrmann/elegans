function e = checkMachineEndian()
%function e = checkMachineEndian()
% Check the endianness of the machine
%
% The reurn value is 'B', 'L', or 'M' for big-endian, little-endian, or
% middle-endian
%
% by Hanchuan Peng
% Apri, 14, 2006
%

a=uint32(hex2dec('44332211'));
if ((nnz(double(bitget(a,[8:-1:1])) -   [0 0 0 1 0 0 0 1]) == 0) & ...
    (nnz(double(bitget(a,[16:-1:9])) -  [0 0 1 0 0 0 1 0]) == 0) & ...
    (nnz(double(bitget(a,[24:-1:17])) - [0 0 1 1 0 0 1 1]) == 0) & ...
    (nnz(double(bitget(a,[32:-1:25])) - [0 1 0 0 0 1 0 0]) == 0)),

    e = 'B'; %the most significant byte first, then is the 'big endian'
    
elseif  ((nnz(double(bitget(a,[8:-1:1])) -   [0 1 0 0 0 1 0 0]) == 0) & ...
         (nnz(double(bitget(a,[16:-1:9])) -  [0 0 1 1 0 0 1 1]) == 0) & ...
         (nnz(double(bitget(a,[24:-1:17])) - [0 0 1 0 0 0 1 0]) == 0) & ...
         (nnz(double(bitget(a,[32:-1:25])) - [0 0 0 1 0 0 0 1]) == 0)),

    e = 'L'; %the most significant byte last, but offset 0 first, then is the 'little endian'

elseif  ((nnz(double(bitget(a,[8:-1:1])) -   [0 0 1 0 0 0 1 0]) == 0) & ...
         (nnz(double(bitget(a,[16:-1:9])) -  [0 0 1 0 0 0 1 0]) == 0) & ...
         (nnz(double(bitget(a,[24:-1:17])) - [0 1 0 0 0 1 0 0]) == 0) & ...
         (nnz(double(bitget(a,[32:-1:25])) - [0 0 1 1 0 0 1 1]) == 0)),

    e = 'M'; %just swap each of the 16bits,  then is the 'middle endian'

else
    
    e = 'N';
    disp('Cannot determine the Endianness of the machine. The data should be verified before they are distributed across different platforms.');
    
end;

return;
