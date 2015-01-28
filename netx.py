"""
Handle NetworkX interfacing, i.e. conversion from neo4j data to NetworkX
graph and output of graph to various formats.
"""

import json
import networkx as nx
from networkx.readwrite import json_graph as jsg


def to_netx(neurons, synapses):
    """ Create a networkx MultiDiGraph from a list of nodes and edges. """
    net = nx.MultiDiGraph()

    for neuron in neurons:
        ncp = neuron.copy()
        i = ncp.pop('id')
        net.add_node(i, ncp)

    for syn in synapses:
        syncp = syn.copy()
        src = syncp.pop('from')
        target = syncp.pop('to')
        idx = syncp.pop('id')
        net.add_edge(src, target, idx, syncp)

    return net


def to_json(net, gformat):
    if "list" in gformat:
        jsn = jsg.node_link_data(net)
    else:
        jsn = jsg.adjacency_data(net)
    jsn = json.dumps(jsn, indent=2, sort_keys=True)
    return jsn


def to_gml(net):
    return '\n'.join(nx.generate_gml(net))


def to_graphml(net):
    return '\n'.join(nx.generate_graphml(net))


def to_adj(net):
    return '\n'.join(nx.generate_adjlist(net))


def save_graphml(net, fnm):
    nx.write_graphml(net, fnm, prettyprint=True)


def print_graphml(net):
    strg = '\n'.join(nx.generate_graphml(net))
    print strg