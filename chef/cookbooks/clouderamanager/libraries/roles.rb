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

libbase = File.dirname(__FILE__)
require "#{libbase}/types.rb"

#######################################################################
# ApiRole
#######################################################################
class ApiRole < BaseApiObject
  
  RO_ATTR = [ 'roleState', 'healthSummary', 'healthChecks', 'serviceRef',
      'configStale', 'haStatus', 'roleUrl', 'commissionState', 
      'maintenanceMode', 'maintenanceOwners', 'roleConfigGroupRef' ]
  
  RW_ATTR = [ 'name', 'type', 'hostRef' ]
  
  #######################################################################
  # initialize(resource_root, name, type, hostRef)
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
  # _get_roles_path(cluster_name, service_name)
  #######################################################################
  def self._get_roles_path(cluster_name, service_name)
    if cluster_name
      return "/clusters/#{cluster_name}/services/#{service_name}/roles"
    end  
    return '/cm/service/roles'
  end
  
  #######################################################################
  # _get_role_path(cluster_name, service_name, role_name)
  #######################################################################
  def self._get_role_path(cluster_name, service_name, role_name)
    path = _get_roles_path(cluster_name, service_name)
    return "#{path}/#{role_name}"
  end
  
  #######################################################################
  # Create a role
  # @param resource_root: The root Resource object.
  # @param service_name: Service name
  # @param role_type: Role type
  # @param role_name: Role name
  # @param cluster_name: Cluster name
  # @return: An ApiRole object
  #######################################################################
  def self.create_role(resource_root, service_name, role_type, role_name, host_id, cluster_name="default")
    hrdict  = { :hostId => host_id } 
    host_ref = ApiHostRef.new(resource_root, hrdict)
    dict  = { :name => role_name, :type => role_type, :hostRef => host_ref } 
    apirole = ApiRole.new(resource_root, dict)
    apirole_array = [ apirole ]
    apirole_list = ApiList.new(apirole_array)
    jdict = apirole_list.to_json_dict(self)
    data = JSON.generate(jdict)
    path = _get_roles_path(cluster_name, service_name)
    resp = resource_root.post(path, data)
    # The server returns a list of created roles (size=1)
    return ApiList.from_json_dict(ApiRole, resp, resource_root)[0]
  end
  
  #######################################################################
  # Lookup a role by name
  # @param resource_root: The root Resource object.
  # @param service_name: Service name
  # @param name: Role name
  # @param cluster_name: Cluster name
  # @return: An ApiRole object
  #######################################################################
  
  def self._get_role(resource_root, path)
    jdict = resource_root.get(path)
    return ApiRole.from_json_dict(jdict, resource_root)
  end
  
  def self.get_role(resource_root, service_name, name, cluster_name='default')
    return _get_role(resource_root, _get_role_path(cluster_name, service_name, name))
  end
  
  #######################################################################
  # Get all roles
  # @param resource_root: The root Resource object.
  # @param service_name: Service name
  # @param cluster_name: Cluster name
  # @return: A list of ApiRole objects.
  #######################################################################
  def self.get_all_roles(resource_root, service_name, cluster_name='default', view=nil)
    params = nil 
    params = { :view => view } if (view)
    path = _get_roles_path(cluster_name, service_name)
    dict = resource_root.get(path, params)
    return ApiList.from_json_dict(ApiRole, dict, resource_root)
  end
  
  #######################################################################
  # Get all roles of a certain type in a service
  # @param resource_root: The root Resource object.
  # @param service_name: Service name
  # @param role_type: Role type
  # @param cluster_name: Cluster name
  # @return: A list of ApiRole objects.
  #######################################################################
  def self.get_roles_by_type(resource_root, service_name, role_type, cluster_name='default', view=nil)
    roles = get_all_roles(resource_root, service_name, cluster_name, view)
    roles.each do |role|
      return role if role.type == role_type
    end
  end
  
  #######################################################################
  # Delete a role by name
  # @param resource_root: The root Resource object.
  # @param service_name: Service name
  # @param name: Role name
  # @param cluster_name: Cluster name
  # @return: The deleted ApiRole object
  #######################################################################
  def self.delete_role(resource_root, service_name, name, cluster_name='default')
    path = _get_role_path(cluster_name, service_name, name) 
    resp = resource_root.delete(path)
    return ApiRole.from_json_dict(resp, resource_root)
  end
  
  #----------------------------------------------------------------------
  # Class methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    cluster = @serviceRef[:clusterName]
    service = @serviceRef[:serviceName]
    return "<ApiRole>: #{@name} (cluster: #{cluster}; service: #{service})"
  end
  
  #######################################################################
  # _path
  #######################################################################
  def _path
    cluster = @serviceRef[:clusterName]
    service = @serviceRef[:serviceName]
    return _get_role_path(cluster, service, @name)
  end
  
  #######################################################################
  # _cmd(cmd, data=nil)
  #######################################################################
  def _cmd(cmd, data=nil)
    path = _path() + "/commands/#{cmd}"
    resource_root = _get_resource_root() 
    resp = resource_root.post(path, data)
    return ApiCommand.from_json_dict(resp, resource_root)
  end
  
  #######################################################################
  # _get_log(log)
  #######################################################################
  def _get_log(log)
    base = _path()
    path = "#{base}/logs/#{log}"
    resource_root = _get_resource_root() 
    return resource_root.get(path)
  end
  
  #######################################################################
  # Retrieve a list of running commands for this role.'
  # @param view: View to materialize('full' or 'summary')
  # @return: A list of running commands.
  #######################################################################
  def get_commands(view=nil)
    params = nil
    params = { :view => view } if (view)
    base = _path()
    path = "#{base}/commands"
    resource_root = _get_resource_root() 
    resp = resource_root.get(path, params)
    return ApiList.from_json_dict(ApiCommand, resp, resource_root)
  end
  
  #######################################################################
  # Retrieve the role's configuration.
  # The 'summary' view contains strings as the dictionary values. The full
  # view contains ApiConfig instances as the values.
  # @param view: View to materialize('full' or 'summary')
  # @return Dictionary with configuration data.
  #######################################################################
  def get_config(view = nil)
    params = nil 
    params = { :view => view } if (view)
    path = _path() + '/config'
    resource_root = _get_resource_root() 
    resp = resource_root.get(path, params)
    return ApiConfig.json_to_config(resource_root, resp, view)
  end
  
  #######################################################################
  # Update the role's configuration.
  # @param config Dictionary with configuration to update.
  # @return Dictionary with updated configuration.
  #######################################################################
  def update_config(config)
    path = _path() + '/config'
    data = config_to_json(config)
    resource_root = _get_resource_root() 
    resp = resource_root.put(path, data)
    return ApiConfig.json_to_config(resp)
  end
  
  #######################################################################
  # Retrieve the contents of the role's log file.
  # @return: Contents of log file.
  #######################################################################
  def get_full_log
    return _get_log('full')
  end
  
  #######################################################################
  # Retrieve the contents of the role's standard output.
  # @return: Contents of stdout.
  #######################################################################
  def get_stdout
    return _get_log('stdout')
  end
  
  #######################################################################
  # Retrieve the contents of the role's standard error.
  # @return: Contents of stderr.
  #######################################################################
  def get_stderr
    return _get_log('stderr')
  end
  
  #######################################################################
  # Retrieve metric readings for the role.
  # @param from_time: A datetime; start of the period to query(optional).
  # @param to_time: A datetime; end of the period to query(default = now).
  # @param metrics: List of metrics to query(default = all).
  # @param view: View to materialize('full' or 'summary')
  # @return List of metrics and their readings.
  #######################################################################
  def get_metrics(from_time=nil, to_time=nil, metrics=nil, view=nil)
    path = _path() + '/metrics'
    resource_root = _get_resource_root() 
    return resource_root.get_metrics(path, from_time, to_time, metrics, view)
  end
  
  #######################################################################
  # Put the role in maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def enter_maintenance_mode
    cmd = _cmd('enterMaintenanceMode')
    if cmd.success
      _update(_get_role(_get_resource_root(), _path()))
    end
    return cmd
  end
  
  #######################################################################
  # Take the role out of maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def exit_maintenance_mode
    cmd = _cmd('exitMaintenanceMode')
    if cmd.success
      _update(_get_role(_get_resource_root(), _path()))
    end
    return cmd
  end
end
