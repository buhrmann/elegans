# Processes neurons, muscles etc. from Chen's excel(csv) into database
import numpy as np
import pandas as pd
import requests
import xlrd
from bs4 import BeautifulSoup as bs

# Filenames
data_folder = "data/"
chen_neurons_fnm = "ChenVarshney/NeuronType.xls"
chen_conns_fnm = "ChenVarshney/NeuronConnect.xls"

kaiser_pos_fnm = "DynamicConnectome/celegans277/celegans277positions.csv"
kaiser_pos_lab_fnm = "DynamicConnectome/celegans277/celegans277labels.csv"

ow_neurons_fnm = ""
ww_neurons_fnm = "WormWeb/name_neurons.txt"

neuron_attrs = ["Neuron", "SomaPosition", "SomaRegion", "AYGanglionDesignation", "AYNbr"]

# Adds leading zero to single digits at the end of a string
def zeroLead(x):
    if x[-1].isdigit() and not x[-2].isdigit():
        return x[0:-1] + "0" + x[-1]
    else:
        return x

def removeLeadingZero(x):
    if x[-1].isdigit() and x[-2] == '0':
        return x[0:-2] + x[-1]
    else:
        return x        


# For symmetric nodes ending in L or R, returns the counterpart
def symNodeName(name):
    suffix = name[-1]
    if suffix == "L":
        return name[0:-1] + "R"
    elif suffix == "R":
        return name[0:-1] + "L"
    else:
        return x


# Expands se->sensory neuron, mo->motor neuron, in->interneuron, mu->muscle, bm->basement membrane, 
# gln->gland cell, mc->marginal cell
def expandTypeAbbr(name):
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


# Returns a pandas DF indexed by neuron label
def kaiserPositionDf():
    pos_labels = pd.io.parsers.read_csv(data_folder + kaiser_pos_lab_fnm, header=None)
    positions = pd.io.parsers.read_csv(data_folder + kaiser_pos_fnm, header=None)
    df = pd.concat([pos_labels, positions], axis=1, ignore_index=True)
    df.columns = ["label", "kx", "ky"]
    #   df["label"] = [zeroLead(x) for x in df["label"]]
    df = df.set_index("label")
    return df


# Returns a pandas DF indexed by neuron label
def chenNeuronDf():
    df = pd.io.excel.read_excel(data_folder + chen_neurons_fnm, sheetname=0, index_col=None, header=0)     
    df.columns = [x.replace(" ", "") for x in df.columns]
    df = df[neuron_attrs]
    df["Neuron"] = [removeLeadingZero(x) for x in df["Neuron"]]
    df.set_index("Neuron", drop=True, inplace=True)
    return df


# WormWeb info about neuron class and type (from japanese CCEP group, itself based on White data)
def wwNeuronDf():
    df = pd.io.parsers.read_csv(data_folder + ww_neurons_fnm, comment="#", 
        header=None, index_col=0, sep=" ", skipinitialspace=True, names=["name", "group", "type"])
    df["type"] = [expandTypeAbbr(x) for x in df["type"]]
    #df.index = [zeroLead(x) for x in df.index]
    return df


# Scrapes following page for neuron single page links: http://www.wormatlas.org/neurons/Individual%20Neurons/Neuronframeset.html
def waLinksDf():
    base_url = "http://www.wormatlas.org/neurons/Individual%20Neurons/"
    table_url = base_url + "Neuronframeset.html"
    header = {'User-agent' : "Mozilla/5.0 (Windows NT 6.3; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2049.0 Safari/537.36"}
    r = requests.get(table_url, headers=header)
    html = r.text
    soup = bs(html)

    # Manual inspection shows some neuron names have extra slashes
    def remSlash(x):
        if x[-2] == "/": 
            return x[:-2]
        else:
            return x

    links = soup.find_all("table")[2].find_all("a")
    hrefs = [ base_url + l['href'] for l in links ]
    names = [ remSlash(l.string) for l in links]

    df = pd.DataFrame()
    df['link'] = hrefs    
    df.index = names
    #df.index = [zeroLead(x) for x in df.index]

    nans = df.index[df['link'].isnull()]
    if len(nans) > 0:
        print [df.loc[x] for x in nans]

    return df


# Kaiser's positions are missing for some left-right symmetric neurons (AIBL, AIYL, SMDVL), so we substitute the 
# right "mirror" neuron, which is ok anyway, since the left-right coordinates are not provided anyway.
# Equally, Chen/Varshney's data doesn't have a VC06 neuron. In Varshney paper it is mentioned that it doesn't make synapses
# with other neurons (and neither does CANL/R) so fine to omit. The set therefore contains 279 of the 282 somatic
# nervous system neurons (of 302 total including pharyngeal NS).
# Otherwise names seem to match.
def neuronsDf():
    nodes = chenNeuronDf()
    pos = kaiserPositionDf()

    nodes_only = np.setdiff1d(nodes.index.values, pos.index.values)
    pos_only = np.setdiff1d(pos.index.values, nodes.index.values)
    print "Nodes but not pos: ", nodes_only    
    print "Pos but not nodes: ", pos_only

    # Perform a left join with nodes on the left and positions on the right, so we only use those neurons provided by Chen
    df = nodes.join(pos, how="left")

    # Now add missing positions from symmetric partners
    for node in nodes_only:
        mirror = symNodeName(node)
        print "Copying position for ", node, " from ", mirror
        df.loc[node, 'kx'] = df.loc[mirror, 'kx']
        df.loc[node, 'ky'] = df.loc[mirror, 'ky']

    # Join with info about neuron class and type
    ww_nodes = wwNeuronDf()
    df = df.join(ww_nodes, how="left")

    # Join links from worm atlas website
    wa_links = waLinksDf()
    df = df.join(wa_links, how="left")

    print df.info()
    return df


# Returns a pandas DF of connections in from->to format
# The original xsl file lists every synapse twice, once as "send" from n1 to n2, 
# and once as "receive" by n2 from n1. Here we only keep the "send" copy.
def connsDf():
    df = pd.io.excel.read_excel(data_folder + chen_conns_fnm, sheetname=0, index_col=None, header=0)
    df.columns = [x.replace(" ", "") for x in df.columns]
    df["Neuron1"] = [removeLeadingZero(x) for x in df["Neuron1"]]
    df["Neuron2"] = [removeLeadingZero(x) for x in df["Neuron2"]]
    df = df[(df['Type'] != 'R') & (df['Type'] != 'Rp') & (df['Type'] != 'NMJ')]
    return df


# Main
if __name__ == "__main__":    
    print process()