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
# ApiUser
#######################################################################
class ApiUser < BaseApiObject
  
  USERS_PATH = "/users"
  
  RO_ATTR = [ ]
  
  RW_ATTR = [ 'name', 'password', 'roles' ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, name = nil, password=nil, roles=nil)
    dict = { 'name' => name, 'password' => password, 'roles' => roles }
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #----------------------------------------------------------------------
  # Static methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Get all users.
  # @param resource_root: The root Resource object
  # @param view: View to materialize('full' or 'summary').
  # @return: A list of ApiUser objects.
  #######################################################################
  def self.get_all_users(resource_root, view=nil)
    params = nil 
    params = { :view => view } if(view)
    path = USERS_PATH
    jdict = resource_root.get(path, params)
    return ApiList.from_json_dict(ApiUser, jdict, resource_root)
  end
  
  #######################################################################
  # Look up a user by username.
  # @param resource_root: The root Resource object
  # @param username: Username to look up
  # @return: An ApiUser object
  #######################################################################
  def self.get_user(resource_root, username)
    path = "#{USERS_PATH}/#{username}"
    jdict = resource_root.get(path)
    return ApiUser.from_json_dict(jdict, resource_root)
  end
  
  #######################################################################
  # Grant admin access to a user.
  # If the user already has admin access, this does nothing.
  # @param resource_root: The root Resource object
  # @param username: Username to give admin access to.
  # @return: An ApiUser object
  #######################################################################
  def self._grant_admin_role(resource_root, username)
    roles= [ 'ROLE_ADMIN' ]
    apiuser = ApiUser.new(resource_root, username, roles)
    jdict = apiuser.to_json_dict(self)
    data = JSON.generate(jdict)
    path = "#{USERS_PATH}/#{username}"
    resp = resource_root.put(path, data)
    return ApiUser.from_json_dict(resp, resource_root)
  end
  
  #######################################################################
  # Revoke admin access from a user. If the user does not have admin
  # access, this does nothing.
  # @param resource_root: The root Resource object
  # @param username: Username to give admin access to.
  # @return: An ApiUser object
  #######################################################################
  def self._revoke_admin_role(resource_root, username)
    apiuser = ApiUser.new(resource_root, username, roles=[])
    jdict = apiuser.to_json_dict(self)
    data = JSON.generate(jdict)
    path = "#{USERS_PATH}/#{username}"
    resp = resource_root.put(path, data)
    return ApiUser.from_json_dict(resp, resource_root)
  end
  
  #######################################################################
  # Create a user.
  # @param resource_root: The root Resource object
  # @param username: Username
  # @param password: Password
  # @param roles: List of roles for the user. This should be [] for a
  # regular user, or ['ROLE_ADMIN'] for an admin.
  # @return: An ApiUser object
  #######################################################################
  def self.create_user(resource_root, username, password, roles)
    apiuser = ApiUser.new(resource_root, username, password=password, roles=roles)
    apiuser_list = ApiList.new([ "#{apiuser}" ])
    jdict = apiuser_list.to_json_dict(self)
    data = JSON.generate(jdict)
    path = USERS_PATH
    resp = resource_root.post(path, data)
    return ApiList.from_json_dict(ApiUser, resp, resource_root)[0]
  end
  
  #######################################################################
  # Delete user by username.
  # @param resource_root: The root Resource object
  # @param: username Username
  # @return: An ApiUser object
  #######################################################################
  def self.delete_user(resource_root, username)
    path = "#{USERS_PATH}/#{username}"
    resp = resource_root.delete(path)
    return ApiUser.from_json_dict(resp, resource_root)
  end
  
  #----------------------------------------------------------------------
  # Class methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Grant admin access to a user. If the user already has admin access,
  # this does nothing.
  # @return: An ApiUser object
  #######################################################################
  def grant_admin_role
    resource_root = _get_resource_root()
    return _grant_admin_role(resource_root, @name)
  end
  
  #######################################################################
  # Revoke admin access from a user. If the user does not have admin
  # access, this does nothing.
  # @return: An ApiUser object
  #######################################################################
  def revoke_admin_role
    resource_root = _get_resource_root()
    return _revoke_admin_role(resource_root, @name)
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiUser>: (name:#{@name}, password:#{@password}, roles:#{@roles})"
  end
end
