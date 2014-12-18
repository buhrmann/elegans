
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
        
g = graph()


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


# Get whole graph as json
def neurons():
    q = "MATCH (n:Neuron) return n"
    graph = graphR()
    res = graph.query(q)
    return [r[0]['data'] for r in res]


# Get whole graph as json
def synapses():
    q = "MATCH (n1:Neuron)-[s:Synapse]->(n2:Neuron) return {from:n1.name, to:n2.name, type:s.type, weight:s.weight}"
    graph = graphR()
    res = graph.query(q)
    return [r[0] for r in res] 
    

def synapsesId(neurons, minWeight=1):
    q = "MATCH (n1:Neuron)-[s:Synapse]->(n2:Neuron) return {from:n1.name, to:n2.name, type:s.type, weight:s.weight}"
    graph = graphR()
    res = graph.query(q)
    synapses = []
    for r in res:
        if r[0]['weight'] >= minWeight:
            s = r[0]
            s['source'] = [i for i,n in enumerate(neurons) if n['name'] == s['from']] [0]
            s['target'] = [i for i,n in enumerate(neurons) if n['name'] == s['to']] [0]
            synapses.append(s)
    return synapses