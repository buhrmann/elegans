function batch_genano(wanodir, datadirprefix, filename, idx, ind,id_ch)
% function batch_genano(wanodir, datadirprefix, filename, idx, ind,id_ch)
% 
% copy files to folders under vano and generate files for vano
% F.Long
% 200807

for i=1:length(filename)

    switch lower(id_ch)
        case 'gfp'
            dprefix = [datadirprefix 'GFP/ss'];
        case 'dapi'
            dprefix = [datadirprefix 'DAPI/ss'];
        case 'rfp'
            dprefix = [datadirprefix 'RFP/ss'];
    end;
    
        
    anofilename(i) = {[dprefix, num2str(i),'/ano.ini']};    
    grayimgfilename(i) = {[datadirprefix, filename{i},num2str(idx(i)), '_crop_straight.raw']};
    maskimgfilename(i) = {[dprefix, num2str(i), '_segNucleiOrdered.mat']};
end;


switch lower(id_ch)
    case 'gfp'
        wdir = [wanodir, 'GFP/'];
    case 'dapi'
        wdir = [wanodir, 'DAPI/'];
    case 'rfp'
        wdir = [wanodir, 'RFP/'];
end;

if (~exist(wdir, 'dir'))
    mkdir(wdir);
end;

for i=1:length(ind)
    
    load(maskimgfilename{ind(i)});
    b = segres;
    
    if (size(b,1)<size(b,2))
        b = permute(segres,[2 1 3 4]);
    end;
    
    maskimg = [wdir, filename{ind(i)}, num2str(idx(ind(i))), '.ano.mask.raw'];
    saveStack2Raw_2byte(b, maskimg);
    
    grayimg = [wdir, filename{ind(i)}, num2str(idx(ind(i))),'_crop_straight.raw'];
    a = loadRaw2Stack(grayimgfilename{ind(i)});
    saveStack2Raw_2byte(a, grayimg);
    
    apofile = [wdir, filename{ind(i)}, num2str(idx(ind(i))), '.apo'];
    copyfile(anofilename{ind(i)}, apofile);    
    
    fid = fopen([wdir, filename{ind(i)}, num2str(idx(ind(i))),'.ano'],'wt');
%     fprintf(fid, 'GRAYIMG=%s\n',[wdir, filename{ind(i)}, num2str(idx(ind(i))),'_crop_straight.raw']);
%     fprintf(fid, 'MASKIMG=%s\n', [wdir,filename{ind(i)}, num2str(idx(ind(i))), '.ano.mask.raw']);
%     fprintf(fid, 'ANOFILE=%s\n', [wdir,filename{ind(i)}, num2str(idx(ind(i))), '.apo']);

    %use relative path
    fprintf(fid, 'GRAYIMG=%s\n', [filename{ind(i)}, num2str(idx(ind(i))),'_crop_straight.raw']);
    fprintf(fid, 'MASKIMG=%s\n', [filename{ind(i)}, num2str(idx(ind(i))), '.ano.mask.raw']);
    fprintf(fid, 'ANOFILE=%s\n', [filename{ind(i)}, num2str(idx(ind(i))), '.apo']);
    
    fclose(fid);
end;
