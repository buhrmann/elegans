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
var highlightId = -1;
var showArrow = 0,
    showJunctions = 1,
    showSynapses = 1;
var fetched = false;

var arcs = false;
var sqrt3 = 1.7320508075688772;

var presets = [
    {name: "Salt klinotaxis S", g1:"ASE", g2:"SMB", smin: 2, jmin: 2, length:3},
    {name: "Salt klinotaxis L", g1:"ASE", g2:"SMB", smin: 1, jmin: 1, length:3},
    // Piggot thesis, p. 89 A
    {name: "Isothermal tracking", g1:"AFD,AWC", g2:"VB, DB, RMD, RIM, SMD, VA, DA, DD", smin: 1, jmin: 1, length:2},
    // Piggot thesis, p. 35 A 
    {name: "Backward escape", g1:"ASH", g2:"VB, DB, RMD, RIM, SMD, VA, DA, DD", smin: 1, jmin: 1, length:2}
]


//-------------------------------------------------------------------
// Little helpers
//-------------------------------------------------------------------
function split(val) {
    return val.split( /,\s*/ );
}

function extractLast( term ) {
    return split(term).pop();
}

//-------------------------------------------------------------------
// Group input autocomplete (multiple)
// https://jqueryui.com/autocomplete/#multiple
//-------------------------------------------------------------------
function group_auto(data) {
   
    var groups = d3.set(data.neurons.map(function(d) { return d.group;} ).sort()).values();
    $(function () {
        $("#group1, #group2")
        .bind("keydown", function(event) {
            if (event.keyCode === $.ui.keyCode.TAB && $(this).autocomplete( "instance" ).menu.active) {
              event.preventDefault();
            }
        })
        .autocomplete({
            minLength: 0,
            source: function( request, response ) {
                // delegate back to autocomplete, but extract the last term
                response($.ui.autocomplete.filter(groups, extractLast(request.term)));
            },
            focus: function() { return false; }, // prevent value inserted on focus
            select: function( event, ui ) {
                var terms = split( this.value );                
                terms.pop();    // remove the current input                
                terms.push( ui.item.value ); // add the selected item                
                terms.push( "" );   // add placeholder to get the comma-and-space at the end
                this.value = terms.join( ", " );
                return false;
            }
        });
    });

    var names = d3.set(data.neurons.map(function(d) { return d.name;} ).sort()).values();
    $(function () {
        $("#search-node").autocomplete({source: names});
    });

    var modalities = data.neurons
        .filter(function(x) { return "modalities" in x; })
        .map(function(d) { return d.modalities.split(", "); });
    modalities = [].concat.apply([], modalities).sort(); // flatten array
    modalities = d3.set(modalities).values();
    $(function () {
        $("#rec-sel")
        .bind("keydown", function(event) {
            if (event.keyCode === $.ui.keyCode.TAB && $(this).autocomplete( "instance" ).menu.active) {
              event.preventDefault();
            }
        })
        .autocomplete({
            minLength: 0,
            source: function( request, response ) {
                response($.ui.autocomplete.filter(modalities, extractLast(request.term)));
            },
            focus: function() { return false; }, // prevent value inserted on focus
            select: function( event, ui ) {
                var terms = split( this.value );                
                terms.pop();    // remove the current input                
                terms.push( ui.item.value ); // add the selected item                
                terms.push( "" );   // add placeholder to get the comma-and-space at the end
                this.value = terms.join( ", " );
                return false;
            }            
        });
    });
}


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
    col_sensory = "#ED008C"
    col_motor = "#F5892D"
    col_inter = "#00ADEF"
    col_sensmot = d3.rgb(d3.interpolateRgb(col_sensory, col_motor)(0.5)).brighter(2).toString();
    col_sensint = d3.rgb(d3.interpolateRgb(col_sensory, col_inter)(0.5)).brighter(2).toString();
    col_intmot = d3.rgb(d3.interpolateRgb(col_inter, col_motor)(0.5)).brighter(1).toString();
    colors = [col_inter, col_sensory, col_motor, col_intmot, col_sensint, col_sensmot, "#bbb"];
    nodeColorScale = d3.scale.ordinal().range(colors);
    
    var degreeDomain = d3.extent(data.neurons, function(n) { return n.D; });
    nodeRadiusScale = d3.scale.linear().domain(degreeDomain).range([10,25]);

    var weightDomain = d3.extent(data.synapses, function(s) { return s.weight; });
    linkWeightScale = d3.scale.linear().domain(weightDomain).range([2,6]);

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

    drag = force.drag().on("dragstart", dragstarted).on("drag", dragged);
    zoom = d3.behavior.zoom().scaleExtent([0.75, 2]).on("zoom", zoomed); 
    svg.call(zoom).on("dblclick.zoom", null);

    node = nodeLayer.selectAll(".node");
    link = linkLayer.selectAll(".link");  

    svg.on("click", function() {
        toggleSelected(highlightId, false);
        connectedNodes(null);
        highlightId = -1;
        removeNodeInfo();
        d3.event.stopPropagation();
    });  

    // Crossfilter
    nfilter.add(data['neurons']);
    efilter.add(data['synapses']);
    nodesDegDim = nfilter.dimension(function(d) { return d.D; });
    edgesWeightDim = efilter.dimension(function(d) { return d.type != "EJ" ? d.weight : 6666; });
    junctionsWeightDim = efilter.dimension(function(d) { return d.type == "EJ" ? d.weight : 6666; });

    // Set up auto-complete for group inputs
    group_auto(data);

    update(data.neurons, data.synapses);
    filter(ndegVal, wminVal, jminVal);
    
    // Warm-start
    for (i = 0; i < 10; i++)
        force.tick();
    
    buildAdjacency();
    buildPresets();
}

function updateCrossFilter(n, s) {
    nodesDegDim.filter(null);
    edgesWeightDim.filter(null);
    junctionsWeightDim.filter(null);
    nfilter.remove();
    efilter.remove();
    nfilter.add(n);
    efilter.add(s);  
    initNodePos(n);  
    addNodeRadius(n);
    update([],[]);
    update(n, s);
    filter(ndegVal, wminVal, jminVal);

    // Warm-start
    for (i = 0; i < 10; i++)
        force.tick();
}


function buildPresets() {
    for (var i = 0; i < presets.length; i++) {
        d3.select("#presetList")
            .append("li")
                .attr("role", "presentation")
                .append("a")
                    .attr("href", "#")
                    .attr("id", i)
                    .attr("role", "menuitem")
                    .attr("tabindex", "-1")
                    .text(presets[i]['name']);
    };
}

function applyPreset(id) {
    p = presets[id];
    $("#group1").val(p.g1);
    $("#group2").val(p.g2);
    setSlider("subw", p.smin);
    setSlider("subj", p.jmin);
    setSlider("subp", p.length);
}


function buildAdjacency() {
    linked = {}
    nodes.forEach(function (d) { linked[d.id + "," + d.id] = true; });
    links.forEach(function (d) { linked[d.from + "," + d.to] = true; });
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
 

    var num_neurons = d3.sum(n, function(d) { return d.type!="muscle" ? 1 : 0 });
    document.getElementById('stats-n').innerHTML = num_neurons;
    document.getElementById('stats-m').innerHTML = n.length - num_neurons;
    document.getElementById('stats-s').innerHTML = d3.sum(e, function(d) { return d.type=="S" || d.type=="Sp" ? 1 : 0 });
    document.getElementById('stats-ej').innerHTML = d3.sum(e, function(d) { return d.type=="EJ" ? 1 : 0 });
    document.getElementById('stats-nmj').innerHTML = d3.sum(e, function(d) { return d.type=="NMJ" ? 1 : 0 });
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
    var str = '<p><span class="badge stats-item">' + d.type + '</span>'
    
    var mods = null;
    if ("modalities" in d) {
        mods = d.modalities.split(", ");
        for (var i = mods.length - 1; i >= 0; i--) {
            str += '<span class="badge badge-sm stats-item">' + mods[i] + '</span>';
        };
    }
    str += '</p>'

    if ("functions" in d && d.functions != '') {
        str +=  '<p><b>Functions</b>: ' + d.functions + '</p>';
    }

    str += '<ul class="list-group">'
    if (d.type == 'muscle') {
        str +=
            '<li class="list-group-item"><span class="badge stats-item">' + d.part + '</span>Location</li>' +
            '<li class="list-group-item"><span class="badge stats-item">' + d.inD + '</span>In Degree</li>';    
    }
    else {
        str +=
            '<li class="list-group-item"><span class="badge stats-item">' + d.group + '</span>Group</li>' +
            '<li class="list-group-item"><span class="badge stats-item">' + d.AYGanglionDesignation + '</span>Ganglion</li>' +
            '<li class="list-group-item"><span class="badge stats-item">' + d.inD + '</span>In Degree</li>' +
            '<li class="list-group-item"><span class="badge stats-item">' + d.outD + '</span>Out Degree</li>' +
            '<li class="list-group-item"><span class="badge stats-item">' + d.AYNbr + '</span>AYNbr</li>' +
            (mods ? ('<li class="list-group-item"><span class="badge stats-item">' + d.organ + '</span>Organ</li>') : '') +
            '<li class="list-group-item"><a target="_blank" href="' + d.link + 
                '"><span class="glyphicon glyphicon-new-window pull-right"></span>In Worm Atlas </a></li>' +
            '<li class="list-group-item"><a target="_blank" href="http://wormweb.org/neuralnet#c=' + d.group +  
                '&m=1"><span class="glyphicon glyphicon-new-window pull-right"></span>In Worm Web </a></li>';
    }
    str += '</ul>'
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
    document.getElementById("nodeinfo").innerHTML = "Click to select...";
    document.getElementById("node-heading").innerHTML = "Node Info";
}

function showNodeInfo(d) {
    //console.log(htmlTabForNode(d));
    document.getElementById("nodeinfo").innerHTML = htmlTabForNode(d);
    document.getElementById("node-heading").innerHTML = d.name;
}


update = function(n, l) {
    nodes = n;
    links = l;
    buildAdjacency();

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
    
    var a = link.enter().append("path");
    a.attr("class", "link")
        .classed("junction", function(d) { return (d.type == 'EJ' || d.type == 'NMJ')})
        .classed("hidden", function(d) { return (d.type=='EJ' && !showJunctions) || (d.type!='EJ' && !showSynapses); })
        .style("stroke-width", function(d) { return linkWeightScale(d.weight); })
        .style("stroke", function(d) { return nodeColorScale(d.source.type); })
        .style("opacity", 0.25)
        .attr("id", function(d) { return d.id; })
        .on("mouseover", linkMouseOver)
        .on("mouseout", linkMouseOut);

    a.filter(function(d) { return d.type == "S" || d.type == "Sp"})
        .attr("marker-mid", function(d) { return "url(#" + nodeColorScale(d.source.type) + ")" });

    // Update nodes
    node = node.data(force.nodes(), function(d) { return d.id; });
        
    var nodeEnter = node.enter().append("g")
        .attr("class", "node")
        .on('click', function(d) { 
            if (d3.event.defaultPrevented) return;
            clicker(d, this);            
            d3.event.stopPropagation();
        })
        .call(drag);

    nodeEnter.append("circle")
        .attr("r", function(d) { return d.r; })
        .style("fill", function(d) { return nodeColorScale(d.type); });

    nodeEnter.append("text")
        .attr("class", "node-label")
        .attr("text-anchor", "middle")
        .attr("dy", "0.35em")
        .text(function(d) { return d.name; });

    nodeEnter.on("mouseover", function(d) {
        connectedNodes(d);
    });

    nodeEnter.on("mouseout", function(d) {
        connectedNodes(null);
    });

    node.exit().remove();

}

updateLinks = function(l) {
    
    links = l;
    force.links(links).start();
    
    link = link.data(force.links(), function(d) { return d.id; });
    link.exit().remove();
    
    var a = link.enter().append("path");
    a.attr("class", "link")
        .classed("junction", function(d) { return (d.type == 'EJ' || d.type == 'NMJ')})
        .classed("hidden", function(d) { return (d.type=='EJ' && !showJunctions) || (d.type!='EJ' && !showSynapses); })
        .style("stroke-width", function(d) { return linkWeightScale(d.weight); })
        .style("stroke", function(d) { return nodeColorScale(d.source.type); })
        .style("opacity", 0.25)
        .attr("id", function(d) { return d.id; })
        .on("mouseover", linkMouseOver)
        .on("mouseout", linkMouseOut);

    a.filter(function(d) { return d.type != "EJ"})
        .attr("marker-mid", function(d) { return "url(#" + nodeColorScale(d.source.type) + ")" });
}


tick = function() {
    force.on("tick", function(e) {
        
        // Add layer forces
        var k = 75 * e.alpha;
        nodes.forEach(function(n, i) {
            if(! n.fixed) {
                if (n.type.indexOf("muscle") > -1)// && n.y > 400) 
                    n.y += 2*k;
                else if (n.type.indexOf("sensory") > -1)// && n.y > 400) 
                    n.y -= k;
                else if (n.type.indexOf("motor") > -1)// && n.y < 600) 
                    n.y += k;
                if (n.name.slice(-1) == "L")// && n.x > 400)
                    n.x -= k
                else if (n.name.slice(-1) == "R")// && n.x < 600)
                    n.x += k;
            }
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
            link.attr("d", function(d) {
                return [
                    "M", d.source.x, d.source.y,
                    "L", (d.source.x + d.target.x)/2, (d.source.y + d.target.y)/2,
                    "L", d.target.x, d.target.y
                ].join(" ");
            });
        }
        node.attr("transform", function (d) { return "translate(" + d.x + "," + d.y + ")"; });
        node.each(collide(0.2));
    });
}

dblclick_timer = false;
function clicker(d, elem) {
    if (dblclick_timer) {
        clearTimeout(dblclick_timer);
        dblclick_timer = false;
        nodeDblClicked(d, elem);
    }
    else dblclick_timer = setTimeout( function() {
        dblclick_timer = false;
        nodeClicked(d);
    }, 200);
};

function nodeClicked(d) {
    // Mark selected node      
    if (highlightId != d.id) {
        showNodeInfo(d); 
        toggleSelected(highlightId, false);
        highlightId = d.id;
        toggleSelected(highlightId, true);
    }
    else
    {
        removeNodeInfo();
        toggleSelected(highlightId, false);
        highlightId = -1;
    }
}

function nodeDblClicked(d, elem) {
    d.fixed = false; 
    d3.select(elem).select("circle").classed("fixed", false);
}

function dragstarted(d) {
     d3.event.sourceEvent.stopPropagation();
}

function dragged(d) {
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


function toggleSelected(i, b) {
    node.filter(function(n) { return n.id == i; })
        .select("circle").classed("selected", b);
}


function connectedNodes(d) {
    if (d != null) {
        //Reduce the opacity of all but the neighbouring nodes
        node.style("opacity", function (o) {
            return neighboring(d, o) | neighboring(o, d) ? 1 : 0.1;
        });
        link.style("opacity", function (o) {
            return d.id==o.from | d.id==o.to ? 1 : 0.05;
        });
    } else {     
        node.style("opacity", 1);
        link.style("opacity", 0.25);
    }
}


function linkMouseOver(d) {
    //link.classed("active", function(p) { return p==d});
    d3.select(this)
        .style("opacity", 1);

    container.append("text")
        .attr("class","labelText")
        .style("font-size", "11px")
        .style("fill", nodeColorScale(d.source.type))
        .attr("x", "50")
        .attr("y", "-20")
        .attr("dy", "-0.2em")
        .attr("text-anchor", "start")
        .append("textPath")
            .attr("xlink:href", '#' + d.id)
            .text(d.type + " " + d.weight); 
}

function linkMouseOut(d) {
    d3.select(this)
        .style("opacity", 0.25);
    container.selectAll(".labelText").remove();
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
    l=links;
    updateLinks([]);
    updateLinks(l);
}


function searchNode() {
    var selectedVal = document.getElementById('search-node').value;
    var sel = node.filter(function(d) { return d.name == selectedVal; });
    if(sel[0].length > 0) {
        //showNodeInfo(sel.data()[0]);
        nodeClicked(sel.data()[0]);
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
        else if (d.type.indexOf("inter") > -1)
            d.y = height/2;
        else if (d.type.indexOf("motor") > -1)
            d.y = 3*height/4;
        else if (d.type.indexOf("muscle") > -1)
            d.y = height;

        if (d.name.slice(-2,-1) == "L")
            d.x = 0.25 * width;
        else if (d.name.slice(-1) == "R")
            d.x = 0.75 * width;

        // Fix AVAL and AVAR to the middle
        //if (d.name="AVAL")
        //d.fixed = true;        
    });
}

function addNodeRadius(neurons) {
   neurons.forEach(function(d) { d.r = nodeRadiusScale(d.D); });
}


function setSlider(s, v) {
    $('#' + s + ' input').val(v);
    $('#' + s + ' output').val(v);
}


function graphReset() {
    document.getElementById("resetbutton").innerHTML = '<img id="ajaxloader" src="/static/images/ajax-loader.gif">'
    $.getJSON($SCRIPT_ROOT + '/_reset', function(d) {
        data = d.result;
        initNodePos(data.neurons);
        setSlider("jmin", jminVal=2);
        setSlider("wmin", wminVal=3);
        setSlider("ndeg", ndegVal=1);
        updateCrossFilter(data['neurons'], data['synapses']);
        document.getElementById("resetbutton").innerHTML = "Reset";
      });
    fetched = false;
    //$('#expandbutton').prop('disabled', true);
    $('#expandbutton').toggleClass('disabled', true);
    return false;
}


function expand() {
    if (fetched) {
        var name_list = nodes.map(function(d) { return d.name; });
        var muscles = ($('#mhead-check').prop('checked') ? "head," : "") +
                  ($('#mneck-check').prop('checked') ? "neck," : "") +
                  ($('#mbody-check').prop('checked') ? "body" : "");
    
        document.getElementById("expandbutton").innerHTML = '<img id="ajaxloader" src="/static/images/ajax-loader.gif">'
        $.getJSON($SCRIPT_ROOT + '/_expand', {
            names: name_list,
            muscles: muscles
          }, function(d) {
            data = d.result;
            setSlider("jmin", jminVal=0);
            setSlider("wmin", wminVal=0);
            setSlider("ndeg", ndegVal=0);
            updateCrossFilter(data['neurons'], data['synapses']);
            document.getElementById("expandbutton").innerHTML = "Expand"
          });
    }
    return false;
}


function subGraph() {
    var g1 = document.getElementById('group1').value;
    var g2 = document.getElementById('group2').value;
    var rec = document.getElementById('rec-sel').value;
    var ws = document.getElementById('subwslider').value;
    var wj = document.getElementById('subjslider').value;
    var l = document.getElementById('subpslider').value;
    var dir = $('#dirButton').text();
    dir = dir == "↓" ? "uni" : "bi";
    var muscles = ($('#mhead-check').prop('checked') ? "head," : "") +
                  ($('#mneck-check').prop('checked') ? "neck," : "") +
                  ($('#mbody-check').prop('checked') ? "body" : "");
    
    document.getElementById("fetchbutton").innerHTML = '<img id="ajaxloader" src="/static/images/ajax-loader.gif">'
    $.getJSON($SCRIPT_ROOT + '/_subgraph', {
        group1: g1,
        group2: g2,
        receptors: rec,
        minWeightS: ws,
        minWeightJ: wj,
        maxLength: l,
        dir: dir,
        muscles: muscles
      }, function(d) {
        data = d.result;
        jmin = wmin = ndeg = 0;
        setSlider("jmin", jminVal=0);
        setSlider("wmin", wminVal=0);
        setSlider("ndeg", ndegVal=0);
        updateCrossFilter(data['neurons'], data['synapses']);
        document.getElementById("fetchbutton").innerHTML = "Fetch"
        $('#expandbutton').toggleClass('disabled', false);
        fetched = true;
      });
      return false;
}


function exportSvg() {
    var ctn = document.getElementById("graph");
    var svg = ctn.getElementsByTagName("svg")[0];
    var serializer = new XMLSerializer();
    var source = serializer.serializeToString(svg);
    //var style = "<?xml-stylesheet href='/static/css/d3.css' type='text/css'?>"
    return source;
}

function downloadPng() {
    // From https://github.com/exupero/saveSvgAsPng
    var ctn = document.getElementById("graph");
    var svg = ctn.getElementsByTagName("svg")[0];
    saveSvgAsPng(svg, "graph.png");
}

