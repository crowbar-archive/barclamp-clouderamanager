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
  def initialize(resource_root)
    dict = {}
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # Invokes a global command.
  # @param command: Command name.
  # @param data: Optional data to send to the command.
  # @return Information about the submitted command.
  #######################################################################
  def _cmd(command, data = nil)
    subpath = "/cm/commands/#{command}"
    resp = _get_resource_root().post(subpath, data)
    return ApiCommand.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # Retrieve a list of running global commands.
  # @param view: View to materialize('full' or 'summary')
  # @return: A list of running commands.
  #######################################################################
  def get_commands(view=nil)
    subpath = '/cm/commands'
    params = nil 
    params = { :view => view } if(view)
    resp = _get_resource_root().get(subpath, params)
    return ApiList.from_json_dict(ApiCommand, resp, _get_resource_root())
  end
  
  #######################################################################
  # Setup the Cloudera Management Service.
  # @param service_setup_info: ApiServiceSetupInfo object.
  # @return: The management service instance.
  #######################################################################
  def create_mgmt_service(service_setup_info)
    subpath = '/cm/service'
    jdict = service_setup_info.to_json_dict(self)
    data = JSON.generate(jdict)
    resp = _get_resource_root().put(subpath, data)
    return ApiService.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # Return the Cloudera Management Services instance.
  # @return: An ApiService instance.
  #######################################################################
  def get_service
    subpath = '/cm/service'
    resp = _get_resource_root().get(subpath)
    return ApiService.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # Return information about the currently installed license.
  # @return: License information.
  #######################################################################
  def get_license
    subpath = '/cm/license'
    resp = _get_resource_root().get(subpath)
    return ApiLicense.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # Install or update the Cloudera Manager license.
  # @param license_text: the license in text form
  #######################################################################
  def update_license(license_text)
    content = [
        '--MULTI_BOUNDARY',
        'Content-Disposition: form-data; name="license"',
        '',
    license_text,
        '--MULTI_BOUNDARY--',
        '' ]
    data = "\r\n".join(content)
    contenttype='multipart/form-data; boundary=MULTI_BOUNDARY'
    resp = _get_resource_root().post('cm/license', data, contenttype)
    return ApiLicense.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # Retrieve the Cloudera Manager configuration.
  # The 'summary' view contains strings as the dictionary values. The full
  # view contains ApiConfig instances as the values.
  # @param view: View to materialize('full' or 'summary')
  # @return: Dictionary with configuration data.
  #######################################################################
  def get_config(view = nil)
    subpath = '/cm/config'
    params = nil 
    params = { :view => view } if(view)
    resp = _get_resource_root().get(subpath, params)
    return json_to_config(resp, view)
  end
  
  #######################################################################
  # Update the CM configuration.
  # @param: config Dictionary with configuration to update.
  # @return: Dictionary with updated configuration.
  #######################################################################
  def update_config(config)
    subpath = '/cm/config'
    data = config_to_json(config)
    resp = _get_resource_root().put(subpath, data)
    return json_to_config(resp, false)
  end
  
  #######################################################################
  # Generate credentials for services configured with Kerberos.
  # @return: Information about the submitted command.
  #######################################################################
  def generate_credentials
    return _cmd('generateCredentials')
  end
  
  #######################################################################
  # Runs the host inspector on the configured hosts.
  # @return: Information about the submitted command.
  #######################################################################
  def inspect_hosts
    return _cmd('inspectHosts')
  end
  
  #######################################################################
  # Issue the command to collect diagnostic data.
  # @param start_datetime: The start of the collection period. Type datetime.
  # @param end_datetime: The end of the collection period. Type datetime.
  # @param includeInfoLog: Whether to include INFO level log messages.
  #######################################################################
  def collect_diagnostic_data(start_datetime, end_datetime, includeInfoLog=false)
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
  def hosts_decommission(host_names)
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
  def hosts_recommission(host_names)
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
  def hosts_start_roles(host_names)
    jdict = { ApiList.LIST_KEY => host_names }
    data = JSON.generate(jdict)
    return _cmd('hostsStartRoles', data)
  end
end
