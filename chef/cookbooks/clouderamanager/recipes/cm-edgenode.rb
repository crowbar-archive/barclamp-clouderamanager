#
# Cookbook Name: clouderamanager
# Recipe: cm-edgenode.rb
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

include_recipe 'clouderamanager::cm-client'

#######################################################################
# Begin recipe
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:edgenode") if debug

# Configuration filter for our crowbar environment.
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

# Add the Hue UI link to the crowbar UI - Example : http://192.168.124.85:8088.
Chef::Log.info("CM - hadoop edge node {" + node[:fqdn] + "}") if debug 
server_ip = node.address.addr
node[:crowbar] = {} if node[:crowbar].nil? 
node[:crowbar][:links] = {} if node[:crowbar][:links].nil?
if server_ip
  url = "http://#{server_ip}:8088" 
  Chef::Log.info("CM - Hue UI [#{url}]") if debug 
  node[:crowbar][:links]["Hue UI"] = url 
else
  node[:crowbar][:links].delete("Hue UI")
end

#######################################################################
# End of recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-edgenode") if debug
