#
# Cookbook Name: clouderamanager
# Recipe: cm-common.rb
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

#######################################################################
# Begin recipe
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:cm-common") if debug

# Configuration filter for our crowbar environment.
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

# Install the common Cloudera Manager packages (all nodes).
pkg_list=%w{
    cloudera-manager-plugins
    hue-hadoop-auth-plugin
  }

pkg_list.each do |pkg|
  package pkg do
    action :install
  end
end

# Find the management services nodes. 
mgmt_service_nodes = []
mgmt_service_fqdns = []
search(:node, "roles:clouderamanager-mgmtservices#{env_filter}") do |obj|
  if obj
    mgmt_service_nodes << obj
    if obj[:fqdn] and !obj[:fqdn].empty?
      mgmt_service_fqdns << obj[:fqdn]
    end
  end
end

Chef::Log.info("CM - Management service nodes {" + mgmt_service_fqdns.join(",") + "}") if debug 
node[:clouderamanager][:cluster][:mgmt_service_nodes] = mgmt_service_fqdns

if mgmt_service_nodes and mgmt_service_nodes.length > 0
  obj = mgmt_service_nodes[0]
  server_ip = BarclampLibrary::Barclamp::Inventory.get_network_by_type(obj,"public").address
  if server_ip.nil? or server_ip.empty?
    server_ip = BarclampLibrary::Barclamp::Inventory.get_network_by_type(obj,"admin").address
  end  
  Chef::Log.info("CM - Management server IP [#{server_ip}]") if debug
  node[:crowbar] = {} if node[:crowbar].nil? 
  node[:crowbar][:links] = {} if node[:crowbar][:links].nil?
  if server_ip
    node[:crowbar][:links]["Cloudera Manager"] = "http://#{server_ip}:7180/cmf/login" 
  else
    node[:crowbar][:links].delete("Cloudera Manager")
  end
else
  node[:crowbar][:links].delete("Cloudera Manager")
end
node.save

#######################################################################
# End of recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-common") if debug
