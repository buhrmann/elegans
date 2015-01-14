
import os
from py2neo import ServiceRoot, Node, neo4j

from neo4jrestclient import client
from neo4jrestclient.client import GraphDatabase
from urlparse import urlparse, urlunparse

import numpy as np
import json
import preproc

# Get connection to graph
def graph():
    graphenedb_url = os.environ.get("GRAPHENEDB_URL", "http://localhost:7474/")
    return ServiceRoot(graphenedb_url).graph


def graphR():
    url = os.environ.get("GRAPHENEDB_URL", None)
    if url == None: 
        return GraphDatabase("http://localhost:7474/db/data/")
    else:
        url = urlparse(url)
        url_without_auth = urlunparse((url.scheme, "{0}:{1}".format(url.hostname, url.port), url.path, None, None, None))
        return GraphDatabase(url_without_auth, username = url.username, password = url.password)
        
g = graphR()


# Imports neurons from source files
# TODO: store preprocessed data locally as csv, then import without need to recreate each time
# nor for using pandas etc.
def addNeurons(clear):
    if clear: 
        g.delete_all()

    neurons = preproc.neuronsDf()

    tx = g.cypher.begin()
    statement = "CREATE (n:Neuron {props})"    
    for name, params in neurons.iterrows():        
        params = params.to_dict()
        params['name'] = name        
        tx.append(statement, {"props":params})
    tx.commit()

    return g


# Add synapses
# TODO: store preprocessed data locally as csv, then import without need to recreate each time
# nor for using pandas etc.
def addSynapses(clear):
    if clear:
        g.delete_all()

    conns = preproc.connsDf()

    tx = g.cypher.begin()
    statement = "MATCH (n1:Neuron {name:{nm1}}), (n2:Neuron {name:{nm2}}) CREATE (n1)-[s:Synapse {name:n1.name+'->'+n2.name, type:{tp}, weight:{w}}]->(n2)" 
    for ix, r in conns.iterrows():        
        tx.append(statement, {"nm1":r['Neuron 1'], "nm2":r['Neuron 2'], "tp":r["Type"], "w":r["Nbr"]})
    tx.commit()

    return g


def addNodeDegrees():
    sIn = "MATCH (n) OPTIONAL MATCH (n)<-[r]-(m) WITH n as n, COUNT(r) as inD SET n.inD=inD"
    sOut = "MATCH (n) OPTIONAL MATCH (n)-[r]->(m) WITH n as n, COUNT(r) as outD SET n.outD=outD"
    total = "MATCH (n) SET n.D = (n.inD + n.outD)"
    graph = graphR()    
    graph.query(sIn)
    graph.query(sOut)
    graph.query(total)
    

# Get all neurons as list
def neurons():
    q = "MATCH (n:Neuron) return n"
    graph = graphR()
    res = graph.query(q)
    #return [r[0]['data'] for r in res]
    neurons = []
    for n in res:
        neuron = n[0]['data']
        neuron['id'] = n[0]['metadata']['id']
        neurons.append(neuron)
    return neurons

# Get all neurons as list
def neuronsSigma():
    q = "MATCH (n:Neuron) return n"
    graph = graphR()
    res = graph.query(q)
    neurons = []
    for n in res:
        neuron = n[0]['data']
        neuron['id'] = neuron['name']
        neuron['label'] = neuron['name']
        neurons.append(neuron)
    #return [r[0]['data'].update({'id':r[0]['data']['name']}) for r in res]
    return neurons


# Get all synapses as list
def synapses():
    q = "MATCH (n1:Neuron)-[s:Synapse]->(n2:Neuron) return {from:n1.name, to:n2.name, type:s.type, weight:s.weight}"
    graph = graphR()
    res = graph.query(q)
    return [r[0] for r in res] 


# d3 compatible format
def synapsesSigma(neurons, minWeight=0):
    q = "MATCH (n1:Neuron)-[s:Synapse]->(n2:Neuron) return {source:n1.name, target:n2.name, kind:s.type, size:s.weight, id:str(id(s))}"
    graph = graphR()
    res = graph.query(q)
    synapses = []
    for r in res:
        s = r[0]
        if s['size'] >= minWeight:
            s['type'] = 'curvedArrow'
            s['color'] = '#bbb'
            s['hover_color'] = '#000'
            synapses.append(s)
    return synapses


# d3 compatible format
def synapsesD3(neurons, minWeight=1):
    q = "MATCH (n1:Neuron)-[s:Synapse]->(n2:Neuron) return {from:id(n1), to:id(n2), type:s.type, weight:s.weight, id:id(s)}"
    graph = graphR()
    res = graph.query(q)
    synapses = []
    for r in res:
        if r[0]['weight'] >= minWeight:
            s = r[0]
            s['source'] = [i for i,n in enumerate(neurons) if n['id'] == s['from']] [0]
            s['target'] = [i for i,n in enumerate(neurons) if n['id'] == s['to']] [0]
            synapses.append(s)
    return synapses


# Returns subgraph connecting neurons in group1 with neurons in group2
def subgraph(g1, g2, l=2, w=2, dir='->'):

    q = ("MATCH (n1:Neuron) WHERE n1.group={g1} "
         "MATCH (n2:Neuron) WHERE n2.group={g2} ")
    q += "MATCH p=(n1)-[r*1.." + str(l) + "]" + dir + "(n2) "
    q += "WHERE ALL(c IN r WHERE c.weight >= {w}) "
    q += ("AND ALL(n in NODES(p) WHERE 1=length(filter(m in NODES(p) WHERE m=n))) "
          "WITH DISTINCT r AS dr, NODES(p) AS ns "
          "UNWIND dr AS udr UNWIND ns AS uns "
          "RETURN COLLECT(DISTINCT udr), COLLECT(DISTINCT uns)")

    parameters = {"g1":g1, "g2":g2, "w":w, "l":l}
    print "Querying graph with "
    print q, parameters
    res = g.query(q, params=parameters)[0]
    print "...Done querying."
    res_syns = res[0]
    res_nodes = res[1]
    synapses = []
    neurons = []
    
    for n in res_nodes:
        neuron = n['data']
        neuron['id'] = n['metadata']['id']
        neurons.append(neuron)

    for n in neurons:
         print n['id'], n['name']

    for syn in res_syns:
        # print syn, "\n"
        s = syn['data']
        # Connected nodes are referenced by their index in start and end properties (within url)
        s['from'] = int(syn['start'].rsplit("/", 1)[1])
        s['to'] = int(syn['end'].rsplit("/", 1)[1])
        print s['from'], " -> ", s['to']
        s['source'] = [i for i,n in enumerate(neurons) if n['id'] == s['from']][0]
        s['target'] = [i for i,n in enumerate(neurons) if n['id'] == s['to']][0]
        s['id'] = syn['metadata']['id']
        synapses.append(s)
    
    return {"synapses":synapses, "neurons":neurons}


    # MATCH (n), (n2) WHERE n.group="ADA" AND n2.group="AVA" MATCH (n)-[r*1..2]->(n2) RETURN n, n2, COUNT(r)
    # MATCH (n), (n2) WHERE n.group="ADA" AND n2.group="AVA" MATCH p=(n)-[r*1..3]->(n2) WHERE ALL(c in r WHERE c.weight > 1) RETURN p, LENGTH(p)
    # MATCH (n1), (n2) WHERE n1.group="ADA" AND n2.group="AVA" 
    #     MATCH p=(n1)-[r*1..3]->(n2) 
    #         WHERE ALL(c in r WHERE c.weight > 1) 
    #         AND ALL(n in NODES(p) WHERE 1=length(filter(m in NODES(p) WHERE m=n))) 
    #         RETURN p

    # MATCH (n1), (n2) WHERE n1.group="ADA" AND n2.group="AVA" 
    #     MATCH p=(n1)-[r*1..3]->(n2) 
    #         WHERE ALL(c in r WHERE c.weight > 1) 
    #         AND ALL(n in NODES(p) WHERE 1=length(filter(m in NODES(p) WHERE m=n))) 
    #             WITH COLLECT(DISTINCT NODES(p)) AS cnodes 
    #             UNWIND cnodes as unodes UNWIND(unodes) as uunodes 
    #             RETURN COLLECT(DISTINCT uunodes)

    # MATCH (n1), (n2) WHERE n1.group="ADA" AND n2.group="AVA" 
    #     MATCH p=(n1)-[r*1..3]->(n2) 
    #         WHERE ALL(c in r WHERE c.weight > 1) 
    #         AND ALL(n in NODES(p) WHERE 1=length(filter(m in NODES(p) WHERE m=n))) 
    #         WITH COLLECT(NODES(p)) AS cnodes 
    #         WITH REDUCE(output=[], r in cnodes | output+r) AS flatnodes 
    #         UNWIND flatnodes as fnodes 
    #         WITH DISTINCT fnodes RETURN COLLECT(fnodes)

    # MATCH (n1), (n2) WHERE n1.group="ADA" AND n2.group="AVA" 
    #     MATCH p=(n1)-[r*1..3]->(n2) 
    #         WHERE ALL(c in r WHERE c.weight > 1) 
    #         AND ALL(n in NODES(p) WHERE 1=length(filter(m in NODES(p) WHERE m=n))) 
    #             WITH p as p, COLLECT(NODES(p)) AS cnodes 
    #             UNWIND cnodes as unodes UNWIND(unodes) as uunodes 
    #             RETURN COLLECT(p) as paths, COLLECT(DISTINCT uunodes) as nodeset

    # MATCH (n1), (n2) WHERE n1.group="ADA" AND n2.group="AVA" 
    # MATCH p=(n1)-[r*1..3]->(n2) 
    #     WHERE ALL(c in r WHERE c.weight > 1) 
    #     AND ALL(n in NODES(p) WHERE 1=length(filter(m in NODES(p) WHERE m=n))) 
    #         WITH COLLECT(DISTINCT r) AS crel, COLLECT(NODES(p)) AS cnodes 
    #             UNWIND cnodes as unodes UNWIND(unodes) as uunodes UNWIND crel as urel UNWIND urel as uurel
    #             RETURN COLLECT(DISTINCT uurel) as paths, COLLECT(DISTINCT uunodes) as nodeset

    # Match (n)-[r*1..2]->(m) WHERE n.group="ADA" AND m.group="AVA" RETURN n, m, COUNT(r)
    # Match (n)-[r*1..2]->(m) WHERE n.group="ADA" AND m.group="AVA" AND ALL(c in r WHERE c.weight > 1) RETURN n,m, COUNT(r)

    # Shortest path...
    # MATCH (n), (n2) WHERE n.group="ADA" AND n2.group="AVA" 
    #     MATCH p=shortestPath((n)-[r*..3]->(n2)) WHERE ALL(c in r WHERE c.weight > 0) RETURN p

    # MATCH (n), (n2) WHERE n.group="ADA" AND n2.group="AVA" 
    #     MATCH p=allShortestPaths((n)-[r*]->(n2)) WHERE ALL(c in r WHERE c.weight > 0) RETURN p
