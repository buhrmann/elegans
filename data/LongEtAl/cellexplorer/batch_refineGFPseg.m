function batch_refineGFPseg(wanodir, filename, idx, GFPdatadir, GFPCorrectdatadir, id_gfp, id_dapi) 
% function batch_refineGFPseg(wanodir, filename, idx, GFPdatadir, GFPCorrectdatadir, id_gfp, id_dapi) 
% batch file for refining GFP segmenation mask
% F. Long
% 20080818

for k=1:length(idx)
    
     i = idx(k);
   
    inimg = uint8(loadRaw2Stack([wanodir, 'GFP/', filename{i}, num2str(i), '_crop_straight.raw']));
    inimg = permute(inimg,[2 1 3 4]);
    inimgGFP = inimg(:,:,:,id_gfp);
    inimgDAPI = inimg(:,:,:,id_dapi);
    clear inimg;
    
    % load segmentation results
    
    load([GFPdatadir, num2str(i), '_segNucleiOrdered.mat']); % might need to permute
    autoSegImg = uint16(segres);
    manualSegImg = uint16(loadRaw2Stack([wanodir, 'GFP/', filename{i}, num2str(i), '.ano.mask.raw']));
    
    
    manualSegImg = permute(manualSegImg, [2 1 3]);
    
    segres = refineGFPseg(manualSegImg, autoSegImg, inimgGFP, inimgDAPI);
    
    % save file
    if ~exist(GFPCorrectdatadir(1:end-3),'dir')
       mkdir(GFPCorrectdatadir(1:end-3));
    end;

    fn = [GFPCorrectdatadir, num2str(i), '_segNucleiOrdered.mat'];
    save(fn, 'segres');

end;

    


           
    
        