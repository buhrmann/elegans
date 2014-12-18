function batch_straightening_stacks4(id_rfp, id_gfp, id_dapi, indatadir, outdatadir, prefix, idx, xy_rez, z_rez, zoom_f)
% function batch_straightening_stacks4(id_rfp, id_gfp, id_dapi, indatadir,outdatadir, prefix, idx, xy_rez, z_rez, zoom_f)
% 
% batch file for straighten worm image stacks
%
% F.Long
% 20070111


for k=1:length(idx)
    i = idx(k);
    
    a = readStanfordEleganStack_FL2([indatadir{k}, num2str(i)], prefix{k}, id_dapi, xy_rez, z_rez, zoom_f); 
    
    b = main_straightenWorm2(a,id_gfp,id_dapi); 
    saveStack2Raw(b, [outdatadir{k}, num2str(i), '_crop_straight_xy.raw']); 
    writeim(b, [outdatadir{k}, num2str(i), '_crop_straight_xy.ics'], 'ics');
    
    filename = [outdatadir{k}, num2str(i), '_crop_straight_xy.ics'];
    [b,dis] = rfpShiftCorrection(filename, id_rfp, id_dapi);  
    
    c = permute(uint8(b), [3 2 1 4]);    
    c = c(:,:,end:-1:1,:);
    d = main_straightenWormSemiauto(c, id_gfp, id_dapi);
    
    e = permute(uint8(d), [3 2 1 4]);        
    e = e(end:-1:1,:,:,:);    
    e = e(:,end:-1:1,end:-1:1,:);    

    f = main_flipWorm(e, id_gfp, id_dapi);
    f1 = permute(uint8(f), [2 1 3 4]);    
    
    saveStack2Raw(f1, [outdatadir{k}, num2str(i), '_crop_straight.raw']); 
    writeim(f, [outdatadir{k}, num2str(i), '_crop_straight.ics'], 'ics');

    close all;
end;

