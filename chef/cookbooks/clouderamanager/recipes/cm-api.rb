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
  
  libbase = File.join(File.dirname(__FILE__), '../libraries' )
  require "#{libbase}/api_client.rb"
  require "#{libbase}/utils.rb"
  
  #--------------------------------------------------------------------
  # CM API configuration parameters.
  #--------------------------------------------------------------------
  server_host = node[:clouderamanager][:cmapi][:server_host]
  server_port = node[:clouderamanager][:cmapi][:server_port]
  username = node[:clouderamanager][:cmapi][:username]
  password = node[:clouderamanager][:cmapi][:password]
  use_tls = node[:clouderamanager][:cmapi][:use_tls]
  version = node[:clouderamanager][:cmapi][:version]
  
  #--------------------------------------------------------------------
  # Cluster configuration parameters.
  #--------------------------------------------------------------------
  license_key = node[:clouderamanager][:cluster][:license_key] 
  cluster_name = node[:clouderamanager][:cluster][:cluster_name] 
  cdh_version = node[:clouderamanager][:cluster][:cdh_version] 
  
  #######################################################################
  # Locate the cm_server.
  #######################################################################
  search(:node, "roles:clouderamanager-server#{env_filter}") do |n|
    server_ip = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    if server_ip && !server_ip.empty? 
      server_host = server_ip
      if server_host != node[:clouderamanager][:cmapi][:server_host]
        node[:clouderamanager][:cmapi][:server_host] = server_host
        node.save
        break;
      end
    end
  end
  
  #######################################################################
  # Create the API resource object.
  #######################################################################
  Chef::Log.info("CM - Create API resource [#{server_host}, #{server_port}, #{username}, #{password}, #{use_tls}, #{version}, #{debug}]") if debug
  api = ApiResource.new(server_host, server_port, username, password, use_tls, version, debug)
  
  api_version = api.version()
  Chef::Log.info("CM - API version [#{api_version}]") if debug
  
  #######################################################################
  # Apply the license key if present.
  #######################################################################
  Chef::Log.info("CM - license_key [#{license_key}]") if debug
  
  #######################################################################
  # Create the cluster if it does not already exist.
  #######################################################################
  cluster_object = api.find_cluster(cluster_name)
  if cluster_object == nil
    Chef::Log.info("CM - cluster does not exists [#{cluster_name}, #{cdh_version}]") if debug
    cluster_object = api.create_cluster(cluster_name, cdh_version)
    Chef::Log.info("CM - api.create_cluster(#{cluster_name}, #{cdh_version}) results : [#{cluster_object}]") if debug
  else
    Chef::Log.info("CM - cluster already exists [#{cluster_name}, #{cdh_version}] results : [#{cluster_object}]") if debug
  end
  
  #######################################################################
  # Create the HDFS Service.
  #######################################################################
  service_name = "hdfs75"
  service_type = "HDFS"
  hdfs_object = api.find_service(service_name, cluster_name)
  if hdfs_object == nil
    Chef::Log.info("CM - service does not exists [#{service_name}, #{service_type}, #{cluster_name}]") if debug
    hdfs_object = api.create_service(cluster_object, service_name, service_type, cluster_name)
    Chef::Log.info("CM - api.create_service([#{service_name}, #{service_type}, #{cluster_name}]) results : [#{hdfs_object}]") if debug
  else
    Chef::Log.info("CM - service already exists [#{service_name}, #{service_type}, #{cluster_name}] results : [#{hdfs_object}]") if debug
  end
  
  #######################################################################
  # End of automatic cluster deployment.
  #######################################################################
else
  Chef::Log.info("CM - Automatic API configuration feature is disabled") if debug
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-api") if debug
