require 'action_controller/metal/renderers'

ActionController.add_renderer :gdf do |gdf, options|
  self.response_body = gdf.respond_to?(:to_gdf) ? gdf.to_gdf(options) : gdf
end
