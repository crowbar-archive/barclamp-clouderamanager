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

libbase = File.dirname(__FILE__)
require "#{libbase}/types.rb"
require "#{libbase}/../utils.rb"

#######################################################################
# ApiEvent
#######################################################################
class ApiEvent < BaseApiObject
  
  EVENTS_PATH = "/events"
  
  RO_ATTR = [ 'id', 'content', 'timeOccurred', 'timeReceived', 'category',
              'severity', 'alert', 'attributes' ]
  
  RW_ATTR = [ ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize (resource_root)
    dict = {}
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #----------------------------------------------------------------------
  # Static methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # Search for events.
  # @param query_str: Query string.
  # @return: A list of ApiEvent.
  #######################################################################
  def self.query_events (resource_root, query_str=nil)
    params = nil
    params = { :query => query_str } if query_str
    path = EVENTS_PATH
    resp = resource_root.get(path, params)
    return ApiList.from_json_dict(ApiEvent, resp, resource_root)
  end
  
  #######################################################################
  # Retrieve a particular event by ID.
  # @param event_id: The event ID.
  # @return: An ApiEvent.
  #######################################################################
  def self.get_event (resource_root, event_id)
    path = "#{EVENTS_PATH}/#{event_id}"
    resp = resource_root.get(path)
    return ApiEvent.from_json_dict(resp, resource_root)
  end
  
  #----------------------------------------------------------------------
  # Class methods.
  #----------------------------------------------------------------------
  
  #######################################################################
  # _setattr (k, v)
  #######################################################################
  def _setattr (k, v)
    if k == 'timeOccurred' and !v.nil?
      @timeOccurred = api_time_to_datetime(v)
    elsif k == 'timeReceived' and !v.nil?
      @timeReceived = api_time_to_datetime(v)
    else
      BaseApiObject._setattr(self, k, v)
    end
  end
end
