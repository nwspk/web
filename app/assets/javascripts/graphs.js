//= require vis

var initGraph = function (container, data) {
  'use strict';

  var options, dataSet, colorSwatch, nodeMap, uniqColorCounter, network, globalHighlight;

  const ZOOM_THRESHOLD = 1.2;
  globalHighlight = false;

  options = {
    width: '100%',
    height: '600px',

    interaction: {
      selectable: false,
      hover: false,
      dragNodes: false,
      hideEdgesOnDrag: true,
      tooltipDelay: 300
    },

    physics: {
      barnesHut: {
        gravitationalConstant: -15000,
        avoidOverlap: 0,
        springLength: 200
      },

      stabilization: {
        iterations: 1000
      }
    },

    edges: {
      smooth: false,

      scaling: {
        min: 1,
        max: 2
      },

      color: '#ccc',

      selectionWidth: function (width) {
        return width + 0.5;
      }
    },

    nodes: {
      shape: 'dot',

      borderWidth: 4,

      font: {
        face: 'akkuratRegular',
        size: 13,
        color: '#111'
      },

      color: {
        border: '#ccc',
        background: '#d5d5d5'
      },

      scaling: {
        min: 5,
        max: 15
      }
    },

    groups: {}
  };

  /*colorSwatch = [
    ['#556270', '#3f4953'],
    ['#4ECDC4', '#33b5ac'],
    ['#b6f134', '#a0e210'],
    ['#FF6B6B', '#ff3838'],
    ['#C44D58', '#a73742']
  ];

  uniqColorCounter = 0;*/

  data.nodes.forEach(function (n) {
    n.label = undefined;

    if (n.meta.showcase) {
      n.color = {
        background: '#000',
        border: '#000'
      };
    } else {
      n.color = {
        background: '#d5d5d5',
        border: '#ccc'
      };
    }

    if (data.center != null && data.center === n.id) {
      n.color = {
        border: '#ab261f',
        background: '#C02D25',

        hover: {
          border: '#ab261f',
          background: '#C02D25'
        }
      };
    }

    /*if (typeof options.groups[n.group] === 'undefined') {
      var swatch = colorSwatch[uniqColorCounter % colorSwatch.length];

      options.groups[n.group] = {
        color: {
          border: swatch[1],
          background: swatch[0],

          hover: {
            border: swatch[1],
            background: swatch[1]
          }
        }
      };

      uniqColorCounter++;
    }*/
  });

  dataSet = { nodes: new vis.DataSet(data.nodes), edges: new vis.DataSet(data.edges) };

  network = new vis.Network(container, dataSet, options);

  network.on('click', function (props) {
    var node   = network.getNodeAt(props.pointer.DOM),
      allNodes = dataSet.nodes.get({ returnType: 'Object' }),
      allEdges = dataSet.edges.get({ returnType: 'Object' }),
      updatesNodes  = [],
      updatesEdges  = [];

    if (typeof node === 'undefined') {
      globalHighlight = false;

      Object.keys(allNodes).forEach(function (nId) {
        var _node = allNodes[nId];

        _node.highlighted = false;

        if (_node.meta.showcase) {
          _node.color = {
            background: '#000',
            border: '#000'
          };
        } else {
          _node.color = {
            background: '#d5d5d5',
            border: '#ccc'
          };
        }

        updatesNodes.push(allNodes[nId]);
      });

      Object.keys(allEdges).forEach(function (eId) {
        allEdges[eId].color = '#ccc';
        updatesEdges.push(allEdges[eId]);
      });
    } else {
      globalHighlight = true;

      // Highlight neighbourhood
      Object.keys(allNodes).forEach(function (nId) {
        var _node = allNodes[nId];

        _node.highlighted = false;

        _node.color = {
          background: '#d5d5d5',
          border: '#ccc'
        };

        updatesNodes.push(allNodes[nId]);
      });

      Object.keys(allEdges).forEach(function (eId) {
        allEdges[eId].color = '#ccc';
        updatesEdges.push(allEdges[eId]);
      });

      var connectedNodes = network.getConnectedNodes(node),
        connectedEdges = network.getConnectedEdges(node);

      allNodes[node].highlighted = true;

      allNodes[node].color = {
        border: '#ab261f',
        background: '#C02D25'
      };

      connectedEdges.forEach(function (eId) {
        allEdges[eId].color = '#000';
      });

      connectedNodes.forEach(function (nId) {
        var _node = allNodes[nId];

        _node.highlighted = true;

        _node.color = {
          background: '#000',
          border: '#000'
        };
      });
    }

    dataSet.nodes.update(updatesNodes);
    dataSet.edges.update(updatesEdges);
  });

  network.on('zoom', function (props) {
    var allNodes = dataSet.nodes.get({ returnType: 'Object' }),
      updates = [];

    if (globalHighlight) {
      return;
    }

    Object.keys(allNodes).forEach(function (nId) {
      var _node = allNodes[nId];

      if (props.scale < ZOOM_THRESHOLD) {
        if (_node.meta.showcase) {
          _node.color = {
            background: '#000',
            border: '#000'
          };
        } else {
          _node.color = {
            background: '#d5d5d5',
            border: '#ccc'
          };
        }
      } else {
        _node.color = {
          background: '#000',
          border: '#000'
        };
      }

      updates.push(_node);
    });

    dataSet.nodes.update(updates);
  });

  network.on('startStabilizing', function () {
    //$('.loader').show();
  });

  network.on('stabilizationIterationsDone', function () {
    $('.loader').hide();

    if (data.center != null) {
      network.focus(data.center, {
        scale: 0.9,
        animation: {
          duration: 1500,
          easingFunction: 'easeInOutQuint'
        }
      });
    }
  });

  network.on('afterDrawing', function (ctx) {
    var nodes = network.getPositions(),
      zoom = network.getScale();

    var node, pos, box, fontSize, maxVisible, minVisible;

    maxVisible = 24;
    minVisible = 14;

    Object.keys(nodes).forEach(function (nodeId) {
      node     = dataSet.nodes.get(nodeId);
      pos      = nodes[nodeId];
      box      = network.getBoundingBox(nodeId);
      fontSize = 14;

      if (!node.highlighted && !(node.meta.showcase && !globalHighlight) && zoom < ZOOM_THRESHOLD) {
        return;
      }

      if (fontSize * zoom >= maxVisible) {
        fontSize = maxVisible / zoom;
      }

      if (fontSize * zoom <= minVisible) {
        fontSize = minVisible / zoom;
      }

      ctx.font = fontSize + 'px akkuratRegular';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';

      if ((!globalHighlight && node.meta.showcase) || node.highlighted || (zoom >= ZOOM_THRESHOLD && !globalHighlight)) {
        ctx.fillStyle = '#000';
      } else {
        ctx.fillStyle = '#777';
      }

      ctx.fillText(node.meta.name, pos.x, box.bottom + 3);

      if (node.meta.text.length > 0) {
        ctx.font = (fontSize * 0.85) + 'px akkuratLight';
        ctx.fillStyle = '#777';

        ctx.fillText(node.meta.text, pos.x, box.bottom + fontSize + 6);
      }
    });
  });
};
