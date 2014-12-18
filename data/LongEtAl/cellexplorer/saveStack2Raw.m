function saveStack2Raw(inimg, filename)
%function saveStack2Raw(inimg, filename)
%
% save a 2-4D image stack as raw image
%
% by Hanchuan Peng

sz = size(inimg);
switch length(sz),
case 2,
  sz = [sz 1 1];
case 3,
  sz = [sz 1];
case 4,
  sz = sz;
otherwise,
  error('The program only support 4D stack or stacks with 2-4 dimensions, with type uint8, uint16, or double (4 bytes float).');
end;

f = fopen(filename, 'wb');

if f<0,
  error('Fail to open file for writing.');
end;

cname = class(inimg);
switch (cname),
    case {'uint8', 'int8', 'uint16', 'int16', 'double', 'float'},
        
    otherwise,
        error('The data type of your input stack is not supported in this version.');
end;    

%% write head information
myWriteHeader(f, sz, cname);

%% write whole file
switch (cname),
    case {'uint8', 'int8'},
        fwrite(f, inimg, cname); 
        
    case {'uint16', 'int16'},
        fwrite(f, inimg, cname);
        

    case {'double', 'float'},
        fwrite(f, inimg, 'float32'); 
        
    otherwise,
        error('The data type of your input stack is not supported in this version.');
end;

fclose(f);

disp(['The stack has been saved to raw image file ' filename]);

return;


%% ========================
function myWriteHeader(fid, sz, datatype)
switch (datatype),
    case {'uint8', 'int8'},
        dcode = 1; %% indicate using 1 byte
        
    case {'uint16', 'int16'},
        dcode = 2; %% indicate using 2 bytes

    case {'double', 'float'},
        dcode = 4; %% indicate using 4 bytes
 
    otherwise,
        error('The data type of your input stack is not supported in this version.');
end;

endian_code = checkMachineEndian;

fwrite(fid, 'raw_image_stack_by_hpeng', 'integer*1');
fwrite(fid, endian_code, 'integer*1');  
fwrite(fid, dcode, 'integer*2');
fwrite(fid, sz, 'integer*4'); 
return;

%% ===========================
