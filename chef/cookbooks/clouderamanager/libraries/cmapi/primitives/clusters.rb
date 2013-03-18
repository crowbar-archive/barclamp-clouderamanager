#!/usr/bin/ruby
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
# ApiCluster
#######################################################################
class ApiCluster < BaseApiObject
  
  CLUSTERS_PATH = "/clusters"
  
  RO_ATTR = [ 'maintenanceMode', 'maintenanceOwners' ]
  
  RW_ATTR = [ 'name', 'version' ]
  
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
  # Create a cluster
  # @param resource_root: The root Resource object.
  # @param name: Cluster name
  # @param version: Cluster CDH version
  # @return: An ApiCluster object
  #######################################################################
  def self.create_cluster(resource_root, name, version)
    dict = { :name => name, :version => version }
    apicluster = ApiCluster.new(resource_root, dict)
    apicluster_list = ApiList.new([apicluster])
    jdict = apicluster_list.to_json_dict(self)
    body = JSON.generate(jdict)
    resp = resource_root.post(CLUSTERS_PATH, body)
    # The server returns a list of created clusters (size=1)
    return ApiList.from_json_dict(ApiCluster, resp, resource_root)[0]
  end
  
  #######################################################################
  # Get all clusters
  # @param resource_root: The root Resource object.
  # @return: A list of ApiCluster objects.
  #######################################################################
  def self.get_all_clusters(resource_root, view=nil)
    params = nil 
    params = { :view => view } if (view)
    jdict = resource_root.get(CLUSTERS_PATH, params)
    return ApiList.from_json_dict(ApiCluster, jdict, resource_root)
  end
  
  #######################################################################
  # Lookup a cluster by name
  # @param resource_root: The root Resource object.
  # @param name: Cluster name
  # @return: An ApiCluster object
  #######################################################################
  def self.get_cluster(resource_root, name)
    jdict = resource_root.get("#{CLUSTERS_PATH}/#{name}")
    return ApiCluster.from_json_dict(ApiCluster, jdict, resource_root)
  end
  
  #######################################################################
  # Delete a cluster by name
  # @param resource_root: The root Resource object.
  # @param name: Cluster name
  # @return: The deleted ApiCluster object
  #######################################################################
  def self.delete_cluster(resource_root, name)
    jdict = resource_root.delete("#{CLUSTERS_PATH}/#{name}")
    return ApiCluster.from_json_dict(ApiCluster, jdict, resource_root)
  end
  
  #----------------------------------------------------------------------
  # Class methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiCluster>: #{@name}; version: #{@version}"
  end
  
  #######################################################################
  # _path
  #######################################################################
  def _path
    return "#{CLUSTERS_PATH}/#{@name}"
  end
  
  #######################################################################
  # _cmd (cmd, data=nil)
  #######################################################################
  def _cmd (cmd, data=nil)
    path = _path() + "/commands/#{cmd}"
    resp = _get_resource_root().post(path, data)
    return ApiCommand.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # _put (dic, params=nil)
  # Change cluster attributes
  #######################################################################
  def _put (dic, params=nil)
    data=JSON.generate(dic)
    resp = _get_resource_root().put(_path(), params, data)
    cluster = ApiCluster.from_json_dict(resp, _get_resource_root())
    _update(cluster)
    return self
  end
  
  #######################################################################
  # Retrieve a list of running commands for this cluster.
  # @param view: View to materialize ('full' or 'summary')
  # @return: A list of running commands.
  #######################################################################
  def get_commands(view=nil)
    params = nil 
    params = { :view => view } if (view)
    subpath = _path() + '/commands'
    resp = _get_resource_root().get(subpath, params)
    return ApiList.from_json_dict(ApiCommand, resp, _get_resource_root())
  end
  
  #######################################################################
  # Rename a cluster.
  # @param newname: New cluster name
  # @return: An ApiCluster object
  # @since: API v2
  #######################################################################
  def rename(newname)
    dic = to_json_dict(self)
    dic['name'] = newname
    return _put(dic)
  end
  
  #######################################################################
  # Create a service.
  # @param name: Service name
  # @param service_type: Service type
  # @return: An ApiService object
  #######################################################################
  def create_service(name, service_type)
    return services.create_service(_get_resource_root(), name, service_type, @name)
  end
  
  #######################################################################
  # Delete a service by name.
  # @param name Service name
  # @return The deleted ApiService object
  #######################################################################
  def delete_service(name)
    return services.delete_service(_get_resource_root(), name, @name)
  end
  
  #######################################################################
  # Lookup a service by name.
  # @param name: Service name
  # @return: An ApiService object
  #######################################################################
  def get_service(name)
    return services.get_service(_get_resource_root(), name, @name)
  end
  
  #######################################################################
  # Get all services in this cluster.
  # @return: A list of ApiService objects.
  #######################################################################
  def get_all_services(view = nil)
    return services.get_all_services(_get_resource_root(), @name, view)
  end
  
  #######################################################################
  # Start all services in a cluster, respecting dependencies.
  # @return: Reference to the submitted command.
  #######################################################################
  def start
    return _cmd('start')
  end
  
  #######################################################################
  # Stop all services in a cluster, respecting dependencies.
  # @return: Reference to the submitted command.
  #######################################################################
  def stop
    return _cmd('stop')
  end
  
  #######################################################################
  # Deploys client configuration to the hosts on the cluster.
  # @return: Reference to the submitted command.
  # @since: API v2
  #######################################################################
  def deploy_client_config
    return _cmd('deployClientConfig')
  end
  
  #######################################################################
  # Put the cluster in maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def enter_maintenance_mode
    cmd = _cmd('enterMaintenanceMode')
    if cmd.success
      _update(get_cluster(_get_resource_root(), @name))
    end
    return cmd
  end
  
  #######################################################################
  # Take the cluster out of maintenance mode.
  # @return: Reference to the completed command.
  # @since: API v2
  #######################################################################
  def exit_maintenance_mode
    cmd = _cmd('exitMaintenanceMode')
    if cmd.success
      _update(get_cluster(_get_resource_root(), @name))
    end
    return cmd
  end
end
