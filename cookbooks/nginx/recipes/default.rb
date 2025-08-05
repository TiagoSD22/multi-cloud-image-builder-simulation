#
# Cookbook:: nginx
# Recipe:: default
#
# Copyright:: 2025, DevOps Team, All Rights Reserved.

# Update package cache
apt_update 'update_package_cache' do
  action :update
end

# Install nginx package
package 'nginx' do
  action :install
end

# Create a custom index.html
template '/var/www/html/index.html' do
  source 'index.html.erb'
  owner 'www-data'
  group 'www-data'
  mode '0644'
  action :create
end

# Configure nginx
template '/etc/nginx/sites-available/default' do
  source 'default.erb'
  owner 'root'
  group 'root'
  mode '0644'
  action :create
  notifies :restart, 'service[nginx]', :delayed
end

# Ensure nginx service is enabled and started
service 'nginx' do
  action [:enable, :start]
end

# Open firewall for HTTP traffic (if ufw is present)
execute 'allow_http' do
  command 'ufw allow "Nginx Full"'
  only_if 'which ufw'
  ignore_failure true
end

# Create a simple health check endpoint
file '/var/www/html/health' do
  content 'OK'
  owner 'www-data'
  group 'www-data'
  mode '0644'
  action :create
end
