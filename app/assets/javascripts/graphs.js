//= require vis

var initGraph = function (container, data) {
  'use strict';

  var options, dataSet, colorSwatch, nodeMap, uniqColorCounter, network;

  options = {
    width: '100%',
    height: '600px',

    interaction: {
      selectable: false,
      hover: false,
      dragNodes: false
    },

    edges: {
      scaling: {
        min: 1,
        max: 2
      },

      color: {
        inherit: 'from'
      },

      selectionWidth: function (width) {
        return width + 0.5;
      }
    },

    nodes: {
      shape: 'dot',

      font: {
        face: 'akkuratRegular'
      },

      color: {
        border: '#555',
        background: '#666'
      }
    },

    groups: {}
  };

  colorSwatch = [['#556270', '#3f4953'], ['#4ECDC4', '#33b5ac'], ['#C7F464', '#b6f134'], ['#FF6B6B', '#ff3838'], ['#C44D58', '#a73742']];
  uniqColorCounter = 0;
  nodeMap = {};

  data.nodes.forEach(function (n) {
    nodeMap[n.id] = n;

    if (typeof options.groups[n.group] === 'undefined') {
      var swatch = colorSwatch[uniqColorCounter % colorSwatch.length];

      options.groups[n.group] = {
        color: {
          border: swatch[1],
          background: swatch[0]
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

    var url = nodeMap[node.id].meta.url;

    if (url.length > 0) {
      window.open(url, '_blank');
    }
  });

  network.on('oncontext', function (props) {
    var node = network.getNodeAt(props.pointer.DOM);

    if (typeof node === 'undefined') {
      return;
    }

    dataSet.nodes.remove(node.id);

    return false;
  });

  network.on('startStabilizing', function () {
    $('.loader').show();
  });

  network.on('stabilized', function () {
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

  $(container).on('contextmenu', function (e) {
    e.preventDefault();
  });
};
