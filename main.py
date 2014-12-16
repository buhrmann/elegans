import os
from flask import Flask

# from bulbs.neo4jserver import Graph, NEO4J_URI
# from bulbs.config import Config as BulbsConfig, DEBUG

# # Choose local or remote DB
# bulbs_config = BulbsConfig(NEO4J_URI)
# bulbs_config.set_logger(DEBUG)
# if os.environ.get('NEO4J_REST_URL'):
#     bulbs_config.set_neo4j_heroku()        
    
# g = Graph(bulbs_config)

from py2neo import Graph
from py2neo import cypher
from urlparse import urlparse

if os.environ.get('NEO4J_REST_URL'):
  g = Graph(os.environ.get('NEO4J_REST_URL'))
else:
  g = Graph()

app = Flask(__name__)

@app.route('/')
def index():
    #n = len(g.V)
    n_rel = len(list(g.match()))
    return 'Graphs has ' + str(n_rel) + ' relationships.' 


# Autostart
# ------------------------------------------------------------------------------
if __name__ == '__main__':
    app.run(debug=True)