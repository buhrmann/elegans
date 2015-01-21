import json
import networkx as nx
from networkx.readwrite import json_graph as jsg


def toNx(neurons, synapses):
    g = nx.MultiDiGraph()


    for n in neurons:
        nc = n.copy()
        i = nc.pop('id')
        g.add_node(i, nc)

    for e in synapses:
        ec = e.copy()
        f = ec.pop('from')
        t = ec.pop('to')
        i = ec.pop('id')
        g.add_edge(f, t, i, ec)

    return g


def toJson(g):
    js = jsg.node_link_data(g)
    print json.dumps(js, indent=2, sort_keys=True)
    return js


def saveGrML(g, fnm):
    nx.write_graphml(g, fnm, prettyprint=True)


def printGrML(g):
    s = '\n'.join(nx.generate_graphml(g))
    print s