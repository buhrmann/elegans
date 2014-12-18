This directory contains a file 

        neurodata.txt

which is a tab delimited Unix ASCII text file containing the synaptic
connectivity data from two electron microscope reconstructions of the
nerve ring, N2U and JSH.  These are data collected by John White,
Eileen Southgate, Nichol Thomson and Sydney Brenner (White et al, Phil
Trans Roy Soc B 314:1-340, 1986).  The data in the file are not
exactly those in the paper -- when they were entered various
inconsistencies were found and corrected.  Also the paper used data
from other reconstructions in areas outside the ring and RVG, which
are not represented here.

The columns in the file are:

<neuron 1>
<neuron 2>
<synapse type>          see below
<reconstruction>        one of JSH, N2U
<number of synapses>

The synapse type is one of 
        Gap_junction    direction is not visible here
        Send            unambiguous chemical synapse from neuron 1 to neuron 2
        Send_joint      chemical synapse from 1 where 2 is a possible or
                                shared recipient
        Receive         unambiguous chemical synapse 2 to 1
        Receive_joint   chemical synapse from 2 where 1 is a possible or
                                shared recipient

See the paper for discussion of the joint type synapses (they may be
called "multiple" there).

I think N2U was a hermaphrodite adult and JSH an L4 male*, but do not
rely on the differences being sex or stage specific: there is likely
to be equally as much random difference between animals; you will be
able to see there are significant differences between bilaterally
symmetric sides.

Richard Durbin 980225

*WormAtlas editors' note: While Richard Durbin suggests that JSH was an L4 male, it is now believed that this animal was an L4 hermaphrodite.