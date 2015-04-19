$(function () {
  var nodes = JSON.parse($('#friends-graph').attr('data-nodes')),
    edges   = JSON.parse($('#friends-graph').attr('data-edges')),
    w       = 500,
    h       = 500,
    nodeMap = {},
    nodeColors = d3.scale.category20();

  var showDetails, hideDetails;

  showDetails = function (d, i) {
    d3.select(this).style("stroke-width", 2.0);
  };

  hideDetails = function (d, i) {
    d3.select(this).style("stroke-width", 1.0);
  };

  nodes.forEach(function (n) {
    n.x = Math.floor(Math.random() * w);
    n.y = Math.floor(Math.random() * h);
    nodeMap[n.id] = n;
  });

  edges.forEach(function (e) {
    e.source = nodeMap[e.source];
    e.target = nodeMap[e.target];
    e.weight = 1;
  });

  var vis = d3.select("#friends-graph").append("svg:svg").attr("width", 500).attr("height", 500);

  var force = d3.layout.force()
    .nodes(nodes)
    .links(edges)
    .size([500, 500])
    .linkDistance(50)
    .charge(-200)
    .start();

  var link = vis.selectAll("line")
    .data(edges);

  link.enter().append("line")
    .attr("class", "link")
    .style("stroke", "#ddd")
    .style("stroke-width", 5.0);

  link.exit().remove();

  var node = vis.selectAll("circle")
      .data(nodes, function (d) { return d.id });

  node.enter().append("circle")
      .attr("class", "node")
      .attr("r", 10)
      .style("fill", "#aaa")
      .style("stroke", "#666")
      .style("stroke-width", 1.0)
      .on("mouseover", showDetails)
      .on("mouseout", hideDetails)
      .append("svg:title")
      .text(function (d) { return d.name });

  node.exit().remove();

  force.on("tick", function() {
    link.attr("x1", function(d) { return d.source.x; })
        .attr("y1", function(d) { return d.source.y; })
        .attr("x2", function(d) { return d.target.x; })
        .attr("y2", function(d) { return d.target.y; });

    node.attr("cx", function(d) { return d.x; })
        .attr("cy", function(d) { return d.y; });
  });
});
