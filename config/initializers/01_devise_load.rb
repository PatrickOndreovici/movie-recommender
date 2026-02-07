# Load Devise and its route helpers before routes are drawn.
# This must run early (01_ prefix) so devise_for is available in config/routes.rb.
require "devise"
require "devise/rails/routes"
