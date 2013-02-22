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
require "#{libbase}/primitives/clusters.rb"
require "#{libbase}/primitives/cms.rb"
require "#{libbase}/primitives/events.rb"
require "#{libbase}/primitives/hosts.rb"
require "#{libbase}/primitives/roles.rb"
require "#{libbase}/primitives/services.rb"
require "#{libbase}/primitives/tools.rb"
require "#{libbase}/primitives/types.rb"
require "#{libbase}/primitives/users.rb"

#######################################################################
# ApiResource
# Resource object that provides methods for managing the top-level API
# resources.
#######################################################################
class ApiResource < Resource
  
  API_AUTH_REALM = "Cloudera Manager"
  API_CURRENT_VERSION = 2
  
  #######################################################################
  # Creates a Resource object that provides API endpoints.
  # @param server_host: The hostname of the Cloudera Manager server.
  # @param server_port: The port of the server. Defaults to 7180(http) or 7183(https).
  # @param username: Login name.
  # @param use_tls: Whether to use tls(https).
  # @param version: API version.
  # @return Resource object referring to the root.
  #######################################################################
  def initialize(server_host, server_port=nil, username="admin", password="admin", use_tls=false, version=API_CURRENT_VERSION)
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
    super(client, base_url)
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
  # Returns a Cloudera Manager object.
  #######################################################################
  
  def get_cloudera_manager
    return cms.ClouderaManager.new(self)
  end
  
  #######################################################################
  # Cluster relate methods.
  #######################################################################
  
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
  # User related methods.
  #######################################################################
  
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
