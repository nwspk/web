//= require vis

var initGraph = function (container, data) {
  'use strict';

  var options, dataSet, colorSwatch, nodeMap, uniqColorCounter, network;

  options = {
    width: '100%',
    height: '600px',

    interaction: {
      selectable: false,
      hover: true,
      dragNodes: false,
      hideEdgesOnDrag: true
    },

    physics: {
      barnesHut: {
        gravitationalConstant: -15000
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

      color: {
        inherit: 'from',
        opacity: 0.5
      },

      selectionWidth: function (width) {
        return width + 0.5;
      }
    },

    nodes: {
      shape: 'dot',

      font: {
        face: 'akkuratRegular',
        size: 13,
        color: '#111'
      },

      color: {
        border: '#555',
        background: '#666',
        hover: {
          border: '#5d5d5d',
          background: '#777'
        }
      }
    },

    groups: {}
  };

  colorSwatch = [
    ['#556270', '#3f4953'],
    ['#4ECDC4', '#33b5ac'],
    ['#b6f134', '#a0e210'],
    ['#FF6B6B', '#ff3838'],
    ['#C44D58', '#a73742']
  ];

  uniqColorCounter = 0;

  data.nodes.forEach(function (n) {
    n.label = undefined;

    if (data.center != null && data.center === n.id) {
      n.borderWidth = 4;

      n.color = {
        border: '#ab261f',
        background: '#C02D25',

        hover: {
          border: '#ab261f',
          background: '#C02D25'
        }
      };
    }

    if (typeof options.groups[n.group] === 'undefined') {
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
    }
  });

  dataSet = { nodes: new vis.DataSet(data.nodes), edges: new vis.DataSet(data.edges) };

  network = new vis.Network(container, dataSet, options);

  network.on('click', function (props) {
    var node = network.getNodeAt(props.pointer.DOM);

    if (typeof node === 'undefined') {
      return;
    }

    var url = dataSet.nodes.get(node.id).meta.url;

    if (url.length > 0) {
      window.open(url, '_blank');
    }
  });

  network.on('startStabilizing', function () {
    $('.loader').show();
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

    var node, pos, box, fontSize, maxVisible;

    if (zoom < 0.6) {
      return;
    }

    maxVisible = 24;

    Object.keys(nodes).forEach(function (nodeId) {
      node     = dataSet.nodes.get(nodeId);
      pos      = nodes[nodeId];
      box      = network.getBoundingBox(nodeId);
      fontSize = 12;

      if (!node.meta.showcase && zoom < 1.5) {
        return;
      }

      if (fontSize * zoom >= maxVisible) {
        fontSize = maxVisible / zoom;
      }

      ctx.font = fontSize + 'px akkuratRegular';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'top';

      if (node.meta.showcase) {
        ctx.fillStyle = '#000';
      } else {
        ctx.fillStyle = '#aaa';
      }

      ctx.fillText(node.meta.name, pos.x, box.bottom + 3);

      if (node.meta.showcase && node.meta.text.length > 0) {
        ctx.font = (fontSize * 0.8) + 'px akkuratLight';
        ctx.fillStyle = '#777';

        ctx.fillText(node.meta.text, pos.x, box.bottom + fontSize + 6);
      }
    });
  });

  $(container).on('contextmenu', function (e) {
    e.preventDefault();
  });
};
