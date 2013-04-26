#
# Cookbook Name: clouderamanager
# Recipe: cm-server.rb
#
# Copyright (c) 2011 Dell Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'clouderamanager::cm-common'

#######################################################################
# Begin recipe
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:cm-server") if debug

# Configuration filter for the crowbar environment.
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

# Install the Cloudera Manager server packages.
server_packages=%w{
    cloudera-manager-daemons
    cloudera-manager-server-db
    cloudera-manager-server
  }

server_packages.each do |pkg|
  package pkg do
    action :install
  end
end

# Cloudera Manager needs to have this directory present. Without it,
# the slave node installation will fail. This is an empty directory and the
# RPM package installer does not seem to create it.
directory "/usr/share/cmf/packages" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# Define the Cloudera Manager server service.
# cloudera-scm-server {start|stop|restart|status}
service "cloudera-scm-server" do
  supports :start => true, :stop => true, :restart => true, :status => true 
  action :enable 
end

# Define the Cloudera Manager database service.
# cloudera-scm-server-db {start|stop|restart|status|initdb}
service "cloudera-scm-server-db" do
  supports :start => true, :stop => true, :restart => true, :status => true 
  action :enable 
end

# Setup the CM server.
# This will only execute if the db is uninitialized, otherwise it returns 1. 
# /var/lib/cloudera-scm-server-db/data is non-empty; perhaps the database
# was already initialized?
bash "cloudera-scm-server-db" do
  code <<-EOH
/etc/init.d/cloudera-scm-server-db initdb
EOH
  returns [0, 1] 
end

# Start the Cloudera Manager database service.
service "cloudera-scm-server-db" do
  action :start 
end

# Start the Cloudera Manager server service.
service "cloudera-scm-server" do
  action :start 
end

# Add the cloudera manager link to the crowbar UI.
Chef::Log.info("CM - Cloudera manager web application {" + node[:fqdn] + "}") if debug 
server_ip = BarclampLibrary::Barclamp::Inventory.get_network_by_type(node,"admin").address
node[:crowbar] = {} if node[:crowbar].nil? 
node[:crowbar][:links] = {} if node[:crowbar][:links].nil?
if server_ip and !server_ip.empty? 
  url = "http://#{server_ip}:7180/cmf/login" 
  Chef::Log.info("CM - Cloudera management services URL [#{url}]") if debug 
  node[:crowbar][:links]["Cloudera Manager"] = url 
else
  node[:crowbar][:links].delete("Cloudera Manager")
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-server") if debug
