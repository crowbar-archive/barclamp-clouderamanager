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
require 'json'

#######################################################################
# Resource
#######################################################################
class Resource < Object
  
  #######################################################################
  # @param client: A Client object.
  # @param base_url: The Base URL.
  #######################################################################
  def initialize(client, base_url)
    @client = client
    @base_url = base_url
    @debug = true
  end
  
  #######################################################################
  # Return the base URL.
  #######################################################################
  def base_url
    return @base_url
  end
  
  #######################################################################
  # Invoke the GET method on a resource.
  # @param relpath: Optional. A relative path to this resource's path.
  # @param params: Key-value data.
  # @return: A dictionary of the JSON result.
  #######################################################################
  def get(relpath=nil, params=nil)
    if @debug
      puts ">>>> Resource.get : (relpath:#{relpath}, params:#{params})"
    end
    if params
      resp = @client[relpath].get :params => params
    else
      resp = @client[relpath].get
    end
    return JSON.parse(resp)
  end
  
  #######################################################################
  # Invoke the PUT method on a resource.
  # @param relpath: Optional. A relative path to this resource's path.
  # @param params: Key-value data.
  # @param data: Optional. Body of the request.
  # @param contenttype: Optional.
  # @return: A dictionary of the JSON result.
  #######################################################################
  def put(relpath=nil, data=nil, params=nil, contenttype=:json)
    puts ">>>> Resource.put : (relpath:#{relpath}, data:#{data}, params:#{params}, contenttype:#{contenttype})"
    if params
      resp = @client[relpath].put data, :params => params, :content_type => contenttype
    else
      resp = @client[relpath].put data, :content_type => contenttype
    end
    return JSON.parse(resp)
  end
  
  #######################################################################
  # Invoke the POST method on a resource.
  # @param relpath: Optional. A relative path to this resource's path.
  # @param params: Key-value data.
  # @param data: Optional. Body of the request.
  # @param contenttype: Optional.
  # @return: A dictionary of the JSON result.
  #######################################################################
  def post(relpath=nil, data=nil, params=nil, contenttype=:json, accepttype=:json)
    if @debug
      puts ">>>> Resource.post : (relpath:#{relpath}, data:#{data}, params:#{params}, contenttype:#{contenttype}, accepttype:#{accepttype})"
    end
    if params
      resp = @client[relpath].post data, :params => params, :content_type => contenttype, :accept => accepttype
    else
      resp = @client[relpath].post data, :content_type => contenttype, :accept => accepttype
    end
    return JSON.parse(resp)
  end
  
  #######################################################################
  # Invoke the DELETE method on a resource.
  # @param relpath: Optional. A relative path to this resource's path.
  # @param params: Key-value data.
  # @return: A dictionary of the JSON result.
  #######################################################################
  def delete(relpath=nil, params=nil)
    if @debug
      puts ">>>> Resource.delete : (relpath:#{relpath}, params:#{params})"
    end
    if params
      resp = @client[relpath].delete :params => params
    else
      resp = @client[relpath].delete
    end
    return JSON.parse(resp)
  end
end
