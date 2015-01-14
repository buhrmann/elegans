// Setup
var width = 1000;
var height = 800;
var data;
var force;
var nodeColorScale;
var nodeRadiusScale;
var linkWeightScale;
var nfilter = crossfilter(), 
    efilter = crossfilter();
var nodesDegDim, edgesWeightDim;
var nodesConDim, edgesConDim;
var nodes = [];
var links = [];
var linked = {};
var node, link;
var svg;
var ndegVal = 2, 
    wminVal = 3;
var highlight = 0;
var highlightId = -1;

//-------------------------------------------------------------------
// Grap with d3
//-------------------------------------------------------------------
graph = function(id, d) {

    data = d;
    var n = data.neurons.length;
    var s = width / 1;
    data.neurons.forEach(function(d, i) { 
        d.x = d.y = s/n * i;
        //d.fixed = true;
    });
    
    // Containers
    svg = d3.select(id).append("svg")
        .attr("viewBox", "0 0 " + width + " " + height)
        .attr("preserveAspectRatio", "xMidYMid meet");

    var linkLayer = svg.append("g");
    var nodeLayer = svg.append("g");

    // Scales
    //nodeColorScale = d3.scale.category20();
    colors = ["#00ADEF", "#ED008C", "#F5892D", "#BBCB5F", "#999", "#ccc"];
    nodeColorScale = d3.scale.ordinal().range(colors);
    //nodeColorScale = d3.scale.ordinal().range(colorbrewer["Accent"][6].reverse());
    
    var degreeDomain = d3.extent(data.neurons, function(n) { return n.D; });
    nodeRadiusScale = d3.scale.linear().domain(degreeDomain).range([5,30]);

    var weightDomain = d3.extent(data.synapses, function(s) { return s.weight; });
    linkWeightScale = d3.scale.linear().domain(weightDomain).range([1,5]);

    force = d3.layout.force()
        .nodes(nodes)
        .links(links)
        .charge(-250)
        .linkDistance(120)
        .linkStrength(0.9)
        .friction(0.5)
        .gravity(0.3)
        .size([width, height])
        .on("tick", tick);

    node = nodeLayer.selectAll(".node");
    link = linkLayer.selectAll(".link");  

    svg.on("click", function() {    
        node.style("opacity", 1);
        link.style("opacity", 1);
        highlight = 0;
        d3.event.stopPropagation();
    })    

    // Crossfilter
    nfilter.add(data['neurons']);
    efilter.add(data['synapses']);
    nodesDegDim = nfilter.dimension(function(d) { return d.D; });
    edgesWeightDim = efilter.dimension(function(d) { return d.weight; });

    //Search    
    var optArray = d3.set(data.neurons.map(function(d) { return d.group;} ).sort()).values();
    $(function () {
        $("#group1").autocomplete({source: optArray});
        $("#group2").autocomplete({source: optArray});
    });

    update(data.neurons, data.synapses);

    filter(ndegVal, wminVal);

    buildAdjacency();
}

function updateCrossFilter(n, s) {
    nodesDegDim.filter(null);
    edgesWeightDim.filter(null);
    nfilter.remove();
    efilter.remove();
    nfilter.add(n);
    efilter.add(s);    

    update(n, s);
    filter(ndegVal, wminVal);
}


function buildAdjacency() {
    data.neurons.forEach(function (d) { linked[d.id + "," + d.id] = true; });
    data.synapses.forEach(function (d) { linked[d.from + "," + d.to] = true; });
}

function neighboring(a, b) {
    return linked[a.id + "," + b.id];
}


function filterNDeg(ndeg) {
    ndegVal = ndeg;
    document.querySelector('#ndeglabel').value = ndeg;
    filter(ndegVal, wminVal);
}

function filterWMin(wmin) {
    wminVal = wmin;
    document.querySelector('#wminlabel').value = wmin;
    filter(ndegVal, wminVal);
}

function filter(ndeg, wmin) {

    var prune = d3.select("#prune1").classed("active");

    if (typeof ndeg == 'undefined') ndeg = ndegVal; //$( "#nsl_slider" ).slider( "value" );
    if (typeof wmin == 'undefined') wmin = wminVal; //$( "#w_slider" ).slider( "value" );

    // Nodes
    nodesDegDim.filter([ndeg, Infinity]);
    var n = nodesDegDim.top(Infinity);
    nodeIds = d3.set(n.map(function(d) { return d.id; }));


    // Links
    edgesWeightDim.filter([wmin, Infinity]);    
    edgesConDim = efilter.dimension(function(d) {
        return nodeIds.has(d.from) && nodeIds.has(d.to);
    });
    edgesConDim.filter(function(d) { return d;});
    var e = edgesConDim.top(Infinity);
    edgesConDim.dispose();

    // Filter unconnected nodes
    var fromIds = e.map(function(d) { return d.from; });
    var toIds = e.map(function(d) { return d.to; });
    var edgeIds = d3.set(fromIds.concat(toIds));
    var ncon = nfilter.dimension(function(d) {
        return edgeIds.has(d.id);
    });
    ncon.filter(function(d) { return d; });
    n = ncon.top(Infinity);
    ncon.dispose();

    if(prune){
        update(n, e);
    }
    else{
        node.style("opacity", function(d) {
            if (!nodeIds.has(d.id))
                return "0";
            else
                return "1";
        });

        edgeIds = d3.set(e.map(function(d) { return d.id; }));
        link.style("opacity", function(d) {
            if (!edgeIds.has(d.id))
                return "0";
            else
                return "1";
        });
    }

    var optArray = n.map(function(d) { return d.name;} ).sort();
    $(function () {
        $("#search").autocomplete({source: optArray});
    });
    
}


function removePopovers() {
  $('.popover').each(function() {
    $(this).remove();
  }); 
}


function htmlForNode(d){
    var str = 
        "Group: " + d.group + "<br>" +
        "Type: " + d.type + "<br>" +
        "Ganglion: " + d.AYGanglionDesignation + "<br>" +
        "Degrees:" + "<br>&emsp;" + "in " + d.inD + " out " + d.outD + " total " + d.D + "<br>";
    return str;
}


function showPopover(d, dir) {
  $(this).popover({
    title: "<a href='" + d.link + "'>" + d.name + "</a> (AYNbr: " + d.AYNbr + ")",
    placement: dir,
    container: 'body',
    trigger: 'manual',
    html : true,
    content: function() { return htmlForNode(d); }
  });
  $(this).popover('show');
}


update = function(n, l) {
    nodes = n;
    links = l;

    var c = Math.min(-700 + wminVal * 100, -250);
    var ld = Math.max(180 - wminVal * 10, 120);
    console.log(c, ld);
    force.nodes(nodes);
    force.links(links);
    force.charge(c);
    force.linkDistance(ld);
    force.start();

    // Update links
    link = link.data(force.links(), function(d) { return d.id; });

    link.enter().append("line")
        .attr("class", "link")
        .classed("junction", function(d) { return (d.type == 'EJ' || d.type == 'NMJ')})
        .style("stroke-width", function(d) { return linkWeightScale(d.weight); })
        .style("stroke", function(d) { return nodeColorScale(d.source.type); });

    link.exit().remove();

    // Update nodes
    node = node.data(force.nodes(), function(d) { return d.id; });
        
    var nodeEnter = node.enter().append("g")
        .attr("class", "node")
        .call(force.drag)
        //.on('click', connectedNodes);
        .on('dblclick', function(d) { window.open(d.link, "_blank");});

    nodeEnter.append("circle")
        .attr("r", function(d) { return nodeRadiusScale(d.D); })
        .style("fill", function(d) { return nodeColorScale(d.type); });

    nodeEnter.append("text")
        .attr("class", "node-label")
        .attr("text-anchor", "middle")
        .attr("dy", "0.35em")
        .text(function(d) { return d.name; });

    nodeEnter.on("mouseover", function(d) {
        showPopover.call(this, d, 'auto top');
        connectedNodes(d);   
    })

    nodeEnter.on("mouseout", function(d) {
        removePopovers();
        connectedNodes(null);
    })

    node.exit().remove();

}


tick = function() {
    force.on("tick", function() {
        link.attr("x1", function(d) { return d.source.x; })
            .attr("y1", function(d) { return d.source.y; })
            .attr("x2", function(d) { return d.target.x; })
            .attr("y2", function(d) { return d.target.y; });

        node.attr("transform", function (d) { return "translate(" + d.x + "," + d.y + ")"; });
        node.each(collide(0.2));
    });
}

collide = function(alpha) {
    var padding = 1;    
    
    var quadtree = d3.geom.quadtree(nodes);
    return function(d) {
        var radius = nodeRadiusScale(d.D);
        var rb = 2*radius + padding,
        nx1 = d.x - rb,
        nx2 = d.x + rb,
        ny1 = d.y - rb,
        ny2 = d.y + rb;
        quadtree.visit(function(quad, x1, y1, x2, y2) {
            if (quad.point && (quad.point !== d)) {
                var x = d.x - quad.point.x,
                y = d.y - quad.point.y,
                l = Math.sqrt(x * x + y * y);
                if (l < rb) {
                    l = (l - rb) / l * alpha;
                    d.x -= x *= l;
                    d.y -= y *= l;
                    quad.point.x += x;
                    quad.point.y += y;
                }
            }
            return x1 > nx2 || x2 < nx1 || y1 > ny2 || y2 < ny1;
        });
    };
}


function connectedNodes(d) {    
    if (d != null && (highlight == 0 || highlightedId != d.id)) {
        //Reduce the opacity of all but the neighbouring nodes
        highlightedId = d.id;
        node.style("opacity", function (o) {
            return neighboring(d, o) | neighboring(o, d) ? 1 : 0.1;
        });
        link.style("opacity", function (o) {
            return d.id==o.from | d.id==o.to ? 1 : 0.05;
        });
        //Reduce the op
        highlight = 1;
    } else {
        //Put them back to opacity=1
        node.style("opacity", 1);
        link.style("opacity", 1);
        highlight = 0;
    }
    d3.event.stopPropagation();
}


function searchNode() {
    var selectedVal = document.getElementById('group1').value;
    svg = d3.select("svg");
    var sel = node.filter(function(d) { return d.name == selectedVal; })
    connectedNodes(sel.data()[0]);
}


function graphReset() {
    $.getJSON($SCRIPT_ROOT + '/_reset', function(d) {
            data = d.result;
            updateCrossFilter(data['neurons'], data['synapses']);        
          });
          return false;
}


function subGraph() {
    var g1 = document.getElementById('group1').value;
    var g2 = document.getElementById('group2').value;
    var w = document.getElementById('subwslider').value;
    var l = document.getElementById('subpslider').value;
    var dir = $('#dirButton').text();
    //dir = dir.slice(2, dir.length-2);
    $.getJSON($SCRIPT_ROOT + '/_subgraph', {
        group1: g1,
        group2: g2,
        minWeight: w,
        maxLength: l,
        dir: dir
      }, function(d) {
        //console.log(d.result);
        data = d.result;
        updateCrossFilter(data['neurons'], data['synapses']);        
      });
      return false;
}

	