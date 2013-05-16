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
require 'json'

libbase = File.dirname(__FILE__)
require "#{libbase}/types.rb"

#######################################################################
# ClouderaManager - The Cloudera Manager instance.
# Provides access to CM configuration and services.
#######################################################################
class ClouderaManager < BaseApiObject
  
  #######################################################################
  # Class Initializer.
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
  # Invokes a global command.
  # @param command: Command name.
  # @param data: Optional data to send to the command.
  # @return Information about the submitted command.
  #######################################################################
  def self._cmd(resource_root, command, data=nil)
    path = "/cm/commands/#{command}"
    resp = resource_root.post(path, data)
    return ApiCommand.from_json_dict(ApiCommand, resp, resource_root)
  end
  
  #######################################################################
  # Retrieve a list of running global commands.
  # @param view: View to materialize('full' or 'summary')
  # @return: A list of running commands.
  #######################################################################
  def self.get_commands(resource_root, view=nil)
    params = nil 
    params = { :view => view } if(view)
    path = '/cm/commands'
    resp = resource_root.get(path, params)
    return ApiList.from_json_dict(ApiCommand, resp, resource_root)
  end
  
  #######################################################################
  # Setup the Cloudera Management Service.
  # @param service_setup_info: ApiServiceSetupInfo object.
  # @return: The management service instance.
  #######################################################################
  def self.create_mgmt_service(resource_root, service_setup_info)
    jdict = service_setup_info.to_json_dict(self)
    data = JSON.generate(jdict)
    path = '/cm/service'
    resp = resource_root.put(path, data)
    return ApiService.from_json_dict(ApiService, resp, resource_root)
  end
  
  #######################################################################
  # Return the Cloudera Management Services instance.
  # @return: An ApiService instance.
  #######################################################################
  def self.get_service(resource_root) 
    path = '/cm/service'
    resp = resource_root.get(path)
    return ApiService.from_json_dict(ApiService, resp, resource_root)
  end
  
  #######################################################################
  # Return information about the currently installed license.
  # @return: License information.
  #######################################################################
  def self.get_license(resource_root)
    path = '/cm/license'
    resp = resource_root.get(path)
    return ApiLicense.from_json_dict(ApiLicense, resp, resource_root)
  end
  
  #######################################################################
  # Install or update the Cloudera Manager license.
  # @param license_text: the license in text form
  #######################################################################
  def self.update_license(resource_root, license_text)
    content = [
        '--MULTI_BOUNDARY',
        'Content-Disposition: form-data; name="license"',
        '',
    license_text,
        '--MULTI_BOUNDARY--',
        '' ]
    params = nil
    data = content.join("\r\n")
    contenttype='multipart/form-data; boundary=MULTI_BOUNDARY'
    path = 'cm/license'
    resp = resource_root.post(path, data, params, contenttype)
    return ApiLicense.from_json_dict(ApiLicense, resp, resource_root)
  end
  
  #######################################################################
  # Retrieve the Cloudera Manager configuration.
  # The 'summary' view contains strings as the dictionary values. The full
  # view contains ApiConfig instances as the values.
  # @param view: View to materialize('full' or 'summary')
  # @return: Dictionary with configuration data.
  #######################################################################
  def self.get_config(resource_root, view = nil)
    params = nil 
    params = { :view => view } if (view)
    path = '/cm/config'
    resp = resource_root.get(path, params)
    return ApiConfig.json_to_config(resource_root, resp, view)
  end
  
  #######################################################################
  # Update the CM configuration.
  # @param: config Dictionary with configuration to update.
  # @return: Dictionary with updated configuration.
  #######################################################################
  def self.update_config(resource_root, config)
    view = nil
    data = config_to_json(config)
    path = '/cm/config'
    resp = resource_root.put(path, data)
    return ApiConfig.json_to_config(resource_root, resp, view)
  end
  
  #######################################################################
  # Generate credentials for services configured with Kerberos.
  # @return: Information about the submitted command.
  #######################################################################
  def self.generate_credentials(resource_root)
    return _cmd('generateCredentials')
  end
  
  #######################################################################
  # Runs the host inspector on the configured hosts.
  # @return: Information about the submitted command.
  #######################################################################
  def self.inspect_hosts(resource_root)
    return _cmd('inspectHosts')
  end
  
  #######################################################################
  # Issue the command to collect diagnostic data.
  # @param start_datetime: The start of the collection period. Type datetime.
  # @param end_datetime: The end of the collection period. Type datetime.
  # @param includeInfoLog: Whether to include INFO level log messages.
  #######################################################################
  def self.collect_diagnostic_data(resource_root, start_datetime, end_datetime, includeInfoLog=false)
    args = {
        'startTime' => start_datetime.isoformat(),
        'endTime' => end_datetime.isoformat(),
        'includeInfoLog' => includeInfoLog
    }
    data = JSON.generate(args)
    return _cmd('collectDiagnosticData', data)
  end
  
  #######################################################################
  # Decommission the specified hosts by decommissioning the slave roles
  # and stopping the remaining ones.
  # @param host_names: List of names of hosts to be decommissioned.
  # @return: Information about the submitted command.
  # @since: API v2
  #######################################################################
  def self.hosts_decommission(resource_root, host_names)
    jdict = { ApiList.LIST_KEY => host_names }
    data = JSON.generate(jdict)
    return _cmd('hostsDecommission', data)
  end
  
  #######################################################################
  # Recommission the specified hosts by recommissioning the slave roles.
  # This command doesn't start the roles. Use hosts_start_roles for that.
  # @param host_names: List of names of hosts to be recommissioned.
  # @return: Information about the submitted command.
  # @since: API v2
  #######################################################################
  def self.hosts_recommission(resource_root, host_names)
    jdict = { ApiList.LIST_KEY => host_names }
    data = JSON.generate(jdict)
    return _cmd('hostsRecommission', data)
  end
  
  #######################################################################
  # Start all the roles on the specified hosts.
  # @param host_names: List of names of hosts on which to start all roles.
  # @return: Information about the submitted command.
  # @since: API v2
  #######################################################################
  def self.hosts_start_roles(resource_root, host_names)
    jdict = { ApiList.LIST_KEY => host_names }
    data = JSON.generate(jdict)
    return _cmd('hostsStartRoles', data)
  end
end
