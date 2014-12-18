function saveStack2Raw(inimg, filename)
%function saveStack2Raw(inimg, filename)
%
% save a 2-4D image stack as raw image
%
% by Hanchuan Peng
% Feb 15, 2006
% Feb 26, 2006: distinguish the cases of 'integer*1' and 'uint8', 'int8',
%               etc, which are very different actually
%
% April 14, 2006: add the support for big-endian, little-endian, and
% middle-endian by add a tag 'B', 'E', or 'L' immediately after the file
% format tag 
%
% Updated 06-08-03 and change the file name by adding a "2byte" surfix. 
%

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
        fwrite(f, inimg, cname); %fwrite(f, inimg, 'uint8');
        
        %fwrite(f, inimg, 'integer*1'); %% note that this 'integer*1' is a
        %BUG to confuse the writer about the difference of 'uint8' and
        %'int8'
        
    case {'uint16', 'int16'},
        fwrite(f, inimg, cname);
        
        %fwrite(f, inimg, 'integer*2');

    case {'double', 'float'},
        fwrite(f, inimg, 'float32'); %% note that there will be precision loss in this conversion
        
        %fwrite(f, inimg, 'integer*4'); %% note that there will be precision loss in this conversion
        
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
fwrite(fid, endian_code, 'integer*1');  %% 060414 the endian support
fwrite(fid, dcode, 'integer*2');
fwrite(fid, sz, 'integer*2');
return;

%% ===========================
