function gnew = freegraph2undirect(g)
% I think this function might lead to bug. Better not use this!!
% Oct/18/2002
%
%turn a free graph DAG or partial undirected to a fully undirected graph
% when there are symmetric edges, then choose the larger one in the final graph
% By Hanchuan Peng
%
%
% June, 2002

gd = diag(g);
g0 = g - diag(gd);
g1 = max(triu(g0),tril(g0)');

gnew = g1 + g1' + diag(gd);

