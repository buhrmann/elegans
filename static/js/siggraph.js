//-------------------------------------------------------------------
// Graph with sigma
//-------------------------------------------------------------------

graphSigma = function(id, data) {

    console.log(data);

    // Prepare data    
    data.nodes.forEach(function(n) {
        n['size'] = 3
        n['type'] = 'def'
    })

    // Select neighbours for node subselction
    sigma.classes.graph.addMethod('neighbors', function(nodeId) {
        var k,
            neighbors = {},
            index = this.allNeighborsIndex[nodeId] || {};

        for (k in index)
          neighbors[k] = this.nodesIndex[k];

        return neighbors;
    });

    // Build basic graph
    var s = new sigma({
        renderer: {
            container: document.getElementById(id),
            type: 'canvas'
        },
        settings: {
            doubleClickEnabled: false,
            defaultNodeColor: '#ec5148',
            edgeColor: 'default',
            defaultEdgeColor: '#bbb',
            edgeLabelSize: 'proportional',
            drawLabels: false,
            //batchEdgesDrawing: true,
            //hideEdgesOnMove: true,
            minEdgeSize: 0.5,
            maxEdgeSize: 8,
            minNodeSize: 3,
            maxNodeSize: 15,
            minArrowSize: 1,
            enableEdgeHovering: true,
            edgeHoverColor: 'edge',
            defaultEdgeHoverColor: '#000',
            edgeHoverSizeRatio: 1,
            edgeHoverExtremities: true,
        }
    });

    s.graph.read(data);


    // Node selection
    s.bind('clickNode', function(e) {
        var nodeId = e.data.node.id;
        var toKeep = s.graph.neighbors(nodeId);
        toKeep[nodeId] = e.data.node;

        // Highlight neighbour nodes
        s.graph.nodes().forEach(function(n) {
            if (toKeep[n.id])
                n.size = 10;
            else
                n.size = 3;
        });

        // Highlight neighbour edges
        s.graph.edges().forEach(function(e) {
            if (toKeep[e.source] && toKeep[e.target])
                e.color = '#000';
            else
                e.color = '#bbb';
        });
        s.refresh();
    });


    // Node deselection
    s.bind('clickStage', function(e) {
        s.graph.nodes().forEach(function(n) {
          n.size = 3;
        });

        s.graph.edges().forEach(function(e) {
          e.color = '#bbb';
        });

        // Same as in the previous event:
        s.refresh();
    });


    s.refresh();

    config = {'linLogMode':true}
    s.startForceAtlas2(config);

    //var filter = new sigma.plugins.filter(s);
}