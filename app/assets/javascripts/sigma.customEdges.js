;(function() {
  'use strict';

  if (typeof sigma === 'undefined') {
    throw 'sigma is not declared';
  }

  sigma.utils.pkg('sigma.canvas.edges');

  sigma.canvas.edges.def = function(edge, source, target, context, settings) {
    var prefix = settings('prefix') || '',
        edgeColor = settings('edgeColor'),
        defaultNodeColor = settings('defaultNodeColor'),
        defaultEdgeColor = settings('defaultEdgeColor');

    var color = source.color,
      size    = edge.weight;

    context.strokeStyle = color;
    context.globalAlpha = 0.5;
    context.lineWidth   = size;

    context.beginPath();
    context.moveTo(
      source[prefix + 'x'],
      source[prefix + 'y']
    );
    context.lineTo(
      target[prefix + 'x'],
      target[prefix + 'y']
    );
    context.stroke();
    context.globalAlpha = 1;
  };
})();
