
    // Size definitions for the shapes
    var rect_size = 30,
        rect_highlighted = 40,
        radius = rect_size / 2;
        radius_highlighted = (rect_size / 1.2);
    
    // Definitions of each of the shapes represented in the force layout.
    // Each new shape must be defined here

    var shapes = {
        rect : {
            d: "M " + -rect_size + " " + (-rect_size / 4) + " h " + 2 * rect_size + " v " + (rect_size / 2) + " h "+ (-2 * rect_size) + " z",
            
            anchors:{"N" : {x:0, y:(-rect_size/4)},
                     "E" : {x:rect_size, y:0},
                     "S" : {x:0, y:(rect_size/4)},
                     "W" : {x:-rect_size, y:0},
                     "NE" : {x:rect_size, y:-rect_size/4},
                     "SE" : {x:rect_size, y:rect_size/4},
                     "SW" : {x:-rect_size, y:rect_size/4},
                     "NW" : {x:-rect_size, y:-rect_size/4}}
        },
        
        rect_highlighted : {
            d: "M " + -rect_highlighted + " " + (-rect_highlighted / 4) + " h " + 2 * rect_highlighted + " v " + (rect_highlighted / 2) + " h "+ (-2 * rect_highlighted) + " z",
            anchors : {"N" : {x:0, y:(-rect_highlighted/4)},
                     "E" : {x:rect_highlighted, y:0},
                     "S" : {x:0, y:(rect_highlighted/4)},
                     "W" : {x:-rect_highlighted, y:0},
                     "NE" : {x:rect_highlighted, y:-rect_highlighted/4},
                     "SE" : {x:rect_highlighted, y:rect_highlighted/4},
                     "SW" : {x:-rect_highlighted, y:rect_highlighted/4},
                     "NW" : {x:-rect_highlighted, y:-rect_highlighted/4}}
        },
        
        vertical_rect : {
            d: "M " + (-rect_size / 4) + " " + -rect_size + " h " + (rect_size / 2) + " v " + 2 * rect_size + " h "      + (-rect_size / 2) + " z",
            anchors : {"N" : {x:0, y:(-rect_size/4)},
                     "E" : {x:rect_size, y:0},
                     "S" : {x:0, y:(rect_size/4)},
                     "W" : {x:-rect_size, y:0},
                     "NE" : {x:rect_size, y:-rect_size/4},
                     "SE" : {x:rect_size, y:rect_size/4},
                     "SW" : {x:-rect_size, y:rect_size/4},
                     "NW" : {x:-rect_size, y:-rect_size/4}}
        },
        
        circle : {
            d: "M 0 0 m" + (-radius) +", 0 a " + radius + "," + radius + " 0 1,0 " + (radius * 2) +",0 " 
                        + "a " + radius + "," + radius + " 0 1,0 " + (-radius * 2) + ",0",
            anchors : {"N" :    {x:Math.cos(Math.PI/2)*radius,      y:-Math.sin(Math.PI/2)*radius},
                     "E" :       {x:Math.cos(0)*radius,              y:Math.sin(0)*radius},
                     "S" :      {x:Math.cos(3/2*Math.PI)*radius,    y:-Math.sin(3/2*Math.PI)*radius},
                     "W" :       {x:Math.cos(Math.PI)*radius,        y:Math.sin(Math.PI)*radius},
                     "NE" :  {x:Math.cos(Math.PI/4)*radius,      y:-Math.sin(Math.PI/4)*radius},
                     "SE" :  {x:Math.cos(7/4*Math.PI)*radius,    y:-Math.sin(7/4*Math.PI)*radius},
                     "SW" :  {x:Math.cos(5/4*Math.PI)*radius,    y:-Math.sin(5/4*Math.PI)*radius},
                     "NW" :  {x:Math.cos(3/4*Math.PI)*radius,    y:-Math.sin(3/4*Math.PI)*radius}}
        },
        
        circle_highlighted : {
            d: "M 0 0 m" + (-radius_highlighted) +", 0 a " + radius_highlighted + "," + radius_highlighted + " 0 1,0 " + (radius_highlighted * 2) +",0 " + "a " + radius_highlighted + "," + radius_highlighted + " 0 1,0 " + (-radius_highlighted * 2) + ",0",
            anchors : {"N" : {x:Math.cos(Math.PI/2)*radius_highlighted,  y:-Math.sin(Math.PI/2)*radius_highlighted},
                     "E" : {x:Math.cos(0)*radius_highlighted,         y:Math.sin(0)*radius_highlighted},
                     "S" : {x:Math.cos(3/2*Math.PI)*radius_highlighted,y:-Math.sin(3/2*Math.PI)*radius_highlighted},
                     "W" : {x:Math.cos(Math.PI)*radius_highlighted,   y:Math.sin(Math.PI)*radius_highlighted},
                     "NE" :{x:Math.cos(Math.PI/4)*radius_highlighted,     y:-Math.sin(Math.PI/4)*radius_highlighted},
                     "SE" :{x:Math.cos(7/4*Math.PI)*radius_highlighted,   y:-Math.sin(7/4*Math.PI)*radius_highlighted},
                     "SW" :{x:Math.cos(5/4*Math.PI)*radius_highlighted,   y:-Math.sin(5/4*Math.PI)*radius_highlighted},
                     "NW" :{x:Math.cos(3/4*Math.PI)*radius_highlighted,   y:-Math.sin(3/4*Math.PI)*radius_highlighted}}
            
        },
    };

    // Position definitions and points of reference for the markers
    var width = 960,
        height = 500,
        markerWidth = 8,
        markerHeight = 8,
        origin = {x: width/2, y: height/2},
        fill = d3.scale.category20();
        
    var outer = d3.select("#model_container").append("svg:svg")
            .attr("width", width)
            .attr("height", height)
            .attr("pointer-events", "all");
            
    var svg = outer.append("svg:g")
                .call(d3.behavior.zoom()
                        .on("zoom", rescale)
                        .on("zoomstart", zoomStart)
                        .on("zoomend", zoomEnd))
                .on("dblclick.zoom", null)
                .append("svg:g")
                .on("mousedown", mouseDown)
                .on("mouseup", mouseUp)
                .on("contextmenu", function(data, index) { d3.event.preventDefault(); });    

    // Background color
    svg.append('svg:rect')
        .attr('width', width)
        .attr('height', height)
        .attr('fill', 'white');
    
    d3.select("#model_container").append("div")
        .attr("id", "forms_group")
        .attr("class", "span5");
    
            
    // The force layout from D3 is the graphical representation of the
    // model. Set gravity in 0 so that the nodes dont move in the graph and linkDistance 
    // in 300 to adjust any node without inicial position
    
    var force = d3.layout.force()
        .size([width, height])
        .nodes([])
        .links([])
        //~ .charge(5)
        //~ .linkDistance(100)
        .on("tick", tick);
    
    // Per-type markers, as they don't inherit styles.
    svg.append("svg:defs").selectAll("marker")
        .data(["suit", "licensing", "resolved"])
        .enter().append("svg:marker")
        .attr("id", String)
        .attr("viewBox", "0 -5 10 10")
        .attr("refX", markerWidth +2)
        .attr("markerWidth", markerWidth)
        .attr("markerHeight", markerHeight)
        .attr("orient", "auto")
        .append("svg:path")
        .attr("d", "M0,-5L10,0L0,5");
        
    var dragInitiated;
    var nodeDrag = d3.behavior.drag()
        .on("dragstart", function(d, i) {
            console.log(d3.event.sourceEvent.which);
            if(d3.event.sourceEvent.which == 3){
                dragInitiated = true
                force.stop();
            }
        })
        .on("drag", function(d, i) {
            if (dragInitiated){
                d.px += d3.event.dx;
                d.py += d3.event.dy;
                d.x += d3.event.dx;
                d.y += d3.event.dy;
                tick();
            }
        })
        .on("dragend", function(d, i){ 
            if (d3.event.sourceEvent.which == 3){
                force.resume()                     
                d.fixed = true
                tick()
                dragInitiated = false
            }
        });

    // Definitions of all the elements from the force layot.
    // the circle represents a token for each node. 
    var path = svg.append("svg:g").selectAll("path").attr("id", "paths"),
        node = svg.append("svg:g").selectAll("node").attr("id", "nodes"),
        circle = svg.append("svg:g").selectAll("g").attr("id", "tokens"),
        text = svg.append("svg:g").selectAll("g").attr("id", "dummy_labels");
        
    var nodes_index = {},
        links_index = {}.
        forms_index = {};

    // Add new node from the model 
    function add_node(node){
        updateModelNode(node);
    }
    
    // Update a previous existing node in the model
    function update_node (node) {
        updateModelNode(node);
    }
    
    function updateModelNode (node) {
        if(node.get("type") == "arc"){
            var source = node.get('source'),
                target = node.get('target'),
                valuation = node.get('validation'),
                anchor = node.get("anchor") ?  node.get("anchor") : '',
                lock_pos = node.get("lock_pos") ?  node.get("lock_pos") : false;
            
            source = force.nodes()[nodes_index[id(source)]];
            target = force.nodes()[nodes_index[id(target)]];
            
            if(!source || !target) return;
            
            if(undefined == links_index[id(node)]){
                force.links().push({id : id(node), 
                                    anchor:anchor,
                                    source: source,
                                    target: target,
                                    type: "licensing",
                                    lock_pos : lock_pos});
                                    
                links_index[id(node)] = force.links().length - 1;
            } else {
                var i = links_index[id(node)];
                force.links()[i].source = source;            
                force.links()[i].target = target;
                force.links()[i].anchor = anchor;
                force.links()[i].lock_pos = lock_pos;
            }
        } else if("place" == node.get("type") || "transition" == node.get("type")){
            
            if(node.get('name') == undefined) return;
            
            marking = node.get('marking') ? node.get('marking') : '';
            highlighted = node.get('highlighted') ? node.get('highlighted') : '';
            selected = node.get('selected') ? node.get('selected') : '';
            name = node.get('name');
            isTransition = node.get("type") == "transition";
            
            if(highlighted)
                shape = isTransition? shapes.rect_highlighted : shapes.circle_highlighted;
            else
                shape = isTransition? shapes.rect : shapes.circle;
            
            var s = node.get("position"),
                is_polar = s.indexOf(",") == -1,
                x_pos, y_pos, p;
                
            if(is_polar)
                p = s.indexOf(":")
            else
                p = s.indexOf(",")
            
            
            var offset_x = is_polar ? Math.cos(s.substring(0, p)*(180/Math.PI)) * s.substring(p+1) : s.substring(0, p)
            var offset_y = is_polar ? Math.sin(s.substring(0, p)*(180/Math.PI)) * s.substring(p+1) : s.substring(p+1)
            
            var x_pos = parseFloat(origin.x) + parseFloat(offset_x);
            var y_pos = parseFloat(origin.y) - parseFloat(offset_y);
            elem = {id : id(node),
                    name : name,
                    type : node.get("type"), 
                    shape : shape,
                    marking : marking ? true : false,
                    px : x_pos,
                    py : y_pos,
                    highlighted : highlighted,
                    selected : selected,
                    lua_node :node};
            if(undefined == nodes_index[id(node)]){
                elem.fixed = true;
                force.nodes().push(elem);
                nodes_index[id(node)] = force.nodes().length - 1;
            } else {
                i = nodes_index[id(node)];
                force.nodes()[i].id = elem.id;
                force.nodes()[i].name = elem.name;
                force.nodes()[i].type = elem.type;
                force.nodes()[i].shape = elem.shape;
                force.nodes()[i].marking = elem.marking;
                force.nodes()[i].px = elem.px;
                force.nodes()[i].py = elem.py;
                force.nodes()[i].highlighted = elem.highlighted;
                force.nodes()[i].selected = elem.selected;
                force.nodes()[i].lua_node = elem.lua_node;
            }
        } else if("form" == node.get("type")){
            var unsorted_forms = elements(node);
            var form_elems = [];
            for(j = 1; j <= count(unsorted_forms); j++){
                form_elems.push(unsorted_forms.get(j));
            }
            form_elems.sort(function sortForms(x, y) {
                if("text" == x.get("type"))
                    return -1;
                if(y_value = "text" == y.get("type"))
                    return 1;
                return 0;
            });
            
            var selection = d3.select("#forms_group");
            var data = selection.data();
            data[id(node)] = node;
            selection = selection.data(data, function(d) { return id(node)});
            
            selection.enter().append("div")
                    .attr("id", id(node))
                    .attr("class", "lua_form");
            
            for(j = 0; j < count(form_elems); j++){
                form = form_elems[j];
                sub_id = id(form);
                if("text" == form.get("type")){
                    selection.append("h4")
                        .attr("id", sub_id+"_h4")
                        .text(form.get("name"));
                    selection.append("input").data([form])
                        .attr("id", sub_id+"_text")
                        .attr("type", "text")
                        .attr("size", 9)
                        .on("change", formTextChange)
                        .attr("value", form.get("value"));
                } else if("button" == form.get("type")) {
                    btn = selection.append("button").data([form]);
                    btn.attr("type", "button")
                        .attr("id", sub_id)
                        .attr("class", "btn btn-success")
                        .attr("data-toggle", "button")
                        .on("click", formBtnClick)
                        .text(form.get("name"));
                    if(!form.get("is_active")){
                        btn.attr("disabled", "true")
                    }
                }
            }
        }
        updateForceLayout();
    }

    // A node has been removed from the model, so it needs to be deleted
    // in the layout
    function remove_node (node) {
        var index_object, list;
        
        if(node.get("type") == "arc"){
            index_object = links_index;
            list = force.links();
        } else if(node.get("type") == "place" || node.get("type") == "transition"){
            index_object = nodes_index;
            list = force.nodes();
        }

        list.splice(index_object[id(node)], 1)
        
        delete index_object[id(node)];
        updateForceLayout();
    }
    
    function websocket (url) {
        console.log ("new websocket: " + url);
        return new WebSocket (url, "cosy");
    }
    
    function add_patch (str) {
    }
    
    // GUI update
    function updateForceLayout() {
        path = path.data(force.links(), function(d){return d.id});
        
        path.enter().insert("svg:path", ".node");
        path.attr("class", function (d) {return "link " + d.type;})
            .attr("marker-end", function (d) {return "url(#" + d.type + ")";});
        path.exit().remove();
        
        node = node.data(force.nodes(), function (d) {return d.id});
        node.enter().append("path");
        node.attr("class", "node")
            .attr("d", function(d){ return d.shape.d;})
            .attr("fill", function(d){ return d.highlighted ? "gold" : "#ccc"})
            .on('mousedown', node_mouseDown)
            .on("click", node_click)
            .on("dblclick", node_dblclick)
            .call(nodeDrag);
        node.exit().remove();
        
        circle = circle.data(force.nodes(), function (d) {return d.id;});
        circle.enter().append("circle")
                .attr("class", "token")
                .attr("r", radius/6)
                .attr("fill", "black")
                .call(nodeDrag);
                                
        circle.attr("visibility", function(d) {return d.marking ? "visible" : "hidden" })
        
        circle.exit().remove();

        text = text.data(force.nodes(), function (d) {return d.id;});
        text.enter().append("text")
            .attr("x", function(d){ return d.type == 'transition' ? 45 : 30})
            .attr("y", ".45em")
            .attr("size", 10)
            .call(nodeDrag);
            
        text.text(function(d) { return d.name; });
        text.exit().remove();
        
        force.start();
        
        return true;
    }
    
    // Zoom and rescale event handling
    function rescale() {
        svg.attr("transform", "translate(" + d3.event.translate + ")"+ " scale(" + d3.event.scale + ")");
    }
    
    function zoomStart(){
        //~ console.log("ZOOM START");
    }
    
    function zoomEnd(){
        //~ console.log("ZOOM END");
    }
    
    // Mouse event handling
    
    function mouseDown(event) {
        //~ console.log("Mouse Down code: " + d3.event.button);
        switch(d3.event.button){
            case 1:
                return;
            default:
                /*If is not the middle button, we stop the panning event*/
                d3.event.stopPropagation();
        }
    }

    function mouseUp(event) {
        //~ console.log("Code: " + d3.event.button);
    }
    
    // Force nodes event handling
    function node_dblclick(d) {
        d.lua_node.set("selected", false);
        d3.select(this).classed("selected", d.selected = false);
    }
    
    function node_click(d){
        if (d3.event.defaultPrevented) return;
        
        d.lua_node.set("selected", true);
        d3.select(this).classed("selected", d.selected = true);
    }
    
    function node_mouseDown(d){
        //~ console.log("Node_mouse down event: " + d3.event.button)
        //~ 
        //~ d3.event.stopPropagation();
        //~ d3.select(this).on("mousedown.drag", null);
        //~ switch(d3.event.button){
            //~ case 2:
                //~ d3.select(this).on("mousedown.drag", force.drag);
        //~ }
    }

    // Other events
    function formTextChange(d){
        d.set("value", this.value);
    }
    
    function formBtnClick(d){
        d.set("clicked", true);
    }
    
    function tick() {
        var duration = 50;
        path.transition().duration(duration).attr("d", function (d) {
            var offset;
            
            var anchor_list = d.target.type == "place" ? (d.target.highlighted ? shapes.circle_highlighted.anchors : shapes.circle.anchors) : (d.target.highlighted ? shapes.rect_highlighted.anchors : shapes.rect.anchors),
                min = Number.MAX_VALUE, dist;
                    
            if(!d.lock_pos || '' == d.anchor) {
                for(var key in anchor_list){
                    x_2 = Math.pow(d.source.x - (d.target.x + anchor_list[key].x), 2);
                    y_2 = Math.pow(d.source.y - (d.target.y + anchor_list[key].y), 2);
                    
                    dist = Math.sqrt(x_2 + y_2)
                    
                    if(dist < min){
                        min = dist;
                        d.anchor = key;
                        offset = anchor_list[key];
                    }
                }
            } else {
                offset = anchor_list[d.anchor];
            }
            
            return "M" + d.source.x + "," + d.source.y + "L" + (d.target.x+ offset.x) + "," + (d.target.y+offset.y);
        });
        
        node.transition().duration(duration).attr("transform", transform);
        circle.transition().duration(duration).attr("transform", transform);
        text.transition().duration(duration).attr("transform", transform);
        
        function transform(d) {
            return "translate(" + d.x + "," + d.y + ")";
        }
    }
