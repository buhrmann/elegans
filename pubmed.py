from Bio import Entrez

Entrez.email = 'thomas.buehrmann@gmail.com'

def num_articles_for_neuron(neuron, query):
    search_term = "\"Caenorhabditis elegans\"[All Fields] AND \"" + query + "\"[All Fields] AND \"" + neuron + "\"[All Fields]"
    print "Searching pubmed for: "
    print search_term
    handle = Entrez.esearch(db="pubmed", term=search_term, retmax=1000, rettype='count')
    record = Entrez.read(handle)
    print "Result:"
    print record
    return int(record['Count'])


def neurons_for_query(neuron_names, query, threshold=1):
    filtered_neurons = []
    num_neurons = len(neuron_names)
    for i, n in enumerate(neuron_names):
        print "Checking neuron %i of %i: %s" % (i, num_neurons, n)
        num_articles = num_articles_for_neuron(n, query)
        if num_articles >= threshold:
            print "Found %i articles." % (num_articles)
            filtered_neurons.append(n)
    return filtered_neurons
