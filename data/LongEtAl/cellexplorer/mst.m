function [gnew,r] = mst(g, rootnode)
%find the minimum spanning tree of undirected map g
%
%example: load fig24.5.mat;gnew = mst(x);dispbnarc(gnew);
%
% By Hanchuan Peng
% June 2002
% Update 041120. Add rootnode

if nargin<2,
  rootnode=1;
end;

g = full(freegraph2undirect(g));
r = mst_prim(g, rootnode);
r = r(:,3);
if length(find(r==-1))~=1,
    fprintf('the algorithm or graph has error ! \n');
    gnew = [];
else
    i = find(r~=-1);
    gnew = zeros(size(g));
    gnew(sub2ind(size(g),r(i),i))=1;
end;
