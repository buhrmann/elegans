
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


def addNodeDegrees():
    sIn  = "MATCH (n)<-[r]-(m) With n as n, count(r) as inD SET n.inD = inD"
    sOut = "MATCH (n)-[r]->(m) With n as n, count(r) as outD SET n.outD = outD"
    graph = graphR()    
    graph.query(sIn)
    graph.query(sOut)
    

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
def synapsesD3(neurons, minWeight=0):
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