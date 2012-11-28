#
# Cookbook Name: clouderamanager
# Recipe: cm-pkginstaller.rb
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
Chef::Log.info("CM - BEGIN clouderamanager:cm-pkginstaller") if debug

# Configuration filter for the crowbar environment.
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

# Is the cm server node.
is_cm_server_node = false
search(:node, "roles:clouderamanager-server#{env_filter}") do |n|
  if n[:fqdn] && !n[:fqdn].empty? && node[:fqdn] && !node[:fqdn].empty? && n[:fqdn] == node[:fqdn] 
    is_cm_server_node = true
    break;
  end
end

# Include the agent packages if this is not a cm-server node.
# CM server packages are installed by the clouderamanager-server role.
if !is_cm_server_node
  Chef::Log.info("CM - cm-agent node instance") if debug 
  include_recipe 'clouderamanager::cm-agent'
else
  Chef::Log.info("CM - cm-server node instance") if debug 
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-pkginstaller") if debug
