"""
Process neurons, synapses, muscles etc. from Chen's excel(csv) for import into DB.
"""
import numpy as np
import pandas as pd
import requests
from bs4 import BeautifulSoup as bs

# Filenames
data_folder = "data/"
chen_neurons_fnm = "ChenVarshney/NeuronType.xls"
chen_conns_fnm = "ChenVarshney/NeuronConnect.xls"

kaiser_pos_fnm = "DynamicConnectome/celegans277/celegans277positions.csv"
kaiser_pos_lab_fnm = "DynamicConnectome/celegans277/celegans277labels.csv"

ow_neurons_fnm = ""
ww_neurons_fnm = "WormWeb/name_neurons.txt"

sensors_fnm = "Self/Sensors.tsv"

neuron_attrs = ["Neuron", "SomaPosition", "SomaRegion", "AYGanglionDesignation", "AYNbr"]


def zero_lead(num_str):
    """ Add leading zero to single digits at the end of a string """
    if num_str[-1].isdigit() and not num_str[-2].isdigit():
        return num_str[0:-1] + "0" + num_str[-1]
    else:
        return num_str


def remove_leading_zero(num_str):
    """ Remove leading zero from single digits at the end of a string """
    if num_str[-1].isdigit() and num_str[-2] == '0':
        return num_str[0:-2] + num_str[-1]
    else:
        return num_str


def sym_node_name(name):
    """ For names of symmetric nodes ending in L or R, return the counterpart's name."""
    suffix = name[-1]
    if suffix == "L":
        return name[0:-1] + "R"
    elif suffix == "R":
        return name[0:-1] + "L"
    else:
        return name


def expand_type_abbr(name):
    """ Expand neuron type appreviation: se->sensory neuron, mo->motor neuron, in->interneuron, mu->muscle, bm->basement membrane, 
    # gln->gland cell, mc->marginal cell """
    sep = ", "
    types = []
    if not name.find("se") == -1: types.append("sensory")
    if not name.find("mo") == -1: types.append("motor")
    if not name.find("in") == -1: types.append("inter")
    if not name.find("mu") == -1: types.append("muscle")
    if not name.find("bm") == -1: types.append("basement membrane")
    if not name.find("gln") == -1: types.append("gland cell")
    if not name.find("mc") == -1: types.append("marginal cell")
    return sep.join(types)


def kaiser_positions_df():
    """ Return a pandas DF containing 2d positions from Kaiser indexed by neuron label """
    pos_labels = pd.io.parsers.read_csv(data_folder + kaiser_pos_lab_fnm, header=None)
    positions = pd.io.parsers.read_csv(data_folder + kaiser_pos_fnm, header=None)
    dfr = pd.concat([pos_labels, positions], axis=1, ignore_index=True)
    dfr.columns = ["label", "kx", "ky"]
    dfr = dfr.set_index("label")
    return dfr


def chen_neurons_df():
    """ Return a pandas DF containing neuron information from Chen indexed by neuron label """
    dfr = pd.io.excel.read_excel(data_folder + chen_neurons_fnm, sheetname=0, index_col=None, header=0)     
    dfr.columns = [x.replace(" ", "") for x in dfr.columns]
    dfr = dfr[neuron_attrs]
    dfr["Neuron"] = [remove_leading_zero(x) for x in dfr["Neuron"]]
    dfr.set_index("Neuron", drop=True, inplace=True)
    return dfr


def ww_neurons_df():
    """ Return WormWeb info about neuron class and type (from japanese CCEP group, itself based on White data) """
    dfr = pd.io.parsers.read_csv(data_folder + ww_neurons_fnm, comment="#", 
            header=None, index_col=0, sep=" ", skipinitialspace=True, names=["name", "group", "type"])
    dfr["type"] = [expand_type_abbr(x) for x in dfr["type"]]
    return dfr


def wa_links_df():
    """ Scrape following page for neuron single page links: http://www.wormatlas.org/neurons/Individual%20Neurons/Neuronframeset.html """
    base_url = "http://www.wormatlas.org/neurons/Individual%20Neurons/"
    table_url = base_url + "Neuronframeset.html"
    header = {'User-agent' : "Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2049.0 Safari/537.36"}
    res = requests.get(table_url, headers=header)
    html = res.text
    soup = bs(html)

    def rem_slash(name):
        """ Remove extra slashes from some neuron names """
        if name[-2] == "/": 
            return name[:-2]
        else:
            return name

    links = soup.find_all("table")[2].find_all("a")
    hrefs = [base_url + l['href'] for l in links]
    names = [rem_slash(l.string) for l in links]

    dfr = pd.DataFrame()
    dfr['link'] = hrefs
    dfr.index = names

    nans = dfr.index[dfr['link'].isnull()]
    if len(nans) > 0:
        print [dfr.loc[x] for x in nans]

    return dfr


# Turns our own generated sensor file into df
def sensors_df():    
    df = pd.io.parsers.read_csv(data_folder + sensors_fnm, sep="\t", comment="#", header=0, 
        index_col=False, skipinitialspace=True, na_values=[''])
    df = df.drop(["number", "location"], 1)
    df.set_index("group", drop=True, inplace=True)
    df.fillna('', inplace=True)
    return df


# Kaiser's positions are missing for some left-right symmetric neurons (AIBL, AIYL, SMDVL), 
# so we substitute the right "mirror" neuron, which is ok anyway, since the left-right 
# coordinates are not provided anyway. Equally, Chen/Varshney's data doesn't have a VC06 neuron. 
# In Varshney paper it is mentioned that it doesn't make synapses with other neurons 
# (and neither does CANL/R) so fine to omit. The set therefore contains 279 of the 282 somatic
# nervous system neurons (of 302 total including pharyngeal NS).
def neurons_df():
    """ Join all available neuron information into a single Pandas DF """
    nodes = chen_neurons_df()
    pos = kaiser_positions_df()

    nodes_only = np.setdiff1d(nodes.index.values, pos.index.values)
    pos_only = np.setdiff1d(pos.index.values, nodes.index.values)
    print "Nodes but not pos: ", nodes_only
    print "Pos but not nodes: ", pos_only

    # Perform a left join with nodes on the left and positions on the right, 
    # so we only use those neurons provided by Chen
    dfr = nodes.join(pos, how="left")

    # Now add missing positions from symmetric partners
    for node in nodes_only:
        mirror = sym_node_name(node)
        print "Copying position for ", node, " from ", mirror
        dfr.loc[node, 'kx'] = dfr.loc[mirror, 'kx']
        dfr.loc[node, 'ky'] = dfr.loc[mirror, 'ky']

    # Join with info about neuron class and type
    ww_nodes = ww_neurons_df()
    dfr = dfr.join(ww_nodes, how="left")

    # Join links from worm atlas website
    wa_links = wa_links_df()
    dfr = dfr.join(wa_links, how="left")

    print dfr.info()
    return dfr


# The original xsl file lists every synapse twice, once as "send" from n1 to n2,
# and once as "receive" by n2 from n1. Here we only keep the "send" copy.
def conns_df():
    """ Return a pandas DF of connections in from->to format """
    dfr = pd.io.excel.read_excel(data_folder + chen_conns_fnm, sheetname=0, index_col=None, header=0)
    dfr.columns = [x.replace(" ", "") for x in dfr.columns]
    dfr["Neuron1"] = [remove_leading_zero(x) for x in dfr["Neuron1"]]
    dfr["Neuron2"] = [remove_leading_zero(x) for x in dfr["Neuron2"]]
    dfr = dfr[(dfr['Type'] != 'R') & (dfr['Type'] != 'Rp') & (dfr['Type'] != 'NMJ')]
    return dfr
