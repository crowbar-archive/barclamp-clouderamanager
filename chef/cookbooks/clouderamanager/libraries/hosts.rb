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

require 'json'

libbase = File.dirname(__FILE__)
require "#{libbase}/types.rb"

#######################################################################
# ApiHost
#######################################################################
class ApiHost < BaseApiObject
  
  HOSTS_PATH = '/hosts'
  
  RO_ATTR = [ 'status', 'lastHeartbeat', 'roleRefs', 'healthSummary',
      'healthChecks', 'hostUrl', 'commissionState',
      'maintenanceMode', 'maintenanceOwners' ]
  
  RW_ATTR = [ 'hostId', 'hostname', 'ipAddress', 'rackId' ]
  
  #######################################################################
  # initialize
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
  # Create a host
  # @param resource_root: The root Resource object.
  # @param host_id: Host id
  # @param name: Host name
  # @param ipaddr: IP address
  # @param rack_id: Rack id. Default None
  # @return: An ApiHost object
  #######################################################################
  def self.create_host(resource_root, host_id, name, ipaddr, rack_id=nil)
    dict = { 'hostId' => host_id, 'hostname' => name, 'ipAddress' => ipaddr, 'rackId'=> rack_id } 
    apihost = ApiHost.new(resource_root, dict)
    apihost_list = ApiList.new([apihost])
    jdict = apihost_list.to_json_dict(self)
    data = JSON.generate(jdict)
    resp = resource_root.post(HOSTS_PATH, data)
    # The server returns a list of created hosts (size=1)
    return ApiList.from_json_dict(ApiHost, resp, resource_root)[0]
  end
  
  #######################################################################
  # Lookup a host by id
  # @param resource_root: The root Resource object.
  # @param host_id: Host id
  # @return: An ApiHost object
  #######################################################################
  def self.get_host(resource_root, host_id)
    jdict = resource_root.get("#{HOSTS_PATH}/#{host_id}")
    return ApiHost.from_json_dict(ApiHost, jdict, resource_root)
  end
  
  #######################################################################
  # Get all hosts
  # @param resource_root: The root Resource object.
  # @return: A list of ApiHost objects.
  #######################################################################
  def self.get_all_hosts(resource_root, view=nil)
    params = nil 
    params = { :view => view } if(view)
    jdict = resource_root.get(HOSTS_PATH, params)
    return ApiList.from_json_dict(ApiHost, jdict, resource_root)
  end
  
  #######################################################################
  # Delete a host by id
  # @param resource_root: The root Resource object.
  # @param host_id: Host id
  # @return: The deleted ApiHost object
  #######################################################################
  def self.delete_host(resource_root, host_id)
    resp = resource_root.delete("#{HOSTS_PATH}/#{host_id}")
    return ApiHost.from_json_dict(ApiHost, resp, resource_root)
  end
  
  #----------------------------------------------------------------------
  # Class methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiHost>: #{@hostId} (#{@ipAddress})"
  end
  
  #######################################################################
  # _path
  #######################################################################
  def _path
    return "#{HOSTS_PATH}/#{@hostId}"
  end
  
  #######################################################################
  # _cmd(cmd, data=nil)
  #######################################################################
  def _cmd(cmd, data=nil)
    path = _path() + '/commands/' + cmd
    resp = _get_resource_root().post(path, data)
    return ApiCommand.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # Retrieve the host's configuration.
  # The 'summary' view contains strings as the dictionary values. The full
  # view contains ApiConfig instances as the values.
  # @param view: View to materialize('full' or 'summary')
  # @return Dictionary with configuration data.
  #######################################################################
  def get_config(view=nil)
    path = _path() + '/config'
    params = nil 
    params = { :view => view } if (view)
    resp = _get_resource_root().get(path, params)
    return json_to_config(resp, view)
  end
  
  #######################################################################
  # Update the host's configuration.
  # @param config Dictionary with configuration to update.
  # @return Dictionary with updated configuration.
  #######################################################################
  def update_config(config)
    path = _path() + '/config'
    data = config_to_json(config)
    resp = _get_resource_root().put(path, data)
    return json_to_config(resp)
  end
  
  #######################################################################
  # Retrieve metric readings for the host.
  # @param from_time: A datetime; start of the period to query(optional).
  # @param to_time: A datetime; end of the period to query(default = now).
  # @param metrics: List of metrics to query(default = all).
  # @param ifs: network interfaces to query. Default all, use None to disable.
  # @param storageIds: storage IDs to query. Default all, use None to disable.
  # @param view: View to materialize('full' or 'summary')
  # @return List of metrics and their readings.
  #######################################################################
  def get_metrics(from_time=nil, to_time=nil, metrics=nil, ifs=[], storageIds=[], view=nil)
    params = { }
    if ifs
      params['ifs'] = ifs
    elsif ifs.equal? nil
      params['queryNw'] = 'false'
    end
    
    if storageIds
      params['storageIds'] = storageIds
    elsif storageIds.equal? nil
      params['queryStorage'] = 'false'
    end
    
    return _get_resource_root().get_metrics(_path() + '/metrics', from_time, to_time, metrics, view, params)
  end
  
  #######################################################################
  # Put the host in maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def enter_maintenance_mode
    cmd = _cmd('enterMaintenanceMode')
    if cmd.success
      _update(get_host(_get_resource_root(), @hostId))
    end
    return cmd
  end
  
  #######################################################################
  # Take the host out of maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def exit_maintenance_mode
    cmd = _cmd('exitMaintenanceMode')
    if cmd.success
      _update(get_host(_get_resource_root(), @hostId))
    end
    return cmd
  end
end
