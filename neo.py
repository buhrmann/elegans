"""
Handle import and export of data into and out of Neo4j database.
"""

import os
from py2neo import ServiceRoot

from neo4jrestclient.client import GraphDatabase
from urlparse import urlparse, urlunparse

import preproc

# ------------------------------------------------------------------------------------------------
# DB connections
# ------------------------------------------------------------------------------------------------
def graph_p2():
    """ Get connection to graph via py2neo. """
    graphenedb_url = os.environ.get("GRAPHENEDB_URL", "http://localhost:7474/")
    return ServiceRoot(graphenedb_url).graph


def graph_rest():
    """ Get connection to graph via neo4jrestclient """
    url = os.environ.get("GRAPHENEDB_URL", None)
    if url == None:
        return GraphDatabase("http://localhost:7474/db/data/")
    else:
        url = urlparse(url)
        url_without_auth = urlunparse((url.scheme, "{0}:{1}".format(url.hostname, url.port), url.path, None, None, None))
        return GraphDatabase(url_without_auth, username=url.username, password=url.password)


GRAPH = graph_rest()

# ------------------------------------------------------------------------------------------------
# DB creation
# ------------------------------------------------------------------------------------------------
def db_add_neurons(clear):
    """ Import neurons into DB from local files. """
    graph = graph_p2()
    if clear:
        graph.delete_all()

    neurons_df = preproc.neurons_df()
    transx = graph.cypher.begin()
    statement = "CREATE (n:Neuron {props})"
    for name, params in neurons_df.iterrows():
        params = params.to_dict()
        params['name'] = name
        transx.append(statement, {"props":params})
    transx.commit()


def db_add_muscles(clear):
    """ Import muscles into DB from local file. """
    graph = graph_p2()
    if clear:
        statement = "MATCH (n:Muscle) DELETE n"
        graph.cypher.run(statement)

    muscles = preproc.muscles_df()
    transx = graph.cypher.begin()
    statement = "CREATE (n:Muscle {props})"
    for name, params in muscles.iterrows():
        params = params.to_dict()
        params['name'] = name
        transx.append(statement, {"props":params})
    transx.commit()    


def db_add_sensory_info():
    """ Add info about sensory modality etc. to sensory neurons. """
    query = "MATCH (n) WHERE n.group={grp} SET n.organ={org}, n.modalities={mod}, n.functions={fct}"
    sdf = preproc.sensors_df()
    for group, values in sdf.iterrows():
        values = values.to_dict()
        pms = {"grp":group, "org":values['organ'], "mod":values['modality'], "fct":values['functions']}
        GRAPH.query(query, params=pms)


def db_add_synapses(clear):
    """ Import synapses into DB from local files. """
    graph = graph_p2()
    if clear:
        graph.delete_all()

    conns = preproc.conns_df()
    transx = graph.cypher.begin()
    statement = "MATCH (n1:Neuron {name:{nm1}}), (n2:Neuron {name:{nm2}}) CREATE (n1)-[s:Synapse {name:n1.name+'->'+n2.name, type:{tp}, weight:{w}}]->(n2)" 
    for idx, row in conns.iterrows():
        transx.append(statement, {"nm1":row['Neuron1'], "nm2":row['Neuron2'], "tp":row["Type"], "w":row["Nbr"]})
    transx.commit()
    db_set_node_degrees()


def db_add_muscle_synapses(clear):
    """ Import muscle synapses into DB from local files. """
    graph = graph_p2()
    if clear:
        statement = "MATCH (n:Neuron)-[r]-(m:Muscle) DELETE r"
        graph.cypher.run(statement)

    conns = preproc.muscle_conns_df()
    transx = graph.cypher.begin()
    statement = "MATCH (n:Neuron {name:{neuron}}), (m:Muscle {name:{muscle}}) CREATE (n)-[s:Synapse {name:n.name+'->'+m.name, type:'NMJ', weight:{w}}]->(m)" 
    for idx, row in conns.iterrows():
        transx.append(statement, {"neuron":row['Neuron'], "muscle":row['Muscle'], "w":row["Weight"]})
    transx.commit()


def db_set_node_degrees():
    """ Calculate and set the in, out and total node degree for each node in the DB. """
    syn_in = "MATCH (n) OPTIONAL MATCH (n)<-[r]-(m) WITH n as n, COUNT(r) as inD SET n.inD=inD"
    syn_out = "MATCH (n) OPTIONAL MATCH (n)-[r]->(m) WITH n as n, COUNT(r) as outD SET n.outD=outD"
    total = "MATCH (n) SET n.D = (n.inD + n.outD)"
    GRAPH.query(syn_in)
    GRAPH.query(syn_out)
    GRAPH.query(total)


# ------------------------------------------------------------------------------------------------
# DB queries
# ------------------------------------------------------------------------------------------------
def neurons():
    """ Return all neurons in DB as list of dicts (d3.js format). """
    query = "MATCH (n:Neuron) return n"
    res = GRAPH.query(query)
    neuron_list = []
    for row in res:
        neuron = row[0]['data']
        neuron['id'] = row[0]['metadata']['id']
        neuron_list.append(neuron)
    return neuron_list


def neurons_sigma():
    """ Return all neurons in DB as list of dicts (sigma.js format). """
    query = "MATCH (n:Neuron) return n"
    res = GRAPH.query(query)
    neuron_list = []
    for row in res:
        neuron = row[0]['data']
        neuron['id'] = neuron['name']
        neuron['label'] = neuron['name']
        neuron_list.append(neuron)
    #return [r[0]['data'].update({'id':r[0]['data']['name']}) for r in res]
    return neuron_list


def synapses():
    """ Return all synapses in DB as list of dicts. """
    query = "MATCH (n1:Neuron)-[s:Synapse]->(n2:Neuron) return {from:n1.name, to:n2.name, type:s.type, weight:s.weight}"
    res = GRAPH.query(query)
    return [row[0] for row in res] 


def synapses_sigma(neurons, min_weight=0):
    """ Return all synapses in DB as list of dicts (sigma.js format). """
    query = "MATCH (n1:Neuron)-[s:Synapse]->(n2:Neuron) return {source:n1.name, target:n2.name, kind:s.type, size:s.weight, id:str(id(s))}"
    res = GRAPH.query(query)
    synapse_list = []
    for row in res:
        synapse = row[0]
        if synapse['size'] >= min_weight:
            synapse['type'] = 'curvedArrow'
            synapse['color'] = '#bbb'
            synapse['hover_color'] = '#000'
            synapse_list.append(synapse)
    return synapse_list


def synapses_d3(neuron_list, min_weight=1):
    """ Return all synapses in DB as list of dicts (d3.js format). """
    #q = "MATCH (n1:Neuron)-[s:Synapse]->(n2:Neuron) return {from:id(n1), to:id(n2), type:s.type, weight:s.weight, id:id(s)}"
    # For EJs we only need to show one direction
    query = "MATCH (n1:Neuron)-[s:Synapse]->(n2:Neuron) WHERE s.type<>'EJ' OR (s.type='EJ' AND id(n1)<id(n2)) RETURN {from:id(n1), to:id(n2), type:s.type, weight:s.weight, id:id(s)}"
    res = GRAPH.query(query)
    synapse_list = []
    for row in res:
        if row[0]['weight'] >= min_weight:
            synapse = row[0]
            synapse['source'] = [i for i, n in enumerate(neuron_list) if n['id'] == synapse['from']][0]
            synapse['target'] = [i for i, n in enumerate(neuron_list) if n['id'] == synapse['to']][0]
            synapse_list.append(synapse)
    return synapse_list


def all_cons_for_set(neuron_set):
    """ Return the subgraph consisting of all connections between specified list of neurons. """
    #q = "MATCH (n)-[r]-(m) WHERE n.name IN {g} AND m.name IN {g} RETURN DISTINCT r"
    query = "MATCH (n:Neuron)-[r]-(m:Neuron) WHERE n.name IN {g} AND m.name IN {g} RETURN COLLECT(DISTINCT r), COLLECT(DISTINCT n)"
    res = GRAPH.query(query, params={"g":neuron_set})[0]

    res_syns = res[0]
    res_nodes = res[1]
    synapse_list = []
    neuron_list = []

    for row in res_nodes:
        neuron = row['data']
        neuron['id'] = row['metadata']['id']
        neuron_list.append(neuron)

    for row in res_syns:
        synapse = row['data']
        synapse['from'] = int(row['start'].rsplit("/", 1)[1])
        synapse['to'] = int(row['end'].rsplit("/", 1)[1])
        synapse['source'] = [i for i, n in enumerate(neuron_list) if n['id'] == synapse['from']][0]
        synapse['target'] = [i for i, n in enumerate(neuron_list) if n['id'] == synapse['to']][0]
        synapse['id'] = row['metadata']['id']
        synapse_list.append(synapse)

    return {"synapses":synapse_list, "neurons":neuron_list}


def subgraph(gr1, gr2, max_length=2, min_ws=2, min_wj=2, path_dir='uni', rec=None):
    """ Return the subgraph connecting neurons in group1 with neurons in group2 """
    
    path_dir = '->' if path_dir == 'uni' else '-'
    query = "MATCH (n1:Neuron) WHERE ( (n1.group IN {g1}) "
    if rec:
        query += "OR (HAS(n1.modalities) AND ANY(s IN SPLIT(n1.modalities, ', ') WHERE s IN {recs}))"
    query += ") MATCH (n2:Neuron) WHERE n2.group IN {g2} "
    query += "MATCH p=(n1)-[r*1.." + str(max_length) + "]" + path_dir + "(n2) "
    query += "WHERE ALL(c IN r WHERE (c.type='EJ' AND c.weight >= {wj}) OR (c.type<>'EJ' AND c.weight >= {ws})) "
    query += ("AND ALL(n in NODES(p) WHERE 1=length(filter(m in NODES(p) WHERE m=n))) "
              "WITH DISTINCT r AS dr, NODES(p) AS ns "
              "UNWIND dr AS udr UNWIND ns AS uns "
              "RETURN COLLECT(DISTINCT udr), COLLECT(DISTINCT uns)")

    #print query
    parameters = {"g1":gr1, "g2":gr2, "ws":min_ws, "wj":min_wj, "l":max_length, "recs":rec}    
    res = GRAPH.query(query, params=parameters)[0]
    res_syns = res[0]
    res_nodes = res[1]
    synapse_list = []
    neuron_list = []
    
    for row in res_nodes:
        neuron = row['data']
        neuron['id'] = row['metadata']['id']
        neuron_list.append(neuron)

    for row in res_syns:
        synapse = row['data']
        # Connected nodes are referenced by their index in start and end properties (within url)
        synapse['from'] = int(row['start'].rsplit("/", 1)[1])
        synapse['to'] = int(row['end'].rsplit("/", 1)[1])
        synapse['source'] = [i for i, n in enumerate(neuron_list) if n['id'] == synapse['from']][0]
        synapse['target'] = [i for i, n in enumerate(neuron_list) if n['id'] == synapse['to']][0]
        synapse['id'] = row['metadata']['id']
        synapse_list.append(synapse)

    return {"synapses":synapse_list, "neurons":neuron_list}


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
