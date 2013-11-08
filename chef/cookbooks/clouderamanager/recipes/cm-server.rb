#
# Cookbook Name: clouderamanager
# Recipe: cm-server.rb
#
# Copyright (c) 2011 Dell Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License")
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

#######################################################################
# Setup the postgresql or mysql server for CM management.
#######################################################################
db_type = node[:clouderamanager][:server][:db_type]
if db_type == 'postgresql'
  include_recipe 'clouderamanager::postgresql'
elsif db_type == 'mysql'
  include_recipe 'clouderamanager::mysql'
else
  Chef::Log.error("CM - Invalid server db_type #{db_type}")
end

#######################################################################
# Cloudera Manager needs to have this directory present. Without it,
# the slave node installation will fail. This is an empty directory and the
# RPM package installer does not seem to create it.
#######################################################################
directory "/usr/share/cmf/packages" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

#######################################################################
# Define the Cloudera Manager server service.
# cloudera-scm-server {start|stop|restart|status}
#######################################################################
service "cloudera-scm-server" do
  supports :start => true, :stop => true, :restart => true, :status => true 
  action :enable 
end

#######################################################################
# Define the Cloudera Manager database service.
# cloudera-scm-server-db {start|stop|restart|status|initdb}
#######################################################################
service "cloudera-scm-server-db" do
  supports :start => true, :stop => true, :restart => true, :status => true 
  action :enable 
end

#######################################################################
# Setup the CM server.
# This will only execute if the db is uninitialized, otherwise it returns 1. 
# /var/lib/cloudera-scm-server-db/data is non-empty; perhaps the database
# was already initialized?
#######################################################################
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

#######################################################################
# Add the cloudera manager link to the crowbar UI.
#######################################################################
server_ip = nil
cmservernodes = node[:hadoop_infrastructure][:cluster][:cmservernodes]
if cmservernodes and cmservernodes.length > 0 
  rec = cmservernodes[0]
  server_ip = rec[:ipaddr]
end
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
# The CM API automatic configuration feature is current disabled by
# default. You must enable it in crowbar before queuing the proposal.
# If this feature is disabled, you must configure the cluster manually
# using the CM user interface.
# Note : This runs in the chef deferred processing phase (enclosed in
# a ruby_block) because it requires the cm-server to be installed and
# running at the point of execution.
#######################################################################

if node[:clouderamanager][:cmapi][:deployment_type] == 'auto' and not node[:clouderamanager][:cluster][:cm_api_configured]
  ruby_block "cm-api-deferred-execution" do
    block do
      libbase = File.join(File.dirname(__FILE__), '../libraries' )
      require "#{libbase}/api_client.rb"
      require "#{libbase}/utils.rb"
      
      #####################################################################
      # Find the cm_server.
      #####################################################################
      def find_cm_server(debug, env_filter, node_object)
        cmservernodes = node_object[:hadoop_infrastructure][:cluster][:cmservernodes]
        if cmservernodes and cmservernodes.length > 0 
          rec = cmservernodes[0]
          return rec[:ipaddr]
        end
        return nil
      end
      
      #####################################################################
      # Role appender helper method.
      #####################################################################
      def role_appender(debug, cluster_config, cluster_name, counter_map, cb_nodes, service_type, role_type)
        if cb_nodes  
          cb_nodes.each do |n|
            counter_map[role_type] = 1 if counter_map[role_type].nil?
            cnt = sprintf("%2.2d", counter_map[role_type])
            role_name = "#{role_type}-#{cluster_name}-#{cnt}"
            # Check for role duplication on this node and skip if the role is already there.
            skip_role_insertion = false
            cluster_config.each do |r|
              if r[:host_id] == n[:fqdn] and r[:role_type] == role_type
                skip_role_insertion = true
                break
              end
            end
            if skip_role_insertion
              Chef::Log.info("CM - #{role_type} role duplicated on node #{n[:fqdn]}, skipping role insertion") if debug
            else
              rec = { :host_id => n[:fqdn], :name => n[:name], :role_type => role_type, :role_name => role_name, :service_type => service_type, :ipaddr => n[:ipaddr] }
              Chef::Log.info("CM - cluster_config add [#{rec.inspect}]") if debug
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
      def build_roles(debug, cluster_name, namenodes, datanodes, edgenodes, cmservernodes, hafilernodes, hajournalingnodes)
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
          role_appender(debug, config, cluster_name, counter_map, primary_namenode, "HDFS", 'GATEWAY')
        end
        # secondary namenode
        if namenodes.length > 1
          secondary_namenode = [ namenodes[1] ]
          role_appender(debug, config, cluster_name, counter_map, secondary_namenode, "HDFS", 'SECONDARYNAMENODE')
          role_appender(debug, config, cluster_name, counter_map, secondary_namenode, "HDFS", 'GATEWAY')
        end
        # datanodes
        role_appender(debug, config, cluster_name, counter_map, datanodes, "HDFS", 'DATANODE')
        role_appender(debug, config, cluster_name, counter_map, datanodes, "MAPREDUCE", 'TASKTRACKER')
        role_appender(debug, config, cluster_name, counter_map, datanodes, "HDFS", 'GATEWAY')
        # edgenodes
        if edgenodes.length > 0
          role_appender(debug, config, cluster_name, counter_map, edgenodes, "HDFS", 'GATEWAY')
        end
        # hafilernodes
        if hafilernodes.length > 0
          role_appender(debug, config, cluster_name, counter_map, hafilernodes, "HDFS", 'GATEWAY')
        end
        # hajournalingnodes
        if hajournalingnodes.length > 0
          role_appender(debug, config, cluster_name, counter_map, hajournalingnodes, "HDFS", 'GATEWAY')
        end
        Chef::Log.info("CM - cluster configuration [#{config.inspect}]") if debug
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
      # Check the license key and update if needed.
      # Note: get_license will report nil until the cm-server has been restarted.
      #####################################################################
      def check_license_key(debug, api, cb_license_key, config_state)
        # cm_license_key = ApiLicense object - owner, uuid, expiration
        cm_license_key = api.get_license()
        cm_uuid = nil
        if cm_license_key
          cm_uuid = cm_license_key.getattr('uuid')
        end
        if cm_uuid and not cm_uuid.empty?
          Chef::Log.info("CM - existing CM license key found [#{cm_uuid}]") if debug
        else
          Chef::Log.info("CM - no existing CM license key") if debug
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
          Chef::Log.info("CM - CB license is present [#{cb_uuid}]") if debug
          # If CM license is not already active or license key has changed.
          if cm_uuid.nil? or cm_uuid.empty? or cb_uuid != cm_uuid
            Chef::Log.info("CM - updating license cm_uuid=#{cm_uuid} cb_uuid=#{cb_uuid}") if debug
            # Update the license. 
            api_license = api.update_license(cb_license_key)
            if not config_state[:cm_server_restarted]
              # Restart the cm server to activate.
              Chef::Log.info("CM - restarting cm-server") if debug
              output = %x{service cloudera-scm-server restart}
              if $?.exitstatus != 0
                Chef::Log.error("cloudera-scm-server restart failed #{output}")
              else
                Chef::Log.info("CM - cm-server restarted #{output}") if debug
                config_state[:cm_server_restarted] = true
              end
            end
          else
            Chef::Log.info("CM - license update NOT required cm_uuid=#{cm_uuid} cb_uuid=#{cb_uuid}") if debug
          end
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
      # Configure the hosts.
      #####################################################################
      def configure_host_instances(debug, api, rack_id, cluster_config)
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
      # Configure the services.
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
      # Apply the roles.
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
      
      #--------------------------------------------------------------------
      # Initialize HDFS.
      # HDFS format does not cover all the initialization cases.
      #--------------------------------------------------------------------
      def hdfs_init(debug, node)
        namenodes = node[:hadoop_infrastructure][:cluster][:namenodes]
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
          Chef::Log.info("CM - execute #{sucmd}") if debug
          if system(sucmd)
            Chef::Log.info("CM - SUCCESS [#{$?}]") if debug
          else
            Chef::Log.error("CM - ERROR [#{$?}]")
          end
        end
      end
      
      #####################################################################
      # cm_api_setup method
      #####################################################################
      def cm_api_setup(debug, env_filter, node, retry_count, config_state)  
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
        rack_id = node[:clouderamanager][:cluster][:rack_id] 
        
        #--------------------------------------------------------------------
        # CB node information (each item is an array of records).
        #--------------------------------------------------------------------
        namenodes = node[:hadoop_infrastructure][:cluster][:namenodes] 
        datanodes = node[:hadoop_infrastructure][:cluster][:datanodes]
        edgenodes = node[:hadoop_infrastructure][:cluster][:edgenodes] 
        cmservernodes = node[:hadoop_infrastructure][:cluster][:cmservernodes]
        hafilernodes = node[:hadoop_infrastructure][:cluster][:hafilernodes] 
        hajournalingnodes = node[:hadoop_infrastructure][:cluster][:hajournalingnodes] 
        
        #--------------------------------------------------------------------
        # Find the cm server. 
        #--------------------------------------------------------------------
        server_host = find_cm_server(debug, env_filter, node) 
        if not server_host or server_host.empty?
          Chef::Log.info("CM - ERROR: Cannot locate CM server - deferring CM_API setup")
          raise Errno::ECONNREFUSED, "CM - ERROR: Cannot locate CM server"
        else
          #--------------------------------------------------------------------
          # Establish the RESTful API connection. 
          #--------------------------------------------------------------------
          api = create_api_resource(debug, server_host, server_port, username, password, use_tls, version) 
          if not api
            Chef::Log.info("CM - ERROR: Cannot create CM API resource - deferring CM_API setup")
            raise Errno::ECONNREFUSED, "CM - ERROR: Cannot create CM API resource"
          else
            #--------------------------------------------------------------------
            # Build the cluster configuration data structure with CM role associations.
            #--------------------------------------------------------------------
            cluster_config = build_roles(debug, cluster_name, namenodes, datanodes, edgenodes, cmservernodes, hafilernodes, hajournalingnodes)
            
            #--------------------------------------------------------------------
            # Set the license key if present. 
            #--------------------------------------------------------------------
            Chef::Log.info("CM - checking license key") if debug
            if license_key and not license_key.empty?
              Chef::Log.info("CM - crowbar license key found") if debug
              check_license_key(debug, api, license_key, config_state)
            end
            
            #--------------------------------------------------------------------
            # Configure the cluster. 
            #--------------------------------------------------------------------
            cluster_object = configure_cluster(debug, api, cluster_name, cdh_version)
            
            #--------------------------------------------------------------------
            # Configure the host instances. 
            #--------------------------------------------------------------------
            configure_host_instances(debug, api, rack_id, cluster_config)
            
            #--------------------------------------------------------------------
            # Configure the HDFS service. 
            #--------------------------------------------------------------------
            hdfs_service_name = "hdfs-#{cluster_name}"
            hdfs_service_type = "HDFS"
            hdfs_service = configure_service(debug, api, hdfs_service_name, hdfs_service_type, cluster_name, cluster_object)  
            
=begin
      # Note: The v3 API does not support rt_configs and you
      # must use role groups for this case. The v2 API maintains
      # backward compatibility with this call.
      if debug
        result = api.get_service_config(hdfs_service, 'full')
        svc_config = result[:svc_config]
        rt_configs = result[:rt_configs]
        Chef::Log.info("\n######### svc_config\n#{svc_config}\n")
        Chef::Log.info("\n######### rt_configs\n#{rt_configs}\n")
      end
=end
            hdfs_mount_str = ''  
            if datanodes and not datanodes.empty?
              datanodes.each do |n|
                if n[:fqdn] and not n[:fqdn].empty?
                  Chef::Log.info("CM - HDFS mount points for #{n[:fqdn]}") if debug 
                  hdfs_mounts = n[:hdfs_mounts]  
                  if hdfs_mounts and not hdfs_mounts.empty? 
                    hdfs_mount_str = hdfs_mounts.join('/dfs/dn,') + '/dfs/dn'
                    Chef::Log.info("CM - [#{hdfs_mount_str}]") if debug  
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
            Chef::Log.info("CM - Updating HDFS service configuration") if debug
            result = api.update_service_config(hdfs_service, hdfs_service_config, hdfs_rt_configs)
            # Chef::Log.info("CM - HDFS service configuration results #{result}") if debug
            
            #--------------------------------------------------------------------
            # Configure the MAPREDUCE service. 
            #--------------------------------------------------------------------
            mapr_service_name = "mapr-#{cluster_name}"
            mapr_service_type = "MAPREDUCE"
            mapr_service = configure_service(debug, api, mapr_service_name, mapr_service_type, cluster_name, cluster_object)  
            
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
            Chef::Log.info("CM - Updating MAPR service configuration") if debug
            result = api.update_service_config(mapr_service, mapr_service_config, mapr_rt_configs)
            # Chef::Log.info("CM - MAPR service configuration results #{result}") if debug
            
            #--------------------------------------------------------------------
            # Apply the cluster roles. 
            #--------------------------------------------------------------------
            apply_roles(debug, api, hdfs_service, mapr_service, cluster_name, cluster_config)
            
            #--------------------------------------------------------------------
            # Format HDFS. 
            #--------------------------------------------------------------------
            cluster_config.each do |r|
              if r[:role_type] == 'NAMENODE'
                role_name = r[:role_name] 
                Chef::Log.info("CM - Attempting HDFS format #{role_name}") if debug
                cmd_array = api.format_hdfs(hdfs_service, [ role_name ])
                cmd = cmd_array[0]
                id = cmd.getattr('id')
                active = cmd.getattr('active')
                success = cmd.getattr('success')
                msg = cmd.getattr('resultMessage')
                Chef::Log.info("CM - Waiting for HDFS format [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
                cmd_timeout = 300 
                wcmd = api.wait_for_cmd(cmd, cmd_timeout)
                id = wcmd.getattr('id')
                active = wcmd.getattr('active')
                success = wcmd.getattr('success')
                msg = wcmd.getattr('resultMessage')
                Chef::Log.info("CM - HDFS format results [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
                # If we timeout and the command is still running, try again later
                if active
                  msg = "CM - HDFS format is running asynchronously in the background, trying again later"
                  Chef::Log.info(msg) if debug
                  raise Errno::ECONNREFUSED, msg
                end
              end
            end
            
            #--------------------------------------------------------------------
            # Startup the HDFS service. 
            #--------------------------------------------------------------------
            Chef::Log.info("CM - Attempting HDFS service startup") if debug
            cmd = api.start_service(hdfs_service)
            id = cmd.getattr('id')
            active = cmd.getattr('active')
            success = cmd.getattr('success')
            msg = cmd.getattr('resultMessage')
            Chef::Log.info("CM - Waiting for HDFS service startup [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
            cmd_timeout = 300
            wcmd = api.wait_for_cmd(cmd, cmd_timeout)
            id = wcmd.getattr('id')
            active = wcmd.getattr('active')
            success = wcmd.getattr('success')
            msg = wcmd.getattr('resultMessage')
            Chef::Log.info("CM - HDFS service startup results [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
            # If we timeout and the command is still running, try again later
            if active
              msg = "CM - HDFS service startup is running asynchronously in the background, trying again later"
              Chef::Log.info(msg) if debug
              raise Errno::ECONNREFUSED, msg
            end
            
            #--------------------------------------------------------------------
            # Deploy HDFS client config. 
            #--------------------------------------------------------------------
            role_list = [] 
            cluster_config.each do |r|
              if r[:service_type] == 'HDFS'
                role_list << r[:role_name] 
              end
            end 
            if role_list and not role_list.empty?
              Chef::Log.info("CM - Attempting HDFS config deployment #{role_list.join(",")}") if debug
              cmd = api.deploy_client_config(hdfs_service, role_list)
              id = cmd.getattr('id')
              active = cmd.getattr('active')
              success = cmd.getattr('success')
              msg = cmd.getattr('resultMessage')
              Chef::Log.info("CM - Waiting for HDFS config deployment [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
              cmd_timeout = 300
              wcmd = api.wait_for_cmd(cmd, cmd_timeout)
              id = wcmd.getattr('id')
              active = wcmd.getattr('active')
              success = wcmd.getattr('success')
              msg = wcmd.getattr('resultMessage')
              Chef::Log.info("CM - HDFS config deployment results [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
              # If we timeout and the command is still running, try again later
              if active
                msg = "CM - HDFS configuration deployment is running asynchronously in the background, trying again later"
                Chef::Log.info(msg) if debug
                raise Errno::ECONNREFUSED, msg
              end
            end
            
            #--------------------------------------------------------------------
            # Initialize HDFS. 
            #--------------------------------------------------------------------
            hdfs_init(debug, node)
            
            #--------------------------------------------------------------------
            # Startup the MAPR service. 
            #--------------------------------------------------------------------
            Chef::Log.info("CM - Attempting MAPR service startup") if debug
            cmd = api.start_service(mapr_service)
            id = cmd.getattr('id')
            active = cmd.getattr('active')
            success = cmd.getattr('success')
            msg = cmd.getattr('resultMessage')
            Chef::Log.info("CM - Waiting for MAPR service startup [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
            cmd_timeout = 300
            wcmd = api.wait_for_cmd(cmd, cmd_timeout)
            id = wcmd.getattr('id')
            active = wcmd.getattr('active')
            success = wcmd.getattr('success')
            msg = wcmd.getattr('resultMessage')
            Chef::Log.info("CM - MAPR service startup results [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
            # If we timeout and the command is still running, try again later
            if active
              msg = "CM - MAPR service startup is running asynchronously in the background, trying again later"
              Chef::Log.info(msg) if debug
              raise Errno::ECONNREFUSED, msg
            end
            
            #--------------------------------------------------------------------
            # Deploy MAPR client config. 
            #--------------------------------------------------------------------
            role_list = [] 
            cluster_config.each do |r|
              if r[:service_type] == 'MAPREDUCE'
                role_list << r[:role_name] 
              end
            end 
            if role_list and not role_list.empty?
              Chef::Log.info("CM - Attempting MAPR config deployment #{role_list.join(",")}") if debug
              cmd = api.deploy_client_config(mapr_service, role_list)
              id = cmd.getattr('id')
              active = cmd.getattr('active')
              success = cmd.getattr('success')
              msg = cmd.getattr('resultMessage')
              Chef::Log.info("CM - Waiting for MAPR config deployment [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
              cmd_timeout = 300 
              wcmd = api.wait_for_cmd(cmd, cmd_timeout)
              id = wcmd.getattr('id')
              active = wcmd.getattr('active')
              success = wcmd.getattr('success')
              msg = wcmd.getattr('resultMessage')
              Chef::Log.info("CM - MAPR config deployment results [id:#{id}, active:#{active}, success:#{success}, msg:#{msg}]") if debug
              # If we timeout and the command is still running, try again later
              if active
                msg = "CM - MAPR configuration deployment is running asynchronously in the background, trying again later"
                Chef::Log.info(msg) if debug
                raise Errno::ECONNREFUSED, msg
              end
            end
          end
        end
      end
      
      #####################################################################
      # CM API MAIN
      # Wait for the cm-server to respond and run the cm-api setup code.
      # Note : This runs in the chef deferred processing phase (enclosed in
      # a ruby_block) because it requires the cm-server to be installed and
      # running at the point of execution.
      #####################################################################
      retry_count = 1
      connection_ok = false
      config_state = { :cm_server_restarted => false}
      while (not connection_ok and retry_count <= 10)
        connection_ok = true
        Chef::Log.info("CM - Executing cm-api code") if debug
        begin
          cm_api_setup(debug, env_filter, node, retry_count, config_state)
        rescue Errno::ECONNREFUSED => e
          connection_ok = false
          Chef::Log.info("CM - Can't connect to the cm-server - sleep and retrying #{retry_count} #{config_state[:cm_server_restarted]}")
          # puts e.message   
          # puts e.backtrace.inspect
          sleep(60)
        end
        retry_count += 1 
      end
      
      if (not connection_ok)
        Chef::Log.info("CM - Giving up on cm-server connection - will try again later")
        node[:clouderamanager][:cluster][:cm_api_configured] = false
        node.save 
      else
        node[:clouderamanager][:cluster][:cm_api_configured] = true
        node.save 
      end
    end
  end
else
  Chef::Log.info("CM - Automatic CM API feature is disabled") if debug
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-server") if debug
