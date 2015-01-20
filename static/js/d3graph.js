// Setup
// var width = 1000;
// var height = 1000;
var width = window.innerWidth;
var height = window.innerHeight;
var data;
var force, drag, zoom;
var nodeColorScale;
var nodeRadiusScale;
var linkWeightScale;
var nfilter = crossfilter(), 
    efilter = crossfilter();
var nodesDegDim, edgesWeightDim, junctionsWeightDim;
var nodesConDim, edgesConDim;
var nodes = [];
var links = [];
var linked = {};
var node, link, nodeLayer, linkLayer, container;
var svg;
var ndegVal = 2, 
    wminVal = 3,
    jminVal = 2;
var highlight = 0;
var highlightId = -1;
var showArrow = 0,
    showJunctions = 1,
    showSynapses = 1;

var arcs = false;
var sqrt3 = 1.7320508075688772;

//-------------------------------------------------------------------
// Grap with d3
//-------------------------------------------------------------------
graph = function(id, d) {

    data = d;
    
    // Containers
    svg = d3.select(id).append("svg")
        .attr("viewBox", "0 0 " + width + " " + height)
        .attr("preserveAspectRatio", "xMidYMid meet");

    container = svg.append("g").attr("style", "cursor:move");
    linkLayer = container.append("g");
    nodeLayer = container.append("g");

    // Scales
    //nodeColorScale = d3.scale.category20();
    colors = ["#00ADEF", "#ED008C", "#F5892D", "#BBCB5F", "#999", "#ccc"];
    nodeColorScale = d3.scale.ordinal().range(colors);
    //nodeColorScale = d3.scale.ordinal().range(colorbrewer["Accent"][6].reverse());
    
    var degreeDomain = d3.extent(data.neurons, function(n) { return n.D; });
    nodeRadiusScale = d3.scale.linear().domain(degreeDomain).range([10,25]);

    var weightDomain = d3.extent(data.synapses, function(s) { return s.weight; });
    linkWeightScale = d3.scale.linear().domain(weightDomain).range([1,5]);

    initNodePos(data.neurons);
    addNodeRadius(data.neurons);

    // Build arrows
    svg.append("svg:defs").selectAll("marker").data(colors)      // Different link/path types can be defined here
      .enter().append("svg:marker")    // This section adds in the arrows
        .attr("id", String)
        .attr("viewBox", "0 -5 10 10")
        .attr("refX", 10)
        .attr("refY", -0)
        .attr("markerWidth", 8)
        .attr("markerHeight", 8)
        .attr("markerUnits", "userSpaceOnUse")
        .attr("orient", "auto")
        .attr("style", function(d) { return "fill: " + d + "; visibility: hidden;"})
            .append("svg:path")
                .attr("d", "M0,-5L10,0L0,5");

    // Create force layout
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

    drag = force.drag().on("dragstart", dragstarted);
    zoom = d3.behavior.zoom().scaleExtent([0.75, 2]).on("zoom", zoomed); 
    svg.call(zoom).on("dblclick.zoom", null);

    node = nodeLayer.selectAll(".node");
    link = linkLayer.selectAll(".link");  

    // svg.on("click", function() {    
    //     node.style("opacity", 1);
    //     link.style("opacity", 0.25);
    //     highlight = 0;
    //     d3.event.stopPropagation();
    // });  

    // Crossfilter
    nfilter.add(data['neurons']);
    efilter.add(data['synapses']);
    nodesDegDim = nfilter.dimension(function(d) { return d.D; });
    edgesWeightDim = efilter.dimension(function(d) { return d.type != "EJ" ? d.weight : 6666; });
    junctionsWeightDim = efilter.dimension(function(d) { return d.type == "EJ" ? d.weight : 6666; });

    //S earch    
    var groupArray = d3.set(data.neurons.map(function(d) { return d.group;} ).sort()).values();
    $(function () {
        $("#group1").autocomplete({source: groupArray});
        $("#group2").autocomplete({source: groupArray});
    });
    var nameArray = d3.set(data.neurons.map(function(d) { return d.name;} ).sort()).values();
    $(function () {
        $("#search-node").autocomplete({source: nameArray});
    });

    update(data.neurons, data.synapses);
    filter(ndegVal, wminVal, jminVal);
    
    // Warm-start
    for (i = 0; i < 10; i++)
        force.tick();
    

    buildAdjacency();
}

function updateCrossFilter(n, s) {
    console.log(n.length, s.length);
    nodesDegDim.filter(null);
    edgesWeightDim.filter(null);
    junctionsWeightDim.filter(null);
    nfilter.remove();
    efilter.remove();
    nfilter.add(n);
    efilter.add(s);    
    addNodeRadius(n);
    update([],[]);
    update(n, s);
    filter(ndegVal, wminVal, jminVal);
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
    filter(ndegVal, wminVal, jminVal);
}

function filterWMin(wmin) {
    wminVal = wmin;
    document.querySelector('#wminlabel').value = wmin;
    filter(ndegVal, wminVal, jminVal);
}

function filterJMin(jmin) {
    jminVal = jmin;
    document.querySelector('#jminlabel').value = jmin;
    filter(ndegVal, wminVal, jminVal);
}

function filter(ndeg, wmin, jmin) {

    var prune = d3.select("#prune1").classed("active");

    if (typeof ndeg == 'undefined') ndeg = ndegVal; //$( "#nsl_slider" ).slider( "value" );
    if (typeof wmin == 'undefined') wmin = wminVal; //$( "#w_slider" ).slider( "value" );
    if (typeof jmin == 'undefined') wmin = jminVal; //$( "#w_slider" ).slider( "value" );

    // Nodes
    nodesDegDim.filter([ndeg, Infinity]);
    var n = nodesDegDim.top(Infinity);
    nodeIds = d3.set(n.map(function(d) { return d.id; }));

    // Links
    edgesWeightDim.filter([wmin, Infinity]);
    junctionsWeightDim.filter([jmin, Infinity]);
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
                return "0.25";
        });
    }

    var optArray = n.map(function(d) { return d.name;} ).sort();
    $(function () {
        $("#search").autocomplete({source: optArray});
    });
 
    document.getElementById('stats-n').innerHTML = n.length;
    document.getElementById('stats-s').innerHTML = d3.sum(e, function(d) { return d.type!="EJ" ? 1 : 0 });
    document.getElementById('stats-ej').innerHTML = d3.sum(e, function(d) { return d.type=="EJ" ? 1 : 0 });
}


function htmlForNode(d){
    var str = 
        "Group: " + d.group + "<br>" +
        "Type: " + d.type + "<br>" +
        "Ganglion: " + d.AYGanglionDesignation + "<br>" +
        "Degrees:" + "<br>&emsp;" + "in " + d.inD + " out " + d.outD + " total " + d.D + "<br>";
    return str;
}

function htmlTabForNode(d){
    var str = '<p><span class="badge stats-item">' + d.type + '</span></p>' +
    '<ul class="list-group">' +
        '<li class="list-group-item"><span class="badge stats-item">' + d.group + '</span>Group</li>' +
        '<li class="list-group-item"><span class="badge stats-item">' + d.AYGanglionDesignation + '</span>Ganglion</li>' +
        '<li class="list-group-item"><span class="badge stats-item">' + d.inD + '</span>In Degree</li>' +
        '<li class="list-group-item"><span class="badge stats-item">' + d.outD + '</span>Out Degree</li>' +
        '<li class="list-group-item"><span class="badge stats-item">' + d.AYNbr + '</span>AYNbr</li>' +
        '<li class="list-group-item"><a href="' + d.link + 
            '"><span class="glyphicon glyphicon-new-window pull-right"></span>In Worm Atlas </a></li>' +
    '</ul>'
    return str;
}

function removePopovers() {
  $('.popover').each(function() {
    $(this).remove();
  }); 
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

function removeNodeInfo() {
    document.getElementById("nodeinfo").innerHTML = "";
    document.getElementById("node-heading").innerHTML = "Node Info";
}

function showNodeInfo(d) {
    document.getElementById("nodeinfo").innerHTML = htmlTabForNode(d);
    document.getElementById("node-heading").innerHTML = d.name;
}


update = function(n, l) {
    nodes = n;
    links = l;

    var c = Math.min(-700 + wminVal * 100, -250);
    var ld = Math.max(120 - wminVal * 10, 40);
    force.nodes(nodes)
        .links(links)
        .charge(c)
        .linkDistance(ld)
        .start();

    // Update links
    link = link.data(force.links(), function(d) { return d.id; });
    link.exit().remove();

    if (arcs)
        var a = link.enter().append("path");
    else
        var a = link.enter().append("polyline");
    
    a.attr("class", "link")
        .classed("junction", function(d) { return (d.type == 'EJ' || d.type == 'NMJ')})
        .classed("hidden", function(d) { return (d.type=='EJ' && !showJunctions) || (d.type!='EJ' && !showSynapses); })
        .style("stroke-width", function(d) { return linkWeightScale(d.weight) * (d.type == 'EJ' ? 2 : 1); })
        .style("stroke", function(d) { return nodeColorScale(d.source.type); })
        .style("opacity", 0.25);

    a.filter(function(d) { return d.type != "EJ"})
        .attr("marker-mid", function(d) { return "url(#" + nodeColorScale(d.source.type) + ")" });
    

    // Update nodes
    node = node.data(force.nodes(), function(d) { return d.id; });
        
    var nodeEnter = node.enter().append("g")
        .attr("class", "node")
        .call(drag)
        //.on('click', connectedNodes);
        .on('dblclick', function(d) { 
            d.fixed = false; 
            d3.select(this).select("circle").classed("fixed", false);
        });

    nodeEnter.append("circle")
        .attr("r", function(d) { return d.r; })
        .style("fill", function(d) { return nodeColorScale(d.type); });

    nodeEnter.append("text")
        .attr("class", "node-label")
        .attr("text-anchor", "middle")
        .attr("dy", "0.35em")
        .text(function(d) { return d.name; });

    nodeEnter.on("mouseover", function(d) {
        //showPopover.call(this, d, 'auto top');
        showNodeInfo(d);        
        connectedNodes(d, this);   
    })

    nodeEnter.on("mouseout", function(d) {
        //removePopovers();
        connectedNodes(null);
    })

    node.exit().remove();

}


tick = function() {
    force.on("tick", function(e) {
        
        // Add layer forces
        var k = 75 * e.alpha;
        nodes.forEach(function(n, i) {
            if (n.type.indexOf("sensory") > -1)// && n.y > 400) 
                n.y -= k;
            else if (n.type.indexOf("motor") > -1)// && n.y < 600) 
                n.y += k;
            if (n.name.slice(-1) == "L")// && n.x > 400)
                n.x -= k
            else if (n.name.slice(-1) == "R")// && n.x < 600)
                n.x += k;
        });
        
        if(arcs) {
            link.attr("d", function(d) {

                // No midpoint
                // var dx = d.target.x - d.source.x,
                //     dy = d.target.y - d.source.y,                    
                //     dr = Math.sqrt(dx * dx + dy * dy),
                //     endx = d.target.x - dx/dr * d.target.r,
                //     endy = d.target.y - dy/dr * d.target.r,
                //     r = d.type=="Sp" ? 0 : d.type=="S" ? 1 : 2; 
                //     return "M" + d.source.x + "," + d.source.y + "A" + r*dr + "," + r*dr + " 0 0,1 " + endx + "," + endy;

                // Midpoint
                // var dx = d.target.x - d.source.x,
                //     dy = d.target.y - d.source.y,
                //     dr = Math.sqrt(dx * dx + dy * dy) / 2,
                //     mx = d.source.x + dx,
                //     my = d.source.y + dy,
                //     r = d.type=="Sp" ? 0 : d.type=="S" ? 1 : 2;
                //     return [
                //         "M", d.source.x, d.source.y,
                //         "A", dr, dr, 0,0,1, mx, my,
                //         "A", dr, dr, 0,0,1, d.target.x, d.target.y
                //     ].join(" ");
                    
                // // Midpoint v2
                var dx = d.target.x - d.source.x,
                    dy = d.target.y - d.source.y,
                    dr = Math.sqrt(dx * dx + dy * dy),
                    mx = (d.target.x + d.source.x) / 2,
                    my = (d.target.y + d.source.y) / 2,
                    len = dr - ((dr/2) * sqrt3),
                    dir = d.type=="S" ? 0 : 2;
                if (d.type=="EJ") {
                    dr = 0;
                }
                else {
                    mx += (dir-1) * dy * len/dr;
                    my += -(dir-1) * dx * len/dr;
                }

                return [
                    "M", d.source.x, d.source.y,
                    "A", dr, dr, 0, 0, dir/2, mx, my,
                    "A", dr, dr, 0, 0, dir/2, d.target.x, d.target.y
                ].join(" ");
            });
        }
        else {
            //Polyline
            link.attr("points", function(d) {
                return d.source.x + "," + d.source.y + " " + 
                 (d.source.x + d.target.x)/2 + "," + (d.source.y + d.target.y)/2 + " " +
                 d.target.x + "," + d.target.y; });
        }

        node.attr("transform", function (d) { return "translate(" + d.x + "," + d.y + ")"; });
        node.each(collide(0.2));
    });
}

function dragstarted(d) {
    d3.event.sourceEvent.stopPropagation();
    d.fixed = true;
    d3.select(this).select("circle").classed("fixed", true);
}

function zoomed() {
  container.attr("transform", "translate(" + d3.event.translate + ")scale(" + d3.event.scale + ")");
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


function connectedNodes(d, elem) {    
    if (d != null && (highlight == 0 || highlightedId != d.id)) {
        //Reduce the opacity of all but the neighbouring nodes
        highlightedId = d.id;
        //d3.select(elem).select("circle").style("stroke", "#000");
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
        //node.select("circle").style("stroke", "#fff");
        link.style("opacity", 0.25);
        highlight = 0;
    }
    d3.event.stopPropagation();
}


function toggleSynapses(checkbox) {
    showSynapses = checkbox.checked;
    link.filter(function(d) { return d.type!="EJ"}).classed("hidden", !showSynapses);
}

function toggleJunctions(checkbox) {
    showJunctions = checkbox.checked;
    link.filter(function(d) { return d.type=="EJ"}).classed("hidden", !showJunctions);
}

function toggleArrows(checkbox) {
    showArrows = checkbox.checked;
    o = showArrows ? "visible" : "hidden";
    svg.selectAll("marker").attr("style", function(d) { return "fill: " + d + "; visibility:" + o +";"});
}

function arcsplease(checkbox) {
    force.stop();
    arcs = checkbox.checked;
    graphReset();
}


function searchNode() {
    var selectedVal = document.getElementById('search-node').value;
    var sel = node.filter(function(d) { return d.name == selectedVal; });
    if(sel[0].length > 0) {
        showNodeInfo(sel.data()[0]);
        connectedNodes(sel.data()[0]);        
    }
    else {
        $('#search-node').addClass("alert-danger");
    }
}


function initNodePos(neurons) {
    neurons.forEach(function(d) { 
        if (d.type.indexOf("sensory") > -1)
            d.y = 0;
        else if (d.type.indexOf("motor") > -1)
            d.y = 600;
        if (d.name.slice(-1) == "L")
            d.x = 200;
        else if (d.name.slice(-1) == "R")
            d.x = 600;

        // Fix AVAL and AVAR to the middle
        //if (d.name="AVAL")
        //d.fixed = true;        
    });
}

function addNodeRadius(neurons) {
   neurons.forEach(function(d) { d.r = nodeRadiusScale(d.D); });
}


function resetSlider(s, v) {
    $('#' + s + ' input').val(v);
    $('#' + s + ' output').val(v);
}


function graphReset() {
    document.getElementById("resetbutton").innerHTML = '<img id="ajaxloader" src="/static/images/ajax-loader.gif">'
    $.getJSON($SCRIPT_ROOT + '/_reset', function(d) {
        data = d.result;
        initNodePos(data.neurons);
        resetSlider("jmin", jminVal=2);
        resetSlider("wmin", wmin=3);
        resetSlider("ndeg", ndegVal=1);
        updateCrossFilter(data['neurons'], data['synapses']);
        document.getElementById("resetbutton").innerHTML = "Reset";
      });
    return false;
}


function subGraph() {
    var g1 = document.getElementById('group1').value;
    var g2 = document.getElementById('group2').value;
    var w = document.getElementById('subwslider').value;
    var l = document.getElementById('subpslider').value;
    var dir = $('#dirButton').text();
    document.getElementById("fetchbutton").innerHTML = '<img id="ajaxloader" src="/static/images/ajax-loader.gif">'
    $.getJSON($SCRIPT_ROOT + '/_subgraph', {
        group1: g1,
        group2: g2,
        minWeight: w,
        maxLength: l,
        dir: dir
      }, function(d) {
        data = d.result;
        resetSlider("jmin", jminVal=0);
        resetSlider("wmin", wmin=0);
        resetSlider("ndeg", ndegVal=0);
        updateCrossFilter(data['neurons'], data['synapses']);
        document.getElementById("fetchbutton").innerHTML = "Fetch!"
      });
      return false;
}

	