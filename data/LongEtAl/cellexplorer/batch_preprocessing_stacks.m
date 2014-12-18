function batch_preprocessing_stacks(psfSize, idx, datadir, channelNo, channel_id, deconvolutionTag)
% function batch_preprocessing_stacks(psfSize, idx, datadir, channelNo, channel_id, deconvolutionTag)
% 
% batch file for preprocessing of worm stacks for segmentation 
% Copyright F. Long
% 20060530
% 20061216

if channelNo < 3
    id_gfp = channel_id(1);
    id_dapi = channel_id(2);
else
    id_rfp = channel_id(1);
    id_gfp = channel_id(2);
    id_dapi = channel_id(3);
end;

for k=1:length(idx)

    i = idx(k);
    imgname = [datadir{i}, '_crop_straight.ics']; 
    if (deconvolutionTag == 0) % do not do deconvolution

        outimgnamedevDAPI =''; 
        outimgnamedevGFP =''; 
        outimgnamedevRFP ='';         
        
        outimgnamepreDAPI = [datadir{i}, '_crop_straight_pre_DAPI.ics'];        
        outimgnamepreGFP = [datadir{i}, '_crop_straight_pre_GFP.ics'];                
        outimgnamepreRFP = [datadir{i}, '_crop_straight_pre_RFP.ics'];                        

        
    else % do deconvolution

        outimgnamedevDAPI = [datadir{i}, '_crop_straight_d_DAPI']; 
        outimgnamedevGFP = [datadir{i}, '_crop_straight_d_GFP']; 
        outimgnamedevGFP = [datadir{i}, '_crop_straight_d_RFP']; 
        
        outimgnamepreDAPI = [datadir{i}, '_crop_straight_d_pre_DAPI.ics'];        
        outimgnamepreGFP = [datadir{i}, '_crop_straight_d_pre_GFP.ics'];   
        outimgnamepreRFP = [datadir{i}, '_crop_straight_pre_RFP.ics'];                      
        
    end;
    
    fprintf('Preprocessing DAPI channel ... \n');
    segNucleiPre(imgname, outimgnamedevDAPI, outimgnamepreDAPI, id_dapi,  psfSize);
    
    fprintf('Preprocessing GFP channel ... \n');
    segNucleiPre(imgname, outimgnamedevGFP, outimgnamepreGFP, id_gfp,  psfSize);
    
    if (channelNo == 3)
        fprintf('Preprocessing RFP channel ... \n');        
        segNucleiPre(imgname, outimgnamedevRFP, outimgnamepreRFP, id_rfp,  psfSize);    
    end;
    
end;