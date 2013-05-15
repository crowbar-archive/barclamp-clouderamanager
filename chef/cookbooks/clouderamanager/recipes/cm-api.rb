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
  
  # TODO: Set the rack ID.
  # Need to add a CB rack_id parameter on each node.
  # See DE1174 for details.
  rack_id = node[:clouderamanager][:cluster][:rack_id] 
  
  #--------------------------------------------------------------------
  # CB node information (each item is an array of records).
  #--------------------------------------------------------------------
  namenodes = node[:clouderamanager][:cluster][:namenodes] 
  datanodes = node[:clouderamanager][:cluster][:datanodes]
  edgenodes = node[:clouderamanager][:cluster][:edgenodes] 
  
  #####################################################################
  # Find the cm_server.
  #####################################################################
  def find_cm_server(debug, env_filter, node_object)
    cmservernodes = node_object[:clouderamanager][:cluster][:cmservernodes]
    if cmservernodes and cmservernodes.length > 0 
      rec = cmservernodes[0]
      return rec[:ipaddr]
    end
    return nil
  end
  
  #####################################################################
  # Build the cluster configuration data structure with CM role associations.
  # Role names must be unique across all clusters. 
  # HDFS : NAMENODE, SECONDARYNAMENODE, DATANODE, BALANCER, GATEWAY, HTTPFS,
  # JOURNALNODE, FAILOVERCONTROLLER.
  # MAPREDUCE : JOBTRACKER, TASKTRACKER, GATEWAY 
  #####################################################################
  def build_roles(debug, cluster_name, namenodes, datanodes, edgenodes)
    
    #####################################################################
    # Role appender helper method.
    #####################################################################
    def role_appender(debug, cluster_config, cluster_name, counter_map, cb_nodes, service_type, role_type)
      if cb_nodes  
        cb_nodes.each do |n|
          counter_map[role_type] = 1 if counter_map[role_type].nil?
          cnt = sprintf("%2.2d", counter_map[role_type])
          role_name = "#{role_type}-#{cluster_name}-#{cnt}"
          rec = { :host_id => n[:fqdn], :name => n[:name], :role_type => role_type, :role_name => role_name, :service_type => service_type, :ipaddr => n[:ipaddr] }
          Chef::Log.info("CM - cluster_config add [#{rec.inspect}]") if debug
          cluster_config << rec
          counter_map[role_type] += 1
        end
      end
    end    
    
    #--------------------------------------------------------------------
    # Add the CM role definitions.
    #--------------------------------------------------------------------
    config = []
    counter_map = { }
    # primary namenode
    if namenodes.length > 0
      primary_namenode = [ namenodes[0] ]
      role_appender(debug, config, cluster_name, counter_map, primary_namenode, "HDFS", 'NAMENODE')
      role_appender(debug, config, cluster_name, counter_map, primary_namenode, "MAPREDUCE", 'JOBTRACKER')
    end
    # secondary namenode
    if namenodes.length > 1
      secondary_namenode = [ namenodes[1] ]
      role_appender(debug, config, cluster_name, counter_map, secondary_namenode, "HDFS", 'SECONDARYNAMENODE')
    end
    # datanodes
    role_appender(debug, config, cluster_name, counter_map, datanodes, "HDFS", 'DATANODE')
    role_appender(debug, config, cluster_name, counter_map, datanodes, "MAPREDUCE", 'TASKTRACKER')
    Chef::Log.info("CM - cluster configuration [#{config.inspect}]") if debug
    # edgenodes
    if edgenodes.length > 0
      role_appender(debug, config, cluster_name, counter_map, edgenodes, "HDFS", 'GATEWAY')
    end
    return config
  end
  
  #####################################################################
  # Create the API resource object (establish the RESTful API connection).
  #####################################################################
  def create_api_resource(debug, server_host, server_port, username, password, use_tls, version)
    Chef::Log.info("CM - Create API resource [#{server_host}, #{server_port}, #{username}, #{password}, #{use_tls}, #{version}, #{debug}]") if debug
    api = ApiResource.new(server_host, server_port, username, password, use_tls, version, debug)
    api_version = api.version()
    Chef::Log.info("CM - API version [#{api_version}]") if debug
    return api
  end
  
  #####################################################################
  # Check the license key adn update if needed.
  # Note: get_license will report nil until the cm-server has been restarted.
  #####################################################################
  def check_license_key(debug, api, license_key)
    license_check  = api.get_license()
    Chef::Log.info("CM - license_check") if debug
    # Only update if not active or key has changed.
    if license_check.nil? or license_check != license_key 
      Chef::Log.info("CM - updating license") if debug
      api_license = api.update_license(license_key)
      Chef::Log.info("CM - update license returns [#{api_license}]") if debug
      service "cloudera-scm-server" do
        action :restart 
      end
      Chef::Log.info("CM - cm-server restarted") if debug
    end
  end
  
  #####################################################################
  # Configure the cluster.
  #####################################################################
  def configure_cluster(debug, api, cluster_name, cdh_version)
    cluster_object = api.find_cluster(cluster_name)
    if cluster_object == nil
      Chef::Log.info("CM - cluster does not exists [#{cluster_name}, #{cdh_version}]") if debug
      cluster_object = api.create_cluster(cluster_name, cdh_version)
      Chef::Log.info("CM - api.configure_cluster(#{cluster_name}, #{cdh_version}) results : [#{cluster_object}]") if debug
    else
      Chef::Log.info("CM - cluster already exists [#{cluster_name}, #{cdh_version}] results : [#{cluster_object}]") if debug
    end
    return cluster_object
  end
  
  #####################################################################
  # Configure the cluster hosts.
  #####################################################################
  def configur_host_instances(debug, api, rack_id, cluster_config)
    cluster_config.each do |host_rec|
      host_id = host_rec[:host_id]
      name = host_rec[:name]
      ipaddr = host_rec[:ipaddr]
      host_object = api.find_host(host_id)
      if host_object == nil
        Chef::Log.info("CM - host does not exists [#{host_id}]") if debug
        host_object = api.create_host(host_id, name, ipaddr, rack_id)
        Chef::Log.info("CM - api.create_host results(#{host_id}, #{name}, #{ipaddr}, #{rack_id}) results : [#{host_object}]") if debug
      else
        Chef::Log.info("CM - host already exists [#{host_id}] results : [#{host_object}]") if debug
      end
    end
  end
  
  #####################################################################
  # Configure the cluster services.
  #####################################################################
  def configure_service(debug, api, service_name, service_type, cluster_name, cluster_object)
    service = api.find_service(service_name, cluster_name)
    if service == nil
      Chef::Log.info("CM - service does not exists [#{service_name}, #{service_type}, #{cluster_name}]") if debug
      service = api.create_service(cluster_object, service_name, service_type, cluster_name)
      Chef::Log.info("CM - api.create_service([#{service_name}, #{service_type}, #{cluster_name}]) results : [#{service}]") if debug
    else
      Chef::Log.info("CM - service already exists [#{service_name}, #{service_type}, #{cluster_name}] results : [#{service}]") if debug
    end
    return service
  end
  
  #####################################################################
  # Apply the cluster roles.
  #####################################################################
  def apply_roles(debug, api, hdfs_service, mapr_service, cluster_name, cluster_config)
    cluster_config.each do |host_rec|
      valid_config = true
      host_id = host_rec[:host_id]
      host_name = host_rec[:name]
      host_ip = host_rec[:ipaddr]
      role_name = host_rec[:role_name]
      role_type = host_rec[:role_type]
      service_type = host_rec[:service_type]
      service_object = nil
      if service_type == "HDFS"
        service_object = hdfs_service
      elsif service_type == "MAPREDUCE"
        service_object = mapr_service
      else
        Chef::Log.info("CM - ERROR : Bad service type [#{service_type}] in apply_roles")
        valid_config = false
      end
      if valid_config
        role_object = api.find_role(service_object, role_name)
        if role_object == nil
          Chef::Log.info("CM - role does not exists [#{host_id}]") if debug
          role_object = api.create_role(service_object, role_name, role_type, host_id)
          Chef::Log.info("CM - api.create_role results(#{role_name}, #{role_type}, #{host_id}) results : [#{role_object}]") if debug
        else
          Chef::Log.info("CM - role already exists [#{role_name}] results : [#{role_object}]") if debug
        end
      end
    end
  end
  
  #####################################################################
  # CM API MAIN
  #####################################################################
  
  #--------------------------------------------------------------------
  # Find the cm server. 
  #--------------------------------------------------------------------
  server_host = find_cm_server(debug, env_filter, node) 
  if not server_host or server_host.empty?
    Chef::Log.info("CM - ERROR: Cannot locate CM server - skipping CM_API setup")
  else
    #--------------------------------------------------------------------
    # Establish the RESTful API connection. 
    #--------------------------------------------------------------------
    api = create_api_resource(debug, server_host, server_port, username, password, use_tls, version) 
    if not api
      Chef::Log.info("CM - ERROR: Cannot create CM API resource - skipping CM_API setup")
    else
      #--------------------------------------------------------------------
      # Build the cluster configuration data structure with CM role associations.
      #--------------------------------------------------------------------
      cluster_config = build_roles(debug, cluster_name, namenodes, datanodes, edgenodes)
      
      #--------------------------------------------------------------------
      # Set the license key if present. 
      #--------------------------------------------------------------------
      if license_key and not license_key.empty? 
        check_license_key(debug, api, license_key)
      end
      
      #--------------------------------------------------------------------
      # Configure the cluster. 
      #--------------------------------------------------------------------
      cluster_object = configure_cluster(debug, api, cluster_name, cdh_version)
      
      #--------------------------------------------------------------------
      # Configure the host instances. 
      #--------------------------------------------------------------------
      configur_host_instances(debug, api, rack_id, cluster_config)
      
      #--------------------------------------------------------------------
      # Configure the HDFS service. 
      #--------------------------------------------------------------------
      service_name = "hdfs-#{cluster_name}"
      service_type = "HDFS"
      hdfs_service = configure_service(debug, api, service_name, service_type, cluster_name, cluster_object)  
      
=begin
      # Note: The v3 API does not support rt_configs and you
      # must use role groups for this case. The v2 API does maintain
      # backward compatibility with this call.
      if debug
        result = api.get_service_config(hdfs_service, 'full')
        svc_config = result[:svc_config]
        rt_configs = result[:rt_configs]
        Chef::Log.info("\n######### svc_config\n#{svc_config}\n")
        Chef::Log.info("\n######### rt_configs\n#{rt_configs}\n")
      end
=end
      
      #--------------------------------------------------------------------
      # If we bypass the CM setup wizard, we need to set some required
      # parameters or HDFS will not start-up correctly. Only set the
      # bare minimum to get the cluster up and running
      # (Rely the CM interface for everything else).
      #--------------------------------------------------------------------
      hdfs_service_config = {
      }
      nn_config = {
        'dfs_name_dir_list' => '/dfs/nn',
      }
      snn_config = {
        'fs_checkpoint_dir_list' => '/dfs/snn'
      }
      dn_config = {
        'dfs_data_dir_list' => '/data/1/dfs/dn,/data/2/dfs/dn'
      }
      gw_config = {
        'dfs_client_use_trash' => true
      }
      rt_configs = {
        'NAMENODE' => nn_config,
        'SECONDARYNAMENODE' => snn_config,
        'DATANODE' => dn_config,
        'GATEWAY' => gw_config
      }      
      Chef::Log.info("CM - Updating HDFS service configuration") if debug
      result = api.update_service_config(hdfs_service, hdfs_service_config, rt_configs)
      # Chef::Log.info("CM - HDFS service configuration results #{result}") if debug
      
      #--------------------------------------------------------------------
      # Configure the MAPREDUCE service. 
      #--------------------------------------------------------------------
      service_name = "mapr-#{cluster_name}"
      service_type = "MAPREDUCE"
      mapr_service = configure_service(debug, api, service_name, service_type, cluster_name, cluster_object)  
      
      #--------------------------------------------------------------------
      # Apply the cluster roles. 
      #--------------------------------------------------------------------
      apply_roles(debug, api, hdfs_service, mapr_service, cluster_name, cluster_config)
    end
  end
  
  #####################################################################
  # End of automatic cluster deployment.
  #####################################################################
else
  Chef::Log.info("CM - Automatic CM API feature is disabled") if debug
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-api") if debug
