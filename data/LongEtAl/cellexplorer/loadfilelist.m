function filelist = loadfilelist(filename)
% function filelist = loadfilelist(filename)
% read a plain text file for all image names. One line is an image name.
%
% By Hanchuan Peng
% Jan,2001

filelist = [];
fid = fopen(filename);
if fid==-1,
    disp(['Error to open the file : ' filename]);
    return;
else
    i=1;
    while 1
        tline = fgetl(fid);
        if ~ischar(tline), break; end;
        filelist{i} = deblank(tline);
        i = i+1;
    end;
end;
fclose(fid);
