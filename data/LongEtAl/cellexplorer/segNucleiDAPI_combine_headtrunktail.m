function segImgFinal = segNucleiDAPI_combine_headtrunktail(sz,posHead, posTail,overlap_winwid, head_segImg2, trunk_segImg2, tail_segImg2)
% function segImgFinal = segNucleiDAPI_combine_headtrunktail(sz,posHead, posTail,overlap_winwid, head_segImg2, trunk_segImg2, tail_segImg2)
% 
% combine head, trunk, and tail segmentation results in DAPI channel,
%
% F. Long

segImgFinal = uint16(zeros(sz));
segImgFinal(:) = 0;

%----------------
% add head part
%----------------

stat = regionprops(head_segImg2, 'PixelIdxList');
idx = unique(head_segImg2(:, end, :));
tmp = head_segImg2;

if (length(idx)>1)
    for i=2:length(idx)
        tmp(stat(idx(i)).PixelIdxList) = 0;
    end;
end;

segImgFinal(:,1:posHead,:) = tmp;

%----------------
% add trunk part
%----------------

stat = regionprops(trunk_segImg2, 'PixelIdxList');
idx1 = unique(trunk_segImg2(:, overlap_winwid+1:end, :));
idx2 = unique(trunk_segImg2(:, end, :));
idx = setdiff(unique(trunk_segImg2),setdiff(idx1, idx2));
tmp = trunk_segImg2;

if (length(idx>1))
    for i=2:length(idx)
        tmp(stat(idx(i)).PixelIdxList) = 0;
    end;
end;

nn1 = segImgFinal(:,posHead-overlap_winwid:posTail,:);
nn2 = (nn1>0).* (tmp>0);
jjj = find(nn2>0);
jjj = unique(nn1(jjj));

for i=1:length(jjj)
    kkk = find(nn1==jjj(i));    
    vol1 = nnz(kkk);
    vol2 = nnz(tmp(kkk)>0);
    if (vol2/vol1>0.9)
        segImgFinal(segImgFinal==jjj(i))=0;
    else
        tmp(kkk) = 0;
    end;
end;

segImgFinal(:,posHead-overlap_winwid:posTail,:) = segImgFinal(:,posHead-overlap_winwid:posTail,:) + (tmp+max(segImgFinal(:))).*uint16(tmp>0);

%----------------
% add tail part
%----------------

stat = regionprops(tail_segImg2, 'PixelIdxList');
idx1 = unique(tail_segImg2(:, overlap_winwid+1:end, :));
idx = setdiff(unique(tail_segImg2),idx1);

tmp = tail_segImg2;
if (length(idx)>0)
    for i=1:length(idx)
        tmp(stat(idx(i)).PixelIdxList) = 0;
    end;
end;


nn1 = segImgFinal(:,posTail-overlap_winwid:end,:);
nn2 = (nn1>0).* (tmp>0);
jjj = find(nn2>0);
jjj = unique(nn1(jjj));

for i=1:length(jjj)
    kkk = find(nn1==jjj(i));    
    vol1 = nnz(kkk);
    vol2 = nnz(tmp(kkk)>0);
    if (vol2/vol1>0.9)
        segImgFinal(segImgFinal==jjj(i))=0;
    else
        tmp(kkk) = 0;
    end;
end;


segImgFinal(:,posTail-overlap_winwid:end,:) = segImgFinal(:,posTail-overlap_winwid:end,:) + (tmp+max(segImgFinal(:))).*uint16(tmp>0);

