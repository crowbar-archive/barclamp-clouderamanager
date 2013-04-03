#
# Cookbook Name: clouderamanager
# Recipe: cm-agent.rb
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
Chef::Log.info("CM - BEGIN clouderamanager:cm-api") if debug

# Configuration filter for the crowbar environment.
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

#######################################################################
# The CM API automatic configuration feature is current disabled by
# default. You must enable it in crowbar before queuing the proposal.
# If this feature is disabled, you must configure the cluster manually
# using the CM user interface.
#######################################################################
if node[:clouderamanager][:cmapi][:deployment_type] == 'auto'
  
  libbase = File.join(File.dirname(__FILE__), '../libraries/cmapi' )
  require "#{libbase}/api_client.rb"
  require "#{libbase}/utils.rb"
  
  #----------------------------------------------------------------------
  # CM API configuration parameters.
  #----------------------------------------------------------------------
  server_host = node[:clouderamanager][:cmapi][:server_host]
  server_port = node[:clouderamanager][:cmapi][:server_port]
  username = node[:clouderamanager][:cmapi][:username]
  password = node[:clouderamanager][:cmapi][:password]
  use_tls = node[:clouderamanager][:cmapi][:use_tls]
  version = node[:clouderamanager][:cmapi][:version]
  
  #----------------------------------------------------------------------
  # Cluster configuration parameters.
  #----------------------------------------------------------------------
  license_key = node[:clouderamanager][:cluster][:license_key] 
  Chef::Log.info("CM - license_key [#{license_key}]") if debug
  
  #######################################################################
  # Create the API resource object.
  #######################################################################
  api = ApiResource.new(server_host, server_port, username, password, use_tls, version, debug)
  api_version = api.version()
  Chef::Log.info("CM - API version [#{api_version}]") if debug
  
  #######################################################################
  # Add CM API programming code here.
  #######################################################################
  
else
  Chef::Log.info("CM - Automatic API configuration feature is disabled") if debug
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-api") if debug
