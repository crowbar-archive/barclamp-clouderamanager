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
# Note : This code is in development mode and is not full debugged yet.
# It is being exercised through the use of the cm API test harness script 
# and is not currently part of crowbar/clouderamanager barclamp cluster
# deployments. 
# 

libbase = File.dirname(__FILE__)
require "#{libbase}/types.rb"

#######################################################################
# ApiService
#######################################################################
class ApiService < BaseApiObject
  
  ROLETYPES_CFG_KEY = 'roleTypeConfigs'
  
  RO_ATTR = [ 'serviceState', 'healthSummary', 'healthChecks', 'clusterRef',
             'configStale', 'serviceUrl', 'maintenanceMode', 'maintenanceOwners',
             'displayName' ]
  
  RW_ATTR = [ 'name', 'type' ]
  
  #######################################################################
  # initialize(resource_root, name, type)
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #----------------------------------------------------------------------
  # Static methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Create a service
  # @param resource_root: The root Resource object.
  # @param name: Service name
  # @param service_type: Service type
  # @param cluster_name: Cluster name
  # @return: An ApiService object
  #######################################################################
  def self.create_service(resource_root, name, service_type, cluster_name="default")
    dict = { :name => name, :type => service_type } 
    apiservice = ApiService.new(resource_root, dict)
    service_array = [ apiservice ]
    apiservice_list = ApiList.new(service_array)
    data = JSON.generate(apiservice_list.to_json_dict(self))
    path = "/clusters/#{cluster_name}/services"
    resp = resource_root.post(path, data)
    # The server returns a list of created services (size=1).
    return ApiList.from_json_dict(ApiService, resp, resource_root)[0]
  end
  
  #######################################################################
  # Parse a json-decoded ApiServiceConfig dictionary into a 2-tuple.
  # @param json_dic: The json dictionary with the config data.
  # @param view: View to materialize.
  # @return: { :svc_config => svc_config, :rt_configs => rt_configs }
  #######################################################################
  def _parse_svc_config(resource_root, json_dic, view = 'full')
    svc_config = ApiConfig.json_to_config(resource_root, json_dic, view)
    rt_configs = { }
    if json_dic.has_key?(ROLETYPES_CFG_KEY)
      jdict = json_dic[ROLETYPES_CFG_KEY]
      jdict.each do |rt_config|
        rt_key = rt_config['roleType']
        rt_data = ApiConfig.json_to_config(resource_root, rt_config, view)
        rt_configs[rt_key] = rt_data  
      end
    end
    return { :svc_config => svc_config, :rt_configs => rt_configs }
  end
  
  #######################################################################
  # Retrieve the service's configuration.
  # Retrieves both the service configuration and role type configuration
  # for each of the service's supported role types. The role type
  # configurations are returned as a dictionary, whose keys are the
  # role type name, and values are the respective configuration dictionaries.
  # The 'summary' view contains strings as the dictionary values. The full
  # view contains ApiConfig instances as the values.
  # @param view: View to materialize('full' or 'summary')
  # @return: { :svc_config => svc_config, :rt_configs => rt_configs }
  #######################################################################
  def get_config(resource_root, view = nil)
    params = nil 
    params = { :view => view } if (view)
    path = _path() + '/config'
    resp = resource_root.get(path, params)
    return _parse_svc_config(resource_root, resp, view)
  end
  
  #######################################################################
  # Update the service's configuration.
  # Note : Cloudera Manager API v3 (new in 4.5) does not support setting
  # a service's roletype configuration, since that has been replaced by
  # role group. Callers should set the configuration on the appropriate
  # role group instead. Cloudera Manager 4.5 continues to support API v1
  # and v2. But users who want to upgrade their existing clients to v3
  # would need to rewrite any roletype configuration calls.  
  # @param resource_root: The root Resource object.
  # @param svc_config Dictionary with service configuration to update.
  # @param rt_configs Dict of role type configurations to update.
  # @return: { :svc_config => svc_config, :rt_configs => rt_configs }
  #######################################################################
  def update_config(resource_root, svc_config, rt_configs=nil)
    ldata = { }
    if svc_config
      ldata = ApiConfig.config_to_api_list(svc_config)
    end
    
    if rt_configs
      rt_list = [ ]
      rt_configs.each do |rt, cfg|
        rt_data = ApiConfig.config_to_api_list(cfg)
        rt_data['roleType'] = rt
        rt_list << rt_data
      end
      ldata[ROLETYPES_CFG_KEY] = rt_list
    end
    
    path = _path() + '/config'
    data = JSON.generate(ldata)
    print "\n######## #{data}\n"
    resp = resource_root.put(path, data)
    return _parse_svc_config(resource_root, resp)
  end
  
  #######################################################################
  # Lookup a service by name
  # @param resource_root: The root Resource object.
  # @param name: Service name
  # @param cluster_name: Cluster name
  # @return: An ApiService object
  #######################################################################
  def self._get_service(resource_root, path)
    dict = resource_root.get(path)
    return ApiService.from_json_dict(dict, resource_root)
  end
  
  def self.get_service(resource_root, name, cluster_name="default")
    path = "/clusters/#{cluster_name}/services"
    return _get_service(resource_root, "#{path}/#{name}")
  end
  
  #######################################################################
  # Get all services
  # @param resource_root: The root Resource object.
  # @param cluster_name: Cluster name
  # @return: A list of ApiService objects.
  #######################################################################
  def self.get_all_services(resource_root, cluster_name="default", view=nil)
    params = nil 
    params = { :view => view } if (view)
    path = "/clusters/#{cluster_name}/services"
    dict = resource_root.get(path, params)
    return ApiList.from_json_dict(ApiService, dict, resource_root)
  end
  
  #######################################################################
  # Delete a service by name.
  # @param resource_root: The root Resource object.
  # @param name: Service name
  # @param cluster_name: Cluster name
  # @return: The deleted ApiService object
  #######################################################################
  def self.delete_service(resource_root, name, cluster_name="default")
    path = "/clusters/#{cluster_name}/services"
    resp = resource_root.delete("#{path}/#{name}")
    return ApiService.from_json_dict(resp, resource_root)
  end
  
  #----------------------------------------------------------------------
  # Class methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    cname = _get_cluster_name()
    return "<ApiService>: #{@name} (cluster: #{cname})"
  end
  
  #######################################################################
  # _get_cluster_name
  #######################################################################
  def _get_cluster_name
    if @clusterRef
      cname = @clusterRef["clusterName"];
      return cname
    end
    return nil
  end
  
  #######################################################################
  # Return the API path for this service.
  # This method assumes that lack of a cluster reference means that the
  # object refers to the Cloudera Management Services instance.
  #######################################################################
  def _path
    cname =_get_cluster_name() 
    if cname
      return "/clusters/#{cname}/services/#{@name}"
    end
    return '/cm/service'
  end
  
  #######################################################################
  # _cmd(cmd, data=nil, params=nil)
  #######################################################################
  def _cmd(cmd, data=nil, params=nil)
    path = _path() + '/commands/' + cmd
    resp = _get_resource_root().post(path, data, params)
    return ApiCommand.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # _role_cmd(cmd, roles)
  #######################################################################
  def _role_cmd(cmd, roles)
    subpath = _path() + "/roleCommands/#{cmd}"
    rec = { ApiList.LIST_KEY => roles }
    data = JSON.generate(rec)
    resp = _get_resource_root().post(subpath, data)
    return ApiList.from_json_dict(ApiCommand, resp, _get_resource_root())
  end
  
  #######################################################################
  # Retrieve a list of running commands for this service.
  # @param view: View to materialize('full' or 'summary')
  # @return: A list of running commands.
  #######################################################################
  def get_commands(view=nil)
    params = nil 
    params = { :view => view } if (view)
    path = _path() + '/commands'
    resource_root = _get_resource_root()
    resp = resource_root.get(path)
    return ApiList.from_json_dict(ApiCommand, resp, resource_root)
  end
  
  #######################################################################
  # get_running_activities
  #######################################################################
  def get_running_activities
    path = _path() + '/activities'
    resource_root = _get_resource_root()
    resp = resource_root.get(path)
    return ApiList.from_json_dict(ApiActivity, resp, resource_root)
  end
  
  #######################################################################
  # query_activities(query_str=nil)
  #######################################################################
  def query_activities(query_str=nil)
    params = { }
    if query_str
      params['query'] = query_str
    end
    path = _path() + '/activities'
    resource_root = _get_resource_root()
    resp = resource_root.get(path, params)
    return ApiList.from_json_dict(ApiActivity, resp, resource_root)
  end
  
  #######################################################################
  # get_activity(job_id)
  #######################################################################
  def get_activity(job_id)
    path = _path() + "/activities/#{job_id}"
    resource_root = _get_resource_root()
    resp = resource_root.get(path)
    return ApiActivity.from_json_dict(resp, resource_root)
  end
  
  #----------------------------------------------------------------------
  # Role related methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Create a role.
  # @param resource_root Resource root object.
  # @param role_name: Role name
  # @param role_type: Role type
  # @param host_id: ID of the host to assign the role to
  # @return: An ApiRole object
  #######################################################################
  def create_role(resource_root, role_name, role_type, host_id)
    return ApiRole.create_role(resource_root, @name, role_type, role_name, host_id, _get_cluster_name())
  end
  
  #######################################################################
  # Delete a role by name.
  # @param resource_root Resource root object.
  # @param name Role name
  # @return The deleted ApiRole object
  #######################################################################
  def delete_role(resource_root, name)
    return ApiRole.delete_role(resource_root, @name, name, _get_cluster_name())
  end
  
  #######################################################################
  # Lookup a role by name.
  # @param resource_root Resource root object.
  # @param name: Role name
  # @return: An ApiRole object
  #######################################################################
  def get_role(resource_root, name)
    return ApiRole.get_role(resource_root, @name, name, _get_cluster_name())
  end
  
  #######################################################################
  # Get all roles in the service.
  # @param resource_root Resource root object.
  # @param view: View to materialize('full' or 'summary')
  # @return: A list of ApiRole objects.
  #######################################################################
  def get_all_roles(resource_root, view = nil)
    return ApiRole.get_all_roles(resource_root, @name, _get_cluster_name(), view)
  end
  
  #######################################################################
  # Get all roles of a certain type in a service.
  # @param resource_root Resource root object.
  # @param role_type: Role type
  # @param view: View to materialize('full' or 'summary')
  # @return: A list of ApiRole objects.
  #######################################################################
  def get_roles_by_type(resource_root, role_type, view = nil)
    return ApiRole.get_roles_by_type(resource_root, @name, role_type, _get_cluster_name(), view)
  end
  
  #######################################################################
  # Get a list of role types in a service.
  # @param resource_root Resource root object.
  # @return: A list of role types(strings)
  #######################################################################
  def get_role_types(resource_root)
    path = _path() + '/roleTypes'
    resp = resource_root.get(path)
    return resp[ApiList.LIST_KEY]
  end
  
  #----------------------------------------------------------------------
  # End of Role related methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Retrieve metric readings for the service.
  # @param from_time: A datetime; start of the period to query(optional).
  # @param to_time: A datetime; end of the period to query(default = now).
  # @param metrics: List of metrics to query(default = all).
  # @param view: View to materialize('full' or 'summary')
  # @return List of metrics and their readings.
  #######################################################################
  def get_metrics(from_time=nil, to_time=nil, metrics=nil, view=nil)
    resource_root = _get_resource_root()
    path = _path() + '/metrics'
    return resource_root.get_metrics(path, from_time, to_time, metrics, view)
  end
  
  #######################################################################
  # Start a service.
  # @return Reference to the submitted command.
  #######################################################################
  def start
    return _cmd('start')
  end
  
  #######################################################################
  # Stop a service.
  # @return Reference to the submitted command.
  #######################################################################
  def stop
    return _cmd('stop')
  end
  
  #######################################################################
  # Restart a service.
  # @return Reference to the submitted command.
  #######################################################################
  def restart
    return _cmd('restart')
  end
  
  #######################################################################
  # Start a list of roles.
  # @param role_names: names of the roles to start.
  # @return: List of submitted commands.
  #######################################################################
  def start_roles(*role_names)
    return _role_cmd('start', role_names)
  end
  
  #######################################################################
  # Stop a list of roles.
  # @param role_names: names of the roles to stop.
  # @return: List of submitted commands.
  #######################################################################
  def stop_roles(*role_names)
    return _role_cmd('stop', role_names)
  end
  
  #######################################################################
  # Restart a list of roles.
  # @param role_names: names of the roles to restart.
  # @return: List of submitted commands.
  #######################################################################
  def restart_roles(*role_names)
    return _role_cmd('restart', role_names)
  end
  
  #######################################################################
  # Bootstrap HDFS stand-by NameNodes.
  # Initialize their state by syncing it with the respective HA partner.
  # @param role_names: NameNodes to bootstrap.
  # @return: List of submitted commands.
  #######################################################################
  def bootstrap_hdfs_stand_by(*role_names)
    return _role_cmd('hdfsBootstrapStandBy', role_names)
  end
  
  #######################################################################
  # Create the Beeswax role's warehouse for a Hue service.
  # @return: Reference to the submitted command.
  #######################################################################
  def create_beeswax_warehouse
    return _cmd('hueCreateHiveWarehouse')
  end
  
  #######################################################################
  # Create the root directory of an HBase service.
  # @return Reference to the submitted command.
  #######################################################################
  def create_hbase_root
    return _cmd('hbaseCreateRoot')
  end
  
  #######################################################################
  # Execute the "refresh" command on a set of roles.
  # @param: role_names Names of the roles to refresh.
  # @return: Reference to the submitted command.
  #######################################################################
  def refresh(role_names)
    return _role_cmd('refresh', role_names)
  end
  
  #######################################################################
  # Decommission roles in a service.
  # @param role_names Names of the roles to decommission.
  # @return Reference to the submitted command.
  #######################################################################
  def decommission(role_names)
    data = JSON.generate({ ApiList.LIST_KEY => role_names })
    return _cmd('decommission', data)
  end
  
  #######################################################################
  # Recommission roles in a service.
  # @param role_names Names of the roles to recommission.
  # @return Reference to the submitted command.
  # @since: API v2
  #######################################################################
  def recommission(role_names)
    data = JSON.generate({ ApiList.LIST_KEY => role_names })
    return _cmd('recommission', data)
  end
  
  #######################################################################
  # Deploys client configuration to the hosts where roles are running.
  # @param: role_names Names of the roles to decommission.
  # @return: Reference to the submitted command.
  #######################################################################
  def deploy_client_config(role_names)
    dict = { ApiList.LIST_KEY => role_names }
    data = JSON.generate(dict)
    return _cmd('deployClientConfig', data)
  end
  
  #######################################################################
  # Disable auto-failover for a highly available HDFS nameservice.
  # @param nameservice: Affected nameservice.
  # @return: Reference to the submitted command.
  #######################################################################
  def disable_hdfs_auto_failover(nameservice)
    data = JSON.generate(nameservice)
    return _cmd('hdfsDisableAutoFailover', data)
  end
  
  #######################################################################
  # Disable high availability for an HDFS NameNode.
  # @param active_name: Name of the NameNode to keep.
  # @param secondary_name: Name of(existing) SecondaryNameNode to link to
  # remaining NameNode.
  # @param start_dependent_services: whether to re-start dependent services.
  # @param deploy_client_configs: whether to re-deploy client configurations.
  # @param disable_quorum_storage: whether to disable Quorum-based Storage. Available since API v2.
  # Quorum-based Storage will be disabled for all
  # nameservices that have Quorum-based Storage
  # enabled.
  # @return: Reference to the submitted command.
  #######################################################################
  def disable_hdfs_ha(active_name, secondary_name,
                      start_dependent_services=true, deploy_client_configs=true,
                      disable_quorum_storage=false)
    args = {
      activeName => active_name,
      secondaryName => secondary_name,
      startDependentServices => start_dependent_services,
      deployClientConfigs => deploy_client_configs
    }
    
    version = _get_resource_root().version
    
    if version < 2
      if disable_quorum_storage
        raise AttributeError.new("Quorum-based Storage.not_equal? supported prior to Cloudera Manager 4.1.")
      end
    else
      args['disableQuorumStorage'] = disable_quorum_storage
    end
    
    return _cmd('hdfsDisableHa', data = JSON.generate(args))
  end
  
  #######################################################################
  # Enable auto-failover for an HDFS nameservice.
  # @param nameservice: Nameservice for which to enable auto-failover.
  # @param active_fc_name: Name of failover controller to create for active node.
  # @param standby_fc_name: Name of failover controller to create for stand-by node.
  # @param zk_service: ZooKeeper service to use.
  # @return: Reference to the submitted command.
  #######################################################################
  def enable_hdfs_auto_failover(nameservice, active_fc_name, standby_fc_name, zk_service)
    args = {
      nameservice => nameservice,
      activeFCName => active_fc_name,
      standByFCName => standby_fc_name,
      zooKeeperService => {
        clusterName => zk_service.clusterRef.clusterName,
        serviceName => zk_service.name
      }
    }
    data = JSON.generate(args)
    return _cmd('hdfsEnableAutoFailover', data)
  end
  
  #######################################################################
  # Enable high availability for an HDFS NameNode.
  # @param active_name: name of active NameNode.
  # @param active_shared_path: shared edits path for active NameNode.
  # Ignored if Quorum-based Storage is being enabled.
  # @param standby_name: name of stand-by NameNode.
  # @param standby_shared_path: shared edits path for stand-by NameNode.
  # Ignored if Quourm Journal is being enabled.
  # @param nameservice: nameservice for the HA pair.
  # @param start_dependent_services: whether to re-start dependent services.
  # @param deploy_client_configs: whether to re-deploy client configurations.
  # @param enable_quorum_storage: whether to enable Quorum-based Storage. Available since API v2.
  # Quorum-based Storage will be enabled for all
  # nameservices except those configured with NFS High
  # Availability.
  # @return: Reference to the submitted command.
  #######################################################################
  def enable_hdfs_ha(active_name, active_shared_path, standby_name,
                     standby_shared_path, nameservice, start_dependent_services=true,
                     deploy_client_configs=true, enable_quorum_storage=false)
    args = { 
      activeName => active_name,
      standByName => standby_name,
      nameservice => nameservice,
      startDependentServices => start_dependent_services,
      deployClientConfigs => deploy_client_configs
    }
    
    if enable_quorum_storage
      version = _get_resource_root().version
      if version < 2
        raise AttributeError.new("Quorum-based Storage.not_equal? supported prior to Cloudera Manager 4.1.")
      else
        args['enableQuorumStorage'] = enable_quorum_storage
      end
    else
      if active_shared_path.equal? nil or standby_shared_path.equal? nil
        raise AttributeError.new("Active and standby shared paths must be specified if not enabling Quorum-based Storage")
      end
      args['activeSharedEditsPath'] = active_shared_path
      args['standBySharedEditsPath'] = standby_shared_path
    end
    
    return _cmd('hdfsEnableHa', data = JSON.generate(args))
  end
  
  #######################################################################
  # Initiate a failover of an HDFS NameNode HA pair.
  # This will make the given stand-by NameNode active, and vice-versa.
  # @param active_name: name of currently active NameNode.
  # @param standby_name: name of NameNode currently in stand-by.
  # @param force: whether to force failover.
  # @return: Reference to the submitted command.
  #######################################################################
  def failover_hdfs(active_name, standby_name, force=false)
    if force
      params = { "force" => "true" }
    else
      params = { "force" => "false" }
    end
    args = { ApiList.LIST_KEY => [ active_name, standby_name ] }
    data = JSON.generate(args)
    return _cmd('hdfsFailover', data)
  end
  
  #######################################################################
  # Format NameNode instances of an HDFS service.
  # 
  # @param namenodes Name of NameNode instances to format.
  # @return List of submitted commands.
  #######################################################################
  def format_hdfs(namenodes)
    return _role_cmd('hdfsFormat', namenodes)
  end
  
  #######################################################################
  # Initialize HDFS failover controller metadata.
  # Only one controller per nameservice needs to be initialized.
  # @param controllers: Name of failover controller instances to initialize.
  # @return: List of submitted commands.
  #######################################################################
  def init_hdfs_auto_failover(*controllers)
    return _role_cmd('hdfsInitializeAutoFailover', controllers)
  end
  
  #######################################################################
  # Initialize a NameNode's shared edits directory.
  # @param namenodes Name of NameNode instances.
  # @return List of submitted commands.
  #######################################################################
  def init_hdfs_shared_dir(*namenodes)
    return _role_cmd('hdfsInitializeSharedDir', namenodes)
  end
  
  #######################################################################
  # Cleanup a ZooKeeper service or roles.
  # If no server role names are provided, the command applies to the whole
  # service, and cleans up all the server roles that are currently running.
  # @param servers: ZK server role names(optional).
  # @return: Command reference(for service command) or list of command
  # references(for role commands).
  #######################################################################
  def cleanup_zookeeper(*servers)
    if servers
      return _role_cmd('zooKeeperCleanup', servers)
    end
    return _cmd('zooKeeperCleanup')
  end
  
  #######################################################################
  # Initialize a ZooKeeper service or roles.
  # If no server role names are provided, the command applies to the whole
  # service, and initializes all the configured server roles.
  # @param servers: ZK server role names(optional).
  # @return: Command reference(for service command) or list of command
  # references(for role commands).
  #######################################################################
  def init_zookeeper(*servers)
    if servers
      return _role_cmd('zooKeeperInit', servers)
    end
    return _cmd('zooKeeperInit')
  end
  
  #######################################################################
  # Synchronize the Hue server's database.
  # @param: servers Name of Hue Server roles to synchronize.
  # @return: List of submitted commands.
  #######################################################################
  def sync_hue_db(*servers)
    return _role_cmd('hueSyncDb', servers)
  end
  
  #######################################################################
  # Put the service in maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def enter_maintenance_mode
    cmd = _cmd('enterMaintenanceMode')
    if cmd.success
      _update(_get_service(_get_resource_root(), _path()))
    end
    return cmd
  end
  
  #######################################################################
  # Take the service out of maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def exit_maintenance_mode
    cmd = _cmd('exitMaintenanceMode')
    if cmd.success
      _update(_get_service(_get_resource_root(), _path()))
    end
    return cmd
  end
end

#######################################################################
# ApiServiceSetupInfo
#######################################################################
class ApiServiceSetupInfo < ApiService
  
  RO_ATTR = []
  
  RW_ATTR = ['name', 'type', 'config', 'roles']
  
  def __init__(name=nil, type=nil,config=nil, roles=nil)
    
    # The BaseApiObject expects a resource_root, which we don't care about
    resource_root = nil
    # Unfortunately, the json key.equal? called "type". So our input arg
    # needs to be called "type" as well, despite it being a keyword.
    BaseApiObject.ctor_helper(locals(self))
  end
  
  #######################################################################
  # Set the service configuration.
  # @param config: A dictionary of config key/value
  #######################################################################
  def set_config(config)
    if @config.equal? nil
      @config = { }
    end
    @config.update(config_to_api_list(config))
  end
  
  #######################################################################
  # Add a role type setup info.
  # @param role_type: Role type
  # @param config: A dictionary of role type configuration
  #######################################################################
  def add_role_type_info(role_type, config)
    rt_config = config_to_api_list(config)
    rt_config['roleType'] = role_type
    
    if @config.equal? nil
      @config = { }
    end
    if not @config.has_key(ROLETYPES_CFG_KEY)
      @config[ROLETYPES_CFG_KEY] = [ ]
    end
    @config[ROLETYPES_CFG_KEY].append(rt_config)
  end
  
  #######################################################################
  # Add a role info. The role will be created along with the service setup.
  # @param role_name: Role name
  # @param role_type: Role type
  # @param host_id: The host where the role should run
  # @param config:(Optional) A dictionary of role config values
  #######################################################################
  def add_role_info(role_name, role_type, host_id, config=nil)
    if @roles.equal? nil
      @roles = [ ]
    end
    if (config)
      api_config_list = config_to_api_list(config)
    else
      api_config_list = nil
    end
    @roles.append({
        'name' => role_name,
        'type' => role_type,
        'hostRef' => { 'hostId' => host_id },
        'config' => api_config_list })
  end
end
