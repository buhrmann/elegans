function [c, xm, ym, zm] = cov_grayimg3d(inimg, pixInd)
%function [c, xm, ym, zm] = cov_grayimg3d(inimg, pixInd)
% 
% Compute the 3D grayscale image's cov matrix (using Hanchuan Peng's
% definition)
%
% c -- the cov matrix
% xm -- x center (weighted)
% ym -- y center (weighted)
% zm -- z center (weighted)
%
% by Hanchuan Peng
% 2006-05-18
%

sz = size(inimg);
if length(sz)~=3,
   error('Inimg must be a 3D image'); 
end;

if nargin<2,
  pixInd = [];
end;

if isempty(pixInd),
  pixInd = [1:prod(sz)]';
end;

[xx, yy, zz] = ind2sub(sz, pixInd);

a = double(inimg(pixInd));

s = sum(a);

xm = (xx'* a)./s;
ym = (yy'* a)./s;
zm = (zz'* a)./s;

t = [(xx-xm) (yy-ym) (zz-zm)];
c = ([a a a] .* t)' * t ./ s;

% c = ([a a a] .* t)' * ([a a a] .* t) ./ (s.*s);
