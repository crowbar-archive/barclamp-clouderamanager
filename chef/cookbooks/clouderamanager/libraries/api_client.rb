#!/usr/bin/ruby
#
# Copyright(c) 2011 Dell Inc.
#
# Licensed under the Apache License, Version 2.0(the "License");
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

require 'rubygems'
require 'restclient'

libbase = File.dirname(__FILE__)
require "#{libbase}/api_resource.rb"

#######################################################################
# ApiClient
#######################################################################
class CmApiClient < ApiResource
  
  #######################################################################
  # Creates an ApiClient object that provides API endpoints.
  # @param logger: The Logger interface for messaging.
  # @param server_host: The hostname of the Cloudera Manager server.
  # @param server_port: The port of the server. Defaults to 7180(http) or 7183(https).
  # @param username: Login name.
  # @param use_tls: Whether to use tls(https).
  # @param version: API version.
  # @return Resource object referring to the root.
  #######################################################################
  def initialize(logger, server_host, server_port=nil, username="admin", password="admin", use_tls=false, version=API_CURRENT_VERSION, debug=false)
    @logger = logger
    @server_host=server_host
    @server_port=server_port
    @username=username
    @password=password
    @use_tls=use_tls
    @version=version
    @debug=debug
    super(server_host, server_port, username, password, use_tls, version, debug)
  end
  
  #####################################################################
  # Find the cm_server.
  #####################################################################
  def _find_cm_server(cmservernodes)
    if cmservernodes and cmservernodes.length > 0 
      rec = cmservernodes[0]
      return rec[:ipaddr]
    end
    return nil
  end
  
  #####################################################################
  # Role appender helper method.
  #####################################################################
  def _role_appender(debug, cluster_config, cluster_name, counter_map, cb_nodes, service_type, role_type)
    if cb_nodes  
      cb_nodes.each do |n|
        counter_map[role_type] = 1 if counter_map[role_type].nil?
        cnt = sprintf("%2.2d", counter_map[role_type])
        role_name = "#{role_type}-#{cluster_name}-#{cnt}"
        # Check for role duplication on this node and skip if the role is already there.
        skip_role_insertion = false
        cluster_config.each do |r|
          if r[:host_id] == n[:fqdn] and r[:service_type] == service_type and r[:role_type] == role_type
            skip_role_insertion = true
            break
          end
        end
        if skip_role_insertion
          @logger.info("CM - #{role_type} role duplicated on node #{n[:fqdn]}, skipping role insertion") if debug
        else
          rec = { :host_id => n[:fqdn], :name => n[:name], :role_type => role_type, :role_name => role_name, :service_type => service_type, :ipaddr => n[:ipaddr] }
          @logger.info("CM - cluster_config add [#{rec.inspect}]") if debug
          cluster_config << rec
          counter_map[role_type] += 1
        end
      end
    end
  end    
  
  #####################################################################
  # Build the cluster configuration data structure with CM role associations.
  # Role names must be unique across all clusters. 
  # HDFS : NAMENODE, SECONDARYNAMENODE, DATANODE, BALANCER, GATEWAY,
  # HTTPFS, JOURNALNODE, FAILOVERCONTROLLER. MAPREDUCE : JOBTRACKER,
  # TASKTRACKER
  #####################################################################
  def _build_roles(debug, cluster_name, namenodes, datanodes, edgenodes, cmservernodes, hafilernodes, hajournalingnodes)
    #--------------------------------------------------------------------
    # Add the CM role definitions.
    #--------------------------------------------------------------------
    config = []
    counter_map = { }
    # primary namenode
    if namenodes.length > 0
      primary_namenode = [ namenodes[0] ]
      _role_appender(debug, config, cluster_name, counter_map, primary_namenode, "HDFS", 'NAMENODE')
      _role_appender(debug, config, cluster_name, counter_map, primary_namenode, "MAPREDUCE", 'JOBTRACKER')
      _role_appender(debug, config, cluster_name, counter_map, primary_namenode, "HDFS", 'GATEWAY')
      _role_appender(debug, config, cluster_name, counter_map, primary_namenode, "MAPREDUCE", 'GATEWAY')
    end
    # secondary namenode
    if namenodes.length > 1
      secondary_namenode = [ namenodes[1] ]
      _role_appender(debug, config, cluster_name, counter_map, secondary_namenode, "HDFS", 'SECONDARYNAMENODE')
      _role_appender(debug, config, cluster_name, counter_map, secondary_namenode, "HDFS", 'GATEWAY')
      _role_appender(debug, config, cluster_name, counter_map, secondary_namenode, "MAPREDUCE", 'GATEWAY')
    end
    # datanodes
    if datanodes.length > 0
      _role_appender(debug, config, cluster_name, counter_map, datanodes, "HDFS", 'DATANODE')
      _role_appender(debug, config, cluster_name, counter_map, datanodes, "MAPREDUCE", 'TASKTRACKER')
      _role_appender(debug, config, cluster_name, counter_map, datanodes, "HDFS", 'GATEWAY')
      _role_appender(debug, config, cluster_name, counter_map, datanodes, "MAPREDUCE", 'GATEWAY')
    end
    # edgenodes
    if edgenodes.length > 0
      _role_appender(debug, config, cluster_name, counter_map, edgenodes, "HDFS", 'GATEWAY')
      _role_appender(debug, config, cluster_name, counter_map, edgenodes, "MAPREDUCE", 'GATEWAY')
    end
    # hafilernodes
    if hafilernodes.length > 0
      _role_appender(debug, config, cluster_name, counter_map, hafilernodes, "HDFS", 'GATEWAY')
      _role_appender(debug, config, cluster_name, counter_map, hafilernodes, "MAPREDUCE", 'GATEWAY')
    end
    # hajournalingnodes
    if hajournalingnodes.length > 0
      _role_appender(debug, config, cluster_name, counter_map, hajournalingnodes, "HDFS", 'GATEWAY')
      _role_appender(debug, config, cluster_name, counter_map, hajournalingnodes, "MAPREDUCE", 'GATEWAY')
    end
    @logger.info("CM - cluster configuration [#{config.inspect}]") if debug
    return config
  end
  
  #####################################################################
  # Check the license key and update if needed.
  # Note: get_license will report nil until the cm-server has been restarted.
  #####################################################################
  def _check_license_key(debug, cb_license_key, config_state)
    # cm_license_key = ApiLicense object - owner, uuid, expiration
    cm_license_key = get_license()
    cm_uuid = nil
    if cm_license_key
      cm_uuid = cm_license_key.getattr('uuid')
    end
    if cm_uuid and not cm_uuid.empty?
      @logger.info("CM - existing CM license key found [#{cm_uuid}]") if debug
    else
      @logger.info("CM - no existing CM license key") if debug
    end
    # Is there a valid license key specified in the crowbar proposal?
    if cb_license_key and not cb_license_key.empty? 
      #################################################################
      # Parse the header key, value pairs.
      # Example: name=devel-06-02282014]
      #          expirationDate=2014-02-28
      #          uuid=aa743538-7b1c-11e2-961a-b499baa7f55b
      #################################################################
      hash = Hash[cb_license_key.scan /^\s*"(.+?)": "(.+?)",\s*$/m]
      cb_uuid = hash['uuid'] 
      @logger.info("CM - CB license is present [#{cb_uuid}]") if debug
      # If CM license is not already active or license key has changed.
      if cm_uuid.nil? or cm_uuid.empty? or cb_uuid != cm_uuid
        @logger.info("CM - updating license cm_uuid=#{cm_uuid} cb_uuid=#{cb_uuid}") if debug
        # Update the license. 
        api_license = update_license(cb_license_key)
        if not config_state[:cm_server_restarted]
          # Restart the cm server to activate.
          @logger.info("CM - restarting cm-server") if debug
          output = %x{service cloudera-scm-server restart}
          if $?.exitstatus != 0
            @logger.error("cloudera-scm-server restart failed #{output}")
          else
            @logger.info("CM - cm-server restarted #{output}") if debug
            config_state[:cm_server_restarted] = true
          end
        end
      else
        @logger.info("CM - license update NOT required cm_uuid=#{cm_uuid} cb_uuid=#{cb_uuid}") if debug
      end
    end
  end
  
  #####################################################################
  # Configure the cluster.
  #####################################################################
  def _configure_cluster(debug, cluster_name, cdh_version)
    cluster_object = find_cluster(cluster_name)
    if cluster_object == nil
      @logger.info("CM - cluster does not exists [#{cluster_name}, #{cdh_version}]") if debug
      cluster_object = create_cluster(cluster_name, cdh_version)
      @logger.info("CM - _configure_cluster(#{cluster_name}, #{cdh_version}) results : [#{cluster_object}]") if debug
    else
      @logger.info("CM - cluster already exists [#{cluster_name}, #{cdh_version}] results : [#{cluster_object}]") if debug
    end
    return cluster_object
  end
  
  #####################################################################
  # Configure the hosts.
  #####################################################################
  def _configure_host_instances(debug, rack_id, cluster_config)
    cluster_config.each do |host_rec|
      host_id = host_rec[:host_id]
      name = host_rec[:name]
      ipaddr = host_rec[:ipaddr]
      host_object = find_host(host_id)
      if host_object == nil
        @logger.info("CM - host does not exists [#{host_id}]") if debug
        host_object = create_host(host_id, name, ipaddr, rack_id)
        @logger.info("CM - create_host results(#{host_id}, #{name}, #{ipaddr}, #{rack_id}) results : [#{host_object}]") if debug
      else
        @logger.info("CM - host already exists [#{host_id}] results : [#{host_object}]") if debug
      end
    end
  end
  
  #####################################################################
  # Configure the services.
  #####################################################################
  def _configure_service(debug, service_name, service_type, cluster_name, cluster_object)
    service = find_service(service_name, cluster_name)
    if service == nil
      @logger.info("CM - service does not exists [#{service_name}, #{service_type}, #{cluster_name}]") if debug
      service = create_service(cluster_object, service_name, service_type, cluster_name)
      @logger.info("CM - create_service([#{service_name}, #{service_type}, #{cluster_name}]) results : [#{service}]") if debug
    else
      @logger.info("CM - service already exists [#{service_name}, #{service_type}, #{cluster_name}] results : [#{service}]") if debug
    end
    return service
  end
  
  #####################################################################
  # Apply the roles.
  #####################################################################
  def _apply_roles(debug, cluster_config, hdfs_service, mapr_service, cluster_name)
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
        @logger.info("CM - ERROR : Bad service type [#{service_type}] in _apply_roles")
        valid_config = false
      end
      if valid_config
        role_object = find_role(service_object, role_name)
        if role_object == nil
          @logger.info("CM - role does not exists [#{host_id}]") if debug
          role_object = create_role(service_object, role_name, role_type, host_id)
          @logger.info("CM - create_role results(#{role_name}, #{role_type}, #{host_id}) results : [#{role_object}]") if debug
        else
          @logger.info("CM - role already exists [#{role_name}] results : [#{role_object}]") if debug
        end
      end
    end
  end
  
  #####################################################################
  # Format HDFS.
  #####################################################################
  def _format_hdfs(debug, cluster_config, service_object)
    cmd_timeout = 10 * 60
    service_name = service_object.getattr('name')
    cluster_config.each do |r|
      if r[:role_type] == 'NAMENODE'
        role_name = r[:role_name]
        @logger.info("CM - Attempting HDFS format [#{service_name}, #{role_name}]") if debug
        cmd_array = format_hdfs(service_object, [ role_name ])
        cmd = cmd_array[0]
        id = cmd.getattr('id')
        active = cmd.getattr('active')
        success = cmd.getattr('success')
        msg = cmd.getattr('resultMessage')
        # If the command is still running, wait for it (note: success is neither true or false at this point). 
        if active 
          @logger.info("CM - Waiting for HDFS format to complete [name:#{service_name}, id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
          wcmd = wait_for_cmd(cmd, cmd_timeout)
          id = wcmd.getattr('id')
          active = wcmd.getattr('active')
          success = wcmd.getattr('success')
          msg = wcmd.getattr('resultMessage')
          # If we timeout and the command is still running, try again later.
          if active
            msg = "CM - HDFS format is running asynchronously in the background, trying again later"
            @logger.info(msg) if debug
            raise Errno::ECONNREFUSED, msg
          end
        end
        if not success
          @logger.info("CM - HDFS format returns [name:#{service_name}, id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
          # Abort the command if it's still running.
          if active
            wcmd = abort_cmd(cmd) 
            id = wcmd.getattr('id')
            active = wcmd.getattr('active')
            success = wcmd.getattr('success')
            msg = wcmd.getattr('resultMessage')
            @logger.info("CM - HDFS format terminated [name:#{service_name}, id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
          end
          return
        end
        @logger.info("CM - HDFS format complete [name:#{service_name}, id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
      end
    end
  end
  
  #--------------------------------------------------------------------
  # Startup a service. 
  #--------------------------------------------------------------------
  def _start_service(debug, cluster_config, service_object)
    cmd_timeout = 10 * 60
    service_name = service_object.getattr('name')
    @logger.info("CM - Attempting #{service_name} service startup") if debug
    cmd = start_service(service_object)
    id = cmd.getattr('id')
    active = cmd.getattr('active')
    success = cmd.getattr('success')
    msg = cmd.getattr('resultMessage')
    # If the command is still running, wait for it (note: success is neither true or false at this point). 
    if active 
      @logger.info("CM - Waiting for #{service_name} service startup [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
      wcmd = wait_for_cmd(cmd, cmd_timeout)
      id = wcmd.getattr('id')
      active = wcmd.getattr('active')
      success = wcmd.getattr('success')
      msg = wcmd.getattr('resultMessage')
      # If we timeout and the command is still running, try again later.
      if active
        msg = "CM - #{service_name} service startup is running asynchronously in the background, trying again later"
        @logger.info(msg) if debug
        raise Errno::ECONNREFUSED, msg
      end
    end
    if not success
      @logger.info("CM - #{service_name} service startup returns [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
      # Abort the command if it's still running.
      if active
        wcmd = abort_cmd(cmd) 
        id = wcmd.getattr('id')
        active = wcmd.getattr('active')
        success = wcmd.getattr('success')
        msg = wcmd.getattr('resultMessage')
        @logger.info("CM - #{service_name} service startup terminated [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
      end
      return
    end
    @logger.info("CM - #{service_name} service startup complete [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
  end
  
  #--------------------------------------------------------------------
  # Initialize HDFS.
  # HDFS format does not cover all the initialization cases.
  #--------------------------------------------------------------------
  def _hdfs_init(debug, cluster_config, namenodes)
    return if namenodes.nil? or namenodes.empty? 
    master = namenodes[0]
    return if master.nil? or master.empty? 
    host_fqdn = master[:fqdn]
    return if host_fqdn.nil? or host_fqdn.empty? 
    hadoop_cmds = [
          "hadoop fs -mkdir -p hdfs://#{host_fqdn}/tmp/mapred",
          "hadoop fs -chown mapred hdfs://#{host_fqdn}/tmp/mapred",
          "hadoop fs -chmod 755 hdfs://#{host_fqdn}/tmp/mapred",
          "hadoop fs -mkdir -p hdfs://#{host_fqdn}/tmp/mapred/system",
          "hadoop fs -chown mapred hdfs://#{host_fqdn}/tmp/mapred/system",
          "hadoop fs -chmod 755 hdfs://#{host_fqdn}/tmp/mapred/system"
    ]
    # Issue the commands and check status.
    hadoop_cmds.each do |cmd|
      sucmd = "su - -c '#{cmd}' hdfs"
      @logger.info("CM - execute #{sucmd}") if debug
      if system(sucmd)
        @logger.info("CM - SUCCESS [#{$?}]") if debug
      else
        @logger.error("CM - ERROR [#{$?}]")
      end
    end
  end
  
  #####################################################################
  # Deploy a client configuration.
  #####################################################################
  def _deploy_client_config(debug, cluster_config, service_object, service_type)
    cmd_timeout = 10 * 60
    role_list = []
    host_list = []
    cluster_config.each do |r|
      if r[:service_type] == service_type
        role_list << r[:role_name] 
        host_list << r[:host_id] 
      end
    end 
    if role_list and not role_list.empty?
      @logger.info("CM - Attempting #{service_type} configuration deployment #{host_list.join(",")}") if debug
      cmd = deploy_client_config(service_object, role_list)
      id = cmd.getattr('id')
      active = cmd.getattr('active')
      success = cmd.getattr('success')
      msg = cmd.getattr('resultMessage')
      # If the command is still running, wait for it (note: success is neither true or false at this point). 
      if active 
        @logger.info("CM - Waiting for #{service_type} configuration deployment [name:#{service_type}, id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
        wcmd = wait_for_cmd(cmd, cmd_timeout)
        id = wcmd.getattr('id')
        active = wcmd.getattr('active')
        success = wcmd.getattr('success')
        msg = wcmd.getattr('resultMessage')
        @logger.info("CM - #{service_type} configuration deployment results [name:#{service_type}, id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
        # If we timeout and the command is still running, try again later.
        if active 
          msg = "CM - #{service_type} configuration deployment is running asynchronously in the background, trying again later"
          @logger.info(msg) if debug
          raise Errno::ECONNREFUSED, msg
        end
      end
      if not success
        @logger.info("CM - Deploy client configuration returns [name:#{service_type}, id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
        if active
          wcmd = abort_cmd(cmd) 
          id = wcmd.getattr('id')
          active = wcmd.getattr('active')
          success = wcmd.getattr('success')
          msg = wcmd.getattr('resultMessage')
          @logger.info("CM - Deploy client configuration terminated [name:#{service_type}, id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
        end
        return
      end
    end
  end            
  
  #####################################################################
  # cm_api_setup method
  #####################################################################
  def cm_api_setup(license_key, cluster_name, cdh_version, rack_id, namenodes,
                   datanodes, edgenodes, cmservernodes, hafilernodes, hajournalingnodes, config_state)  
    
    debug=@debug
    server_host=@server_host
    server_port=@server_port
    username=@username
    password=@password
    use_tls=@use_tls
    version=@version
    
    @logger.info("CM - Executing cm-api code") if debug
    
    #--------------------------------------------------------------------
    # Find the cm server. 
    #--------------------------------------------------------------------
    server_host = _find_cm_server(cmservernodes) 
    if not server_host or server_host.empty?
      @logger.info("CM - ERROR: Cannot locate CM server - deferring CM_API setup")
      raise Errno::ECONNREFUSED, "CM - ERROR: Cannot locate CM server"
    else
      #--------------------------------------------------------------------
      # Establish the RESTful API connection. 
      #--------------------------------------------------------------------
      
      api_version = version()
      @logger.info("CM - API version [#{api_version}]") if debug
      
      #--------------------------------------------------------------------
      # Build the cluster configuration data structure with CM role associations.
      #--------------------------------------------------------------------
      cluster_config = _build_roles(debug, cluster_name, namenodes, datanodes, 
                                    edgenodes, cmservernodes, hafilernodes, hajournalingnodes)
      
      #--------------------------------------------------------------------
      # Set the license key if present. 
      #--------------------------------------------------------------------
      @logger.info("CM - checking license key") if debug
      if license_key and not license_key.empty?
        @logger.info("CM - crowbar license key found") if debug
        _check_license_key(debug, license_key, config_state)
      end
      
      #--------------------------------------------------------------------
      # Configure the cluster. 
      #--------------------------------------------------------------------
      cluster_object = _configure_cluster(debug, cluster_name, cdh_version)
      
      #--------------------------------------------------------------------
      # Configure the host instances. 
      #--------------------------------------------------------------------
      _configure_host_instances(debug, rack_id, cluster_config)
      
      #--------------------------------------------------------------------
      # Configure the HDFS service. 
      #--------------------------------------------------------------------
      hdfs_service_name = "hdfs-#{cluster_name}"
      hdfs_service_type = "HDFS"
      hdfs_service = _configure_service(debug, hdfs_service_name, hdfs_service_type, cluster_name, cluster_object)  
      
=begin
      # Note: The v3 API does not support rt_configs and you
      # must use role groups for this case. The v2 API maintains
      # backward compatibility with this call.
      if debug
        result = get_service_config(hdfs_service, 'full')
        svc_config = result[:svc_config]
        rt_configs = result[:rt_configs]
        @logger.info("\n######### svc_config\n#{svc_config}\n")
        @logger.info("\n######### rt_configs\n#{rt_configs}\n")
      end
=end
      hdfs_mount_str = ''  
      if datanodes and not datanodes.empty?
        datanodes.each do |n|
          if n[:fqdn] and not n[:fqdn].empty?
            @logger.info("CM - HDFS mount points for #{n[:fqdn]}") if debug 
            hdfs_mounts = n[:hdfs_mounts]  
            if hdfs_mounts and not hdfs_mounts.empty? 
              hdfs_mount_str = hdfs_mounts.join('/dfs/dn,') + '/dfs/dn'
              @logger.info("CM - [#{hdfs_mount_str}]") if debug  
            end
          end
        end  
      end
      
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
              'dfs_data_dir_list' => hdfs_mount_str # '/data/1/dfs/dn,/data/2/dfs/dn'
      }
      hdfs_gw_config = {
              'dfs_client_use_trash' => true
      }
      hdfs_rt_configs = {
              'NAMENODE' => nn_config,
              'SECONDARYNAMENODE' => snn_config,
              'DATANODE' => dn_config,
              'GATEWAY' => hdfs_gw_config
      }      
      @logger.info("CM - Updating HDFS service configuration") if debug
      result = update_service_config(hdfs_service, hdfs_service_config, hdfs_rt_configs)
      # @logger.info("CM - HDFS service configuration results #{result}") if debug
      
      #--------------------------------------------------------------------
      # Configure the MAPREDUCE service. 
      #--------------------------------------------------------------------
      mapr_service_name = "mapr-#{cluster_name}"
      mapr_service_type = "MAPREDUCE"
      mapr_service = _configure_service(debug, mapr_service_name, mapr_service_type, cluster_name, cluster_object)  
      
      mapr_service_config = {
              'hdfs_service' =>  hdfs_service_name
      }
      jt_config = {
              'jobtracker_mapred_local_dir_list' => '/mapred/jt',
              'mapred_job_tracker_handler_count'=> 40
      }
      tt_config = {
              'tasktracker_mapred_local_dir_list' => '/mapred/local',
              'mapred_tasktracker_map_tasks_maximum' => 10,
              'mapred_tasktracker_reduce_tasks_maximum' => 6
      }
      mapr_gw_config = {
              'mapred_reduce_tasks' => 10,
              'mapred_submit_replication' => 2
      }
      mapr_rt_configs = {
              'JOBTRACKER' => jt_config,
              'TASKTRACKER' => tt_config,
              'GATEWAY' => mapr_gw_config
      }      
      
      @logger.info("CM - Updating MAPR service configuration") if debug
      result = update_service_config(mapr_service, mapr_service_config, mapr_rt_configs)
      # @logger.info("CM - MAPR service configuration results #{result}") if debug
      
      #--------------------------------------------------------------------
      # Apply the cluster roles. 
      #--------------------------------------------------------------------
      _apply_roles(debug, cluster_config, hdfs_service, mapr_service, cluster_name)
      
      #--------------------------------------------------------------------
      #  Format HDFS.
      #--------------------------------------------------------------------
      _format_hdfs(debug, cluster_config, hdfs_service)
      
      #--------------------------------------------------------------------
      # Startup the HDFS service. 
      #--------------------------------------------------------------------
      _start_service(debug, cluster_config, hdfs_service)
      
      #--------------------------------------------------------------------
      # Startup the MAPR service. 
      #--------------------------------------------------------------------
      _start_service(debug, cluster_config, mapr_service)
      
      #--------------------------------------------------------------------
      # Initialize HDFS. 
      #--------------------------------------------------------------------
      _hdfs_init(debug, cluster_config, namenodes)
      
      #--------------------------------------------------------------------
      # Deploy the HDFS client config. 
      #--------------------------------------------------------------------
      _deploy_client_config(debug, cluster_config, hdfs_service, 'HDFS')
      
      #--------------------------------------------------------------------
      # Deploy the MAPREDUCE client config. 
      #--------------------------------------------------------------------
      _deploy_client_config(debug, cluster_config, mapr_service, 'MAPREDUCE')
    end
  end
  
  #####################################################################
  # Deploy the hadoop cluster.
  #####################################################################
  def deploy_cluster(license_key, cluster_name, cdh_version, rack_id, namenodes,
                     datanodes, edgenodes, cmservernodes, hafilernodes, hajournalingnodes)
    retry_count = 1
    deployment_ok = false
    config_state = { :cm_server_restarted => false}
    while (not deployment_ok and retry_count <= 10)
      deployment_ok = true
      begin
        cm_api_setup(license_key, cluster_name, cdh_version, rack_id, namenodes,
                     datanodes, edgenodes, cmservernodes, hafilernodes, hajournalingnodes, config_state)
      rescue Errno::ECONNREFUSED => e
        deployment_ok = false
        @logger.info("CM - Can't connect to the cm-server - sleep and retrying #{retry_count} #{config_state[:cm_server_restarted]}")
        # puts e.message   
        # puts e.backtrace.inspect
        sleep(60)
      end
      retry_count += 1 
    end
    return deployment_ok
  end
end
