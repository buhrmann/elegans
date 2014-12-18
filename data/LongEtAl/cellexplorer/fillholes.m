function outimg = fillholes(inimg)
% function outimg = fillholes(inimg)
%
% fill holes of a 3D image slice by slice along
% z directions. 
%
% Copyright Fuhui Long


outimg = inimg;

sz=size(inimg);

if length(sz)==2
    outimg = imfill(inimg,'holes');
else
    for i=1:sz(3)
        outimg(:,:,i) = imfill(squeeze(inimg(:,:,i)), 'holes');
    end;
end;
