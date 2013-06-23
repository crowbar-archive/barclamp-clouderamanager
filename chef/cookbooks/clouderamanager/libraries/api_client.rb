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

require 'rubygems'
require 'restclient'

libbase = File.dirname(__FILE__)
require "#{libbase}/resource.rb"
require "#{libbase}/clusters.rb"
require "#{libbase}/cms.rb"
require "#{libbase}/events.rb"
require "#{libbase}/hosts.rb"
require "#{libbase}/roles.rb"
require "#{libbase}/services.rb"
require "#{libbase}/tools.rb"
require "#{libbase}/types.rb"
require "#{libbase}/users.rb"

#######################################################################
# ApiResource
# Resource object that provides methods for managing the top-level API
# resources.
#######################################################################
class ApiResource < Resource
  
  API_AUTH_REALM = "Cloudera Manager"
  API_CURRENT_VERSION = 2 # V3 as of CM 4.5.0
  
  #######################################################################
  # Creates a Resource object that provides API endpoints.
  # @param server_host: The hostname of the Cloudera Manager server.
  # @param server_port: The port of the server. Defaults to 7180(http) or 7183(https).
  # @param username: Login name.
  # @param use_tls: Whether to use tls(https).
  # @param version: API version.
  # @return Resource object referring to the root.
  #######################################################################
  def initialize(server_host, server_port=nil, username="admin", password="admin", use_tls=false, version=API_CURRENT_VERSION, debug=false)
    @version = version
    if use_tls
      protocol = "https"
    else
      protocol = "http"
    end
    if server_port.nil?
      if use_tls
        server_port = 7183
      else
        server_port = 7180
      end
    end
    base_url = "#{protocol}://#{server_host}:#{server_port}/api/v#{version}"
    client = RestClient::Resource.new(base_url, username, password)
    super(client, base_url, debug)
  end
  
  #######################################################################
  # Returns the API version being used.
  #######################################################################
  def version
    return @version
  end
  
  #----------------------------------------------------------------------
  # CMS related methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Retrieve a list of running global commands.
  # @param view: View to materialize('full' or 'summary')
  # @return: A list of running commands.
  #######################################################################
  def get_commands(view=nil)
    return ClouderaManager.get_commands(self, view)
  end
  
  #######################################################################
  # Setup the Cloudera Management Service.
  # @param service_setup_info: ApiServiceSetupInfo object.
  # @return: The management service instance.
  #######################################################################
  def create_mgmt_service(service_setup_info)
    return ClouderaManager.create_mgmt_service(self, service_setup_info)
  end
  
  #######################################################################
  # Return the Cloudera Management Services instance.
  # @return: An ApiService instance.
  #######################################################################
  def get_service
    return ClouderaManager.get_service(self)
  end
  
  #######################################################################
  # Return information about the currently installed license.
  # Return nil if no license key found.
  # @return: License information.
  #######################################################################
  def get_license
    begin
      return ClouderaManager.get_license(self)
    rescue RestClient::ResourceNotFound => e
      return nil
    end
  end
  
  #######################################################################
  # Install or update the Cloudera Manager license.
  # Note: get_license will report nil until the cm-server has been restarted.
  # @param license_text: the license in text form.
  #######################################################################
  def update_license(license_text)
    return ClouderaManager.update_license(self, license_text)
  end
  
  #######################################################################
  # Retrieve the Cloudera Manager configuration.
  # The 'summary' view contains strings as the dictionary values. The full
  # view contains ApiConfig instances as the values.
  # @param view: View to materialize('full' or 'summary')
  # @return: Dictionary with configuration data.
  #######################################################################
  def get_config(view = nil)
    return ClouderaManager.get_config(self, view)
  end
  
  #######################################################################
  # Update the CM configuration.
  # @param: config Dictionary with configuration to update.
  # @return: Dictionary with updated configuration.
  #######################################################################
  def update_config(config)
    return ClouderaManager.update_config(self, config)
  end
  
  #######################################################################
  # Generate credentials for services configured with Kerberos.
  # @return: Information about the submitted command.
  #######################################################################
  def generate_credentials()
    return ClouderaManager.generate_credentials(self)
  end
  
  #######################################################################
  # Runs the host inspector on the configured hosts.
  # @return: Information about the submitted command.
  #######################################################################
  def inspect_hosts()
    return ClouderaManager.inspect_hosts(self)
  end
  
  #######################################################################
  # Issue the command to collect diagnostic data.
  # @param start_datetime: The start of the collection period. Type datetime.
  # @param end_datetime: The end of the collection period. Type datetime.
  # @param includeInfoLog: Whether to include INFO level log messages.
  #######################################################################
  def collect_diagnostic_data(start_datetime, end_datetime, includeInfoLog=false)
    return ClouderaManager.collect_diagnostic_data(self, start_datetime, end_datetime, includeInfoLog)
  end
  
  #######################################################################
  # Decommission the specified hosts by decommissioning the slave roles
  # and stopping the remaining ones.
  # @param host_names: List of names of hosts to be decommissioned.
  # @return: Information about the submitted command.
  # @since: API v2
  #######################################################################
  def hosts_decommission(host_names)
    return ClouderaManager.hosts_decommission(self, host_names)
  end
  
  #######################################################################
  # Recommission the specified hosts by recommissioning the slave roles.
  # This command doesn't start the roles. Use hosts_start_roles for that.
  # @param host_names: List of names of hosts to be recommissioned.
  # @return: Information about the submitted command.
  # @since: API v2
  #######################################################################
  def hosts_recommission(host_names)
    return ClouderaManager.hosts_recommission(self, host_names)
  end
  
  #######################################################################
  # Start all the roles on the specified hosts.
  # @param host_names: List of names of hosts on which to start all roles.
  # @return: Information about the submitted command.
  # @since: API v2
  #######################################################################
  def hosts_start_roles(host_names)
    return ClouderaManager.hosts_start_roles(self, host_names)
  end
  
  #----------------------------------------------------------------------
  # Host related methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Create a host.
  # @param host_id  The host id.
  # @param name     Host name
  # @param ipaddr   IP address
  # @param rack_id  Rack id. Default nil.
  # @return An ApiHost object
  #######################################################################
  def create_host(host_id, name, ipaddr, rack_id = nil)
    return ApiHost.create_host(self, host_id, name, ipaddr, rack_id)
  end
  
  #######################################################################
  # Delete a host by id.
  # @param host_id Host id
  # @return The deleted ApiHost object
  #######################################################################
  def delete_host(host_id)
    return ApiHost.delete_host(self, host_id)
  end
  
  #######################################################################
  # Get all hosts.
  # @param view View to materialize('full' or 'summary').
  # @return A list of ApiHost objects.
  #######################################################################
  def get_all_hosts(view = nil)
    return ApiHost.get_all_hosts(self, view)
  end
  
  #######################################################################
  # Look up a host by id.
  # @param host_id Host id
  # # @return: An ApiHost object
  #######################################################################
  def get_host(host_id)
    return ApiHost.get_host(self, host_id)
  end
  
  #######################################################################
  # Determine if a host already exists.
  # @param host_id Host ID.
  # @return host object or nil.
  #######################################################################
  def find_host(host_id)
    results = self.get_all_hosts()
    host_list = results.to_array
    host_list.each do |host_object|
      return host_object if host_object.getattr('hostId') == host_id
    end
    return nil
  end
  
  #----------------------------------------------------------------------
  # Cluster related methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Create a new cluster.
  # @param name Cluster name.
  # @param version Cluster CDH version.
  # @return The created cluster.
  #######################################################################
  def create_cluster(name, version)
    return ApiCluster.create_cluster(self, name, version)
  end
  
  #######################################################################
  # Delete a cluster by name.
  # @param name: Cluster name
  # @return The deleted ApiCluster object
  #######################################################################
  def delete_cluster(name)
    return ApiCluster.delete_cluster(self, name)
  end
  
  #######################################################################
  # Retrieve a list of all clusters.
  # @param view View to materialize('full' or 'summary').
  # @return A list of ApiCluster objects.
  #######################################################################
  def get_all_clusters(view = nil)
    return ApiCluster.get_all_clusters(self, view)
  end
  
  #######################################################################
  # Look up a cluster by name.
  # @param name Cluster name.
  # @return An ApiCluster object.
  #######################################################################
  def get_cluster(name)
    return ApiCluster.get_cluster(self, name)
  end
  
  #######################################################################
  # Determine if a cluster already exists.
  # @param name Cluster name.
  # @return cluster object or nil.
  #######################################################################
  def find_cluster(name)
    results = self.get_all_clusters()
    cluster_list = results.to_array
    cluster_list.each do |cluster_object|
      return cluster_object if cluster_object.getattr('name') == name
    end
    return nil
  end
  
  #----------------------------------------------------------------------
  # User related methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Get all users.
  # @param view: View to materialize('full' or 'summary').
  # @return: A list of ApiUser objects.
  #######################################################################
  def get_all_users(view = nil)
    return ApiUser.get_all_users(self, view)
  end
  
  #######################################################################
  # Look up a user by username.
  # @param username: Username to look up
  # @return: An ApiUser object
  #######################################################################
  def get_user(username)
    return ApiUser.get_user(self, username)
  end
  
  #######################################################################
  # Create a user.
  # @param username: Username
  # @param password: Password
  # @param roles: List of roles for the user. This should be [] for a
  #                   regular user, or ['ROLE_ADMIN'] for an admin.
  #######################################################################
  def create_user(username, password, roles)
    return ApiUser.create_user(self, username, password, roles)
  end
  
  #######################################################################
  # Delete user by username.
  # @param: username Username
  # @return: An ApiUser object
  #######################################################################
  def delete_user(username)
    return ApiUser.delete_user(self, username)
  end
  
  #----------------------------------------------------------------------
  # Service control methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Create a service
  # @param name: Service name
  # @param service_type: Service type
  # @param cluster_name: Cluster name
  # @return: An ApiService object
  #######################################################################
  def create_service(cluster, name, service_type, cluster_name="default")
    return ApiService.create_service(self, name, service_type, cluster_name)
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
  def get_service_config(service_object, view = nil)
    return service_object.get_config(self, view)
  end
  
  #######################################################################
  # Update the service's configuration.
  # Note : Cloudera Manager API v3 (new in 4.5) does not support setting
  # a service's roletype configuration, since that has been replaced by
  # role group. Callers should set the configuration on the appropriate
  # role group instead. Cloudera Manager 4.5 continues to support API v1
  # and v2. But users who want to upgrade their existing clients to v3
  # would need to rewrite any roletype configuration calls.  
  # @param svc_config Dictionary with service configuration to update.
  # @param rt_configs Dict of role type configurations to update.
  # @return 2-tuple(service config dictionary, role type configurations)
  #######################################################################
  def update_service_config(service_object, svc_config, rt_configs=nil)
    return service_object.update_config(self, svc_config, rt_configs)
  end
  
  #----------------------------------------------------------------------
  # Service level control methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Start a list of roles.
  # @param role_names: names of the roles to start.
  # @return: List of submitted commands.
  #######################################################################
  def start_roles(service_object, role_names)
    return service_object.start_roles(self, role_names)
  end
  
  #######################################################################
  # Stop a list of roles.
  # @param role_names: names of the roles to stop.
  # @return: List of submitted commands.
  #######################################################################
  def stop_roles(service_object, role_names)
    return service_object.stop_roles(self, role_names)
  end
  
  #######################################################################
  # Restart a list of roles.
  # @param role_names: names of the roles to restart.
  # @return: List of submitted commands.
  #######################################################################
  def restart_roles(service_object, role_names)
    return service_object.restart_roles(self, role_names)
  end
  
  #######################################################################
  # Bootstrap HDFS stand-by NameNodes.
  # Initialize their state by syncing it with the respective HA partner.
  # @param role_names: NameNodes to bootstrap.
  # @return: List of submitted commands.
  #######################################################################
  def bootstrap_hdfs_stand_by(service_object, role_names)
    return service_object.bootstrap_hdfs_stand_by(self, role_names)
  end
  
  #######################################################################
  # Execute the "refresh" command on a set of roles.
  # @param: role_names Names of the roles to refresh.
  # @return: Reference to the submitted command.
  #######################################################################
  def refresh(service_object, role_names)
    return service_object.refresh(self, role_names)
  end
  
  #######################################################################
  # Format NameNode instances of an HDFS service.
  # 
  # @param namenodes Name of NameNode instances to format.
  # @return List of submitted commands.
  #######################################################################
  def format_hdfs(service_object, namenodes)
    return service_object.format_hdfs(self, namenodes)
  end
  
  #######################################################################
  # Initialize HDFS failover controller metadata.
  # Only one controller per nameservice needs to be initialized.
  # @param controllers: Name of failover controller instances to initialize.
  # @return: List of submitted commands.
  #######################################################################
  def init_hdfs_auto_failover(service_object, controllers)
    return service_object.init_hdfs_auto_failover(self, controllers)
  end
  
  #######################################################################
  # Initialize a NameNode's shared edits directory.
  # @param namenodes Name of NameNode instances.
  # @return List of submitted commands.
  #######################################################################
  def init_hdfs_shared_dir(service_object, namenodes)
    return service_object.init_hdfs_shared_dir(self, namenodes)
  end
  
  #######################################################################
  # Synchronize the Hue server's database.
  # @param: servers Name of Hue Server roles to synchronize.
  # @return: List of submitted commands.
  #######################################################################
  def sync_hue_db(service_object, servers)
    return service_object.sync_hue_db(self, servers)
  end
  
  #######################################################################
  # Cleanup a ZooKeeper service or roles.
  # If no server role names are provided, the command applies to the whole
  # service, and cleans up all the server roles that are currently running.
  # @param servers: ZK server role names(optional).
  # @return: Command reference(for service command) or list of command
  # references(for role commands).
  #######################################################################
  def cleanup_zookeeper(service_object, servers)
    return service_object.cleanup_zookeeper(self, servers)
  end
  
  #######################################################################
  # Initialize a ZooKeeper service or roles.
  # If no server role names are provided, the command applies to the whole
  # service, and initializes all the configured server roles.
  # @param servers: ZK server role names(optional).
  # @return: Command reference(for service command) or list of command
  # references(for role commands).
  #######################################################################
  def init_zookeeper(service_object, servers)
    return service_object.init_zookeeper(self, servers)
  end
  
  #######################################################################
  # Put the service in maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def enter_maintenance_mode(service_object)
    return service_object.enter_maintenance_mode(self)
  end
  
  #######################################################################
  # Take the service out of maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def exit_maintenance_mode(service_object)
    return service_object.exit_maintenance_mode(self)
  end
  
  #######################################################################
  # Start a service.
  # @return Reference to the submitted command.
  #######################################################################
  def start_service(service_object)
    return service_object.start(self)
  end
  
  #######################################################################
  # Wait for command to finish.
  # @param timeout:(Optional) Max amount of time(in seconds) to wait. Wait
  # forever by default.
  # @return: The final ApiCommand object, containing the last known state.
  # The command may still be running in case of timeout.
  #######################################################################
  def wait_for_cmd(cmd_object, timeout=nil)
    return cmd_object.wait(self, timeout)
  end
  
  #######################################################################
  # Stop a service.
  # @return Reference to the submitted command.
  #######################################################################
  def stop_service(service_object)
    return service_object.stop(self)
  end
  
  #######################################################################
  # Restart a service.
  # @return Reference to the submitted command.
  #######################################################################
  def restart_service(service_object)
    return service_object.restart(self)
  end
  
  #----------------------------------------------------------------------
  # End of service level commands.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Lookup a service by name
  # @param name: Service name
  # @param cluster_name: Cluster name
  # @return: An ApiService object
  #######################################################################
  def get_service(name, cluster_name="default")
    return ApiService.get_service(self, name, cluster_name)
  end
  
  #######################################################################
  # Get all services
  # @param cluster_name: Cluster name
  # @return: A list of ApiService objects.
  #######################################################################
  def get_all_services(cluster_name="default", view=nil)
    return ApiService.get_all_services(self, cluster_name, view)
  end
  
  #######################################################################
  # Delete a service by name.
  # @param name: Service name
  # @param cluster_name: Cluster name
  # @return: The deleted ApiService object
  #######################################################################
  def delete_service(name, cluster_name="default")
    return ApiService.delete_service(self, name, cluster_name)
  end
  
  #######################################################################
  # Determine if a service already exists.
  # @param name Service name.
  # @param cluster_name Cluster name.
  # @return service object or nil.
  #######################################################################
  def find_service(name, cluster_name="default")
    results = self.get_all_services(cluster_name, 'full')
    service_list = results.to_array
    service_list.each do |service_object|
      return service_object if service_object.getattr('name') == name
    end
    return nil
  end
  
  #----------------------------------------------------------------------
  # Role related methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Create a role
  # @param service_parent: Top level service object (i.e. HDFS).
  # @param role_name: Role name
  # @param role_type: Role type
  # @param host_id: ID of the host to assign the role to
  # @return: An ApiRole object
  #######################################################################
  def create_role(service_parent, role_name, role_type, host_id)
    return service_parent.create_role(self, role_name, role_type, host_id)
  end
  
  #######################################################################
  # Lookup a role by name
  # @param service_parent: Top level service object (i.e. HDFS).
  # @param name: Role name
  # @return: An ApiRole object
  #######################################################################
  def get_role(service_parent, name)
    return service_parent.get_role(self, name)   
  end
  
  #######################################################################
  # Get all roles
  # @param service_parent: Top level service object (i.e. HDFS).
  # @param view: View to materialize('full' or 'summary')
  # @return: A list of ApiRole objects.
  #######################################################################
  def get_all_roles(service_parent, view=nil)
    return service_parent.get_all_roles(self, view)
  end
  
  #######################################################################
  # Get all roles of a certain type in a service
  # @param service_parent: Top level service object (i.e. HDFS).
  # @param role_type: Role type
  # @param view: View to materialize('full' or 'summary')
  # @return: A list of ApiRole objects.
  #######################################################################
  def get_roles_by_type(service_parent, role_type, view=nil)
    return service_parent.get_roles_by_type(self, role_type, view)
  end
  
  #######################################################################
  # Delete a role by name
  # @param service_parent: Top level service object (i.e. HDFS).
  # @param name Role name
  # @return The deleted ApiRole object
  #######################################################################
  def delete_role(service_parent, name)
    return service_parent.delete_role(self, name)
  end
  
  #######################################################################
  # Get a list of role types in a service.
  # @param service_parent: Top level service object (i.e. HDFS).
  # @return: A list of role types(strings)
  #######################################################################
  def get_role_types(service_parent)
    return service_parent.get_role_types(self)
  end
  
  #######################################################################
  # Determine if a role already exists.
  # @param service_parent: Top level service object (i.e. HDFS).
  # @param role_name Role name.
  # @return role object or nil.
  #######################################################################
  def find_role(service_parent, name)
    results = self.get_all_roles(service_parent, 'full')
    role_list = results.to_array
    role_list.each do |role_object|
      return role_object if role_object.getattr('name') == name
    end
    return nil
  end
  
  #----------------------------------------------------------------------
  # Event related methods
  #----------------------------------------------------------------------
  
  #######################################################################
  # Query events.
  # @param query_str: Query string.
  # @return: A list of ApiEvent.
  #######################################################################
  def query_events(query_str = nil)
    return ApiEvent.query_events(self, query_str)
  end
  
  #######################################################################
  # Retrieve a particular event by ID.
  # @param event_id: The event ID.
  # @return An ApiEvent.
  #######################################################################
  def get_event(event_id)
    return ApiEvent.get_event(self, event_id)
  end
  
  #----------------------------------------------------------------------
  # Tool related methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Have the server echo a message back.
  #######################################################################
  def echo(message)
    return Tools.echo(self, message)
  end
  
  #######################################################################
  # Generate an error, but we get to set the error message.
  #######################################################################
  def echo_error(message)
    return Tools.echo_error(self, message)
  end
  
  #######################################################################
  # Generic function for querying metrics.
  # @param from_time: A datetime; start of the period to query(optional).
  # @param to_time: A datetime; end_ of the period to query(default = now).
  # @param metrics: List of metrics to query(default = all).
  # @param view: View to materialize('full' or 'summary')
  # @param params: Other query parameters.
  # @return List of metrics and their readings.
  #######################################################################
  def get_metrics(path, from_time, to_time, metrics, view, params=nil)
    if not params
      params = { }
    end
    if from_time
      params['from'] = from_time.isoformat()
    end
    if to_time
      params['to'] = to_time.isoformat()
    end
    if metrics
      params['metrics'] = metrics
    end
    if view
      params['view'] = view
    end
    resp = get(path, params=params)
    return types.ApiList.from_json_dict(types.ApiMetric, resp, self)
  end
  
  #######################################################################
  # Get the root resource objects.
  #######################################################################
  def get_root_resource(server_host, server_port=nil, username="admin", password="admin", use_tls=false, version=1)
    return ApiResource.new(server_host, server_port, username, password, use_tls, version)
  end
end
