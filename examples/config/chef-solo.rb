#
# Example Chef Solo Config

cookbook_path File.join(File.dirname(__FILE__), "cookbooks")
node_path     File.join(File.dirname(__FILE__), "nodes")
log_level     :debug

