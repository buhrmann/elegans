import networkx as nx
import matplotlib

def showXY(fnm, x="kx", y="ky"):
    g = nx.read_graphml(fnm)
    x = nx.get_node_attributes(g, x)
    y = nx.get_node_attributes(g, y)
    coords = zip(x.values(),y.values())
    pos = dict(zip(g.nodes(), coords))
    nx.draw(g,pos)
    
def showX(fnm):
    g = nx.read_graphml(fnm)
    x = nx.get_node_attributes(g, 'soma_pos')
    y = [0] * len(x)
    coords = zip(x.values(), y)
    pos = dict(zip(g.nodes(), coords))
    nx.draw(g,pos)    