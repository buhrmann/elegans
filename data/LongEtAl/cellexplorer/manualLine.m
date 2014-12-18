

function bpos = manualLine(a)
  %function bpos = manualLine(a)
%
%% manually select backbone points
%
% by Hanchuan Peng
% 050722

  if isa(a, 'uint8')==0,
  a = uint8(a);
end;

nd = ndims(a);

if nd==2,
  s = a;
elseif nd==3,
  s = sum(a,3)./size(a,3);
s = s./max(s(:))*255;
elseif nd==4,
  s = sum(a(:,:,:,1),3);
s = s./size(a,3);
s = s./max(s(:))*255;
 else,
   error('only support 2,3,4 dimensional array.');
end;

s = uint8(s);

imshow(s);
[CX,CY,C,xi,yi] = improfile;



% % for i=1:length(CX),
	    % %   bpos(i).x = CX(i);
% %   bpos(i).y = CY(i);
% % end;

for i=1:length(xi),  %%note that I swap x and y
	bpos(i).x = yi(i);
bpos(i).y = xi(i);
end;
