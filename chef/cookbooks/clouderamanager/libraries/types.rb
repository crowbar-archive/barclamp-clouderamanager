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

#######################################################################
# BaseApiObject
#
# The BaseApiObject helps with deserialization and deserialization from/to JSON.
# To take advantage of it, the derived class needs to define;
#   RW_ATTR - A list of mutable attributes.
#   RO_ATTR - A list of immutable attributes.
# 
# The derived class's ctor must take all the RW_ATTR as arguments.
# When de-serializing from JSON, all attributes will be set. Their
# names are taken from the keys in the JSON object.
# 
# Reference objects(e.g. hostRef, clusterRef) are automatically
# deserialized. They can be accessed as attributes.
#######################################################################
class BaseApiObject < Object
  
  RO_ATTR = [ ] # Derived classes should override this.
  RW_ATTR = [ ] # Derived classes should override this.
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    @resource_root = resource_root
    dict.each do |k, v|
=begin
      if k not in @RW_ATTR
        raise ArgumentError, "Unexpected argument #{k} in #{self.class.name}"
      end
=end
      setattr(k, v)
    end
  end
  
  #######################################################################
  # _get_resource_root
  #######################################################################
  def _get_resource_root
    return @resource_root
  end
  
  #######################################################################
  # Copy state from api_obj to this object.
  #######################################################################
  def _update(api_obj)
    if not isinstance(self, api_obj.class)
      raise ArgumentError, "Class #{self.class.name} does not derive from #{api_obj.class.name}; cannot update attributes."
    end
    
    for attr in @RW_ATTR + @RO_ATTR
      begin
        val = getclassattr(api_obj, attr)
        setclassattr(self, attr, val)
      rescue Exception => e   
        puts e.message   
        puts e.backtrace.inspect   
      end
    end
  end
  
  #######################################################################
  # Set an object attribute. 
  #######################################################################
  def setclassattr(cls, k, v)
    cls.instance_variable_set("@#{k}", v)
  end
  
  def setattr(k, v)
    setclassattr(self, k, v)
  end
  
  #######################################################################
  # Get a object attribute. 
  #######################################################################
  
  def getclassattr(cls, k)
    cls.instance_variable_get("@#{k}")
  end
  
  def getattr(k)
    getclassattr(self, k)
  end
  
  #######################################################################
  # Place holder to deal with unicode strings.
  #######################################################################
  def self.fix_unicode_kwargs(dic)
    return dic
  end
  
  #######################################################################
  # to_json_dict(cls)
  #######################################################################
  def to_json_dict(cls)
    dict = {}
    cls::RW_ATTR.each do |attr| 
      value = getclassattr(self, attr)
      begin
        # If the value has to_json_dict(), call it
        value = value.to_json_dict(cls)
      rescue Exception => e   
        # puts e.message   
        # puts e.backtrace.inspect   
      end
      dict[attr] = value
    end
    return dict
  end
  
  #######################################################################
  # from_json_dict(cls, dic, resource_root)
  #######################################################################
  def self.from_json_dict(cls, dic, resource_root)
    rw_dict = {}
    dic.each do |k, v|
      if cls::RW_ATTR.include?(k)
        rw_dict[k] = v
        dic.delete(k)
      end
    end
    
    # Construct object based on RW_ATTR
    rw_dict = fix_unicode_kwargs(rw_dict)
    obj = cls.new(resource_root, rw_dict)
    
    # Initialize all RO_ATTR to be nil
    cls::RO_ATTR.each do |attr| 
      obj.setattr(attr, nil)
    end
    
    # Now set the RO_ATTR based on the json
    dic.each do  |k, v| 
      if cls::RO_ATTR.include?(k)
        obj.setattr(k, v)
      else
        print "Unexpected attribute #{k} in #{cls.class.name} json\n"
      end
    end
    return obj
  end
end

#######################################################################
# ApiList - A list of API objects.
#######################################################################
class ApiList < Object
  
  LIST_KEY = "items"
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(objects)
    @objects = objects
  end
  
  #######################################################################
  # length
  #######################################################################
  def __len__
    return @objects.length
  end
  
=begin  
  #######################################################################
  # __iter__
  #######################################################################
  def __iter__
    return @objects.__iter__()
  end
=end
  
  #######################################################################
  # [](i)
  #######################################################################
  def [](i)
    return @objects[i]
  end
  
  #######################################################################
  # __getslice(i, j)
  #######################################################################
  def __getslice(i, j)
    return @objects[i..j]
  end
  
  #######################################################################
  # to_array
  #######################################################################
  
  def to_array
    return @objects
  end
  
  #######################################################################
  # to_json_dict(cls)
  #######################################################################
  def to_json_dict(cls)
    ary = []
    @objects.each do |x|
      ary << x.to_json_dict(cls)
    end
    rec = { ApiList::LIST_KEY => ary }
    return rec
  end
  
  #######################################################################
  # from_json_dict(member_cls, dic, resource_root)
  #######################################################################
  def self.from_json_dict(member_cls, dic, resource_root)
    objs = [ ]
    json_list = dic[ApiList::LIST_KEY]
    json_list.each do |x| 
      objs << member_cls.from_json_dict(member_cls, x, resource_root)
    end
    return ApiList.new(objs)
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    str = @objects.join(",")
    return "<ApiList> (length:#{@objects.length}, str:#{str})"
  end
end

#######################################################################
# ApiCommand - Information about a command.
#######################################################################
class ApiCommand < BaseApiObject
  
  SYNCHRONOUS_COMMAND_ID = -1
  
  RO_ATTR = [ 'id', 'name', 'startTime', 'endTime', 'active', 'success',
             'resultMessage', 'clusterRef', 'serviceRef', 'roleRef',
             'hostRef', 'children', 'parent', 'resultDataUrl' ]
  
  RW_ATTR = [ ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # _path
  #######################################################################
  def _path
    return "/commands/#{@id}"
  end
  
  #######################################################################
  # setattr(k, v)
  #######################################################################
  def setattr(k, v)
    if k == 'children' and v.not_equal? nil
      v = ApiList.from_json_dict(ApiCommand, v, _get_resource_root())
    elsif k == 'parent' and v.not_equal? nil
      v = ApiCommand.from_json_dict(v, _get_resource_root())
    end
    BaseApiObject.setclassattr(self, k, v)
  end
  
  #######################################################################
  # Retrieve updated data about the command from the server.
  # @param resource_root: The root Resource object.
  # @return: A new ApiCommand object.
  #######################################################################
  def fetch
    if @id == ApiCommand.SYNCHRONOUS_COMMAND_ID
      return self
    end
    resp = _get_resource_root().get(_path())
    return ApiCommand.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # Wait for command to finish.
  # @param timeout:(Optional) Max amount of time(in seconds) to wait. Wait
  # forever by default.
  # @return: The final ApiCommand object, containing the last known state.
  # The command may still be running in case of timeout.
  #######################################################################
  def wait(timeout=nil)
    if @id == ApiCommand.SYNCHRONOUS_COMMAND_ID
      return self
    end
    
    sleep_sec = 5
    
    if timeout.equal? nil
      deadline = nil
    else
      deadline = time.time() + timeout
    end
    
    while true
      cmd = fetch()
      if not cmd.active
        return cmd
      end
      
      if deadline.not_equal? nil
        now = time.time()
        if deadline < now
          return cmd
        else
          time.sleep(min(sleep_sec, deadline - now))
        end
      else
        time.sleep(sleep_sec)
      end
    end
  end
  
  #######################################################################
  # Abort a running command.
  # @param resource_root: The root Resource object.
  # @return: A new ApiCommand object with the updated information.
  #######################################################################
  def abort
    if @id == ApiCommand.SYNCHRONOUS_COMMAND_ID
      return self
    end
    subpath = _path() + '/abort'
    resp = _get_resource_root().post(subpath)
    return ApiCommand.from_json_dict(resp, _get_resource_root())
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiCommand> (name:#{@name}, id:#{@id}, active:#{@active}, success:#{@success})"
  end
end

#######################################################################
# ApiMetricData - Metric reading data.
#######################################################################
class ApiMetricData < BaseApiObject
  
  RO_ATTR = [ 'timestamp', 'value' ]
  RW_ATTR = [ ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiMetricData> (timestamp:#{@timestamp}, value:#{@value})"
  end
end

#######################################################################
# ApiMetricData - Metric information.
#######################################################################
class ApiMetric < BaseApiObject
  
  RO_ATTR = [ 'name', 'context', 'unit', 'data', 'displayName', 'description' ]
  RW_ATTR = [ ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # setattr(k, v)
  #######################################################################
  def setattr(k, v)
    if k == 'data'
      if v
        assert isinstance(v, list)
        @data = []
        v do |x| 
          @data << ApiMetricData.from_json_dict(x, _get_resource_root())
        end
      else
        BaseApiObject.setclassattr(self, k, v)
      end
    end
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiMetric> (name:#{@name}, description:#{@description})"
  end
end  

#######################################################################
# ApiActivity
#######################################################################
class ApiActivity < BaseApiObject
  
  RO_ATTR = [ 'name', 'type', 'parent', 'startTime', 'finishTime', 'id',
      'status', 'use/, /group', 'inputDi/, /outputDi/, /mappe/, /combiner',
      'reduce/, /queueName', 'schedulerPriority' ]
  
  RW_ATTR = [ ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiActivity> (name:#{@name} (status:#{@status})"
  end
end

#######################################################################
# ApiConfig - Configuration helpers.
#######################################################################
class ApiConfig < BaseApiObject
  
  RO_ATTR = [ 'required', 'default', 'displayName', 'description',
      'relatedName', 'validationState', 'validationMessage' ]
  
  RW_ATTR = [ 'name', 'value' ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, name, value = nil)
    dict = {}
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # Converts a dictionary into a list containing the proper
  # ApiConfig encoding for configuration data.
  # @param dic Key-value pairs to convert.
  # @return JSON dictionary of an ApiConfig list(*not* an ApiList).
  #######################################################################
  def config_to_api_list(dic)
    config = [ ]
    dic.iteritems().each do |k, v|
      config << { :name => k, :value => v }
    end
    return { ApiList.LIST_KEY => config }
  end
  
  #######################################################################
  # Converts a python dictionary into a JSON payload.
  # The payload matches the expected "apiConfig list" type used to update
  # configuration parameters using the API.
  # @param dic Key-value pairs to convert.
  # @return String with the JSON-encoded data.
  #######################################################################
  def config_to_json(dic)
    return JSON.generate(config_to_api_list(dic))
  end
  
  #######################################################################
  # Converts a JSON-decoded configuration dictionary to a ruby dictionary.
  # When materializing the full view, the values in the dictionary will be
  # instances of ApiConfig, instead of strings.
  # @param dic JSON-decoded configuration dictionary.
  # @param full Whether to materialize the full view of the config data.
  # @return dictionary with configuration data.
  #######################################################################
  def self.json_to_config(dic, resource_root, view)
    config = { }
    items = dic['items']
    items.each do |entry|
      k = entry['name']
      if view == 'full'
        config[k] = ApiConfig.from_json_dict(ApiConfig, entry, resource_root)
      else
        config[k] = entry['value']
      end
    end
    return config
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiConfig> (name:#{@name}, value:#{@value})"
  end
end

#######################################################################
# ApiHostRef
#######################################################################
class ApiHostRef < BaseApiObject
  
  RO_ATTR = [ ]
  RW_ATTR = [ 'hostId' ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiHostRef> (hostId:#{@hostId})"
  end
end

#######################################################################
# ApiServiceRef
#######################################################################
class ApiServiceRef < BaseApiObject
  
  RO_ATTR = [ ]
  RW_ATTR = [ 'clusterName', 'serviceName' ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiServiceRef> (clusterName:#{@clusterName}, serviceName:#{@serviceName})"
  end
end

#######################################################################
# ApiClusterRef
#######################################################################
class ApiClusterRef < BaseApiObject
  
  RO_ATTR = [ ]
  RW_ATTR = [ 'clusterName' ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiClusterRef> (clusterName:#{@clusterName})"
  end
end

#######################################################################
# ApiRoleRef
#######################################################################
class ApiRoleRef < BaseApiObject
  
  RO_ATTR = [ ]
  RW_ATTR = [ 'clusterName', 'serviceName', 'roleName' ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiRoleRef> (clusterName:#{@clusterName}, serviceName:#{@serviceName}, roleName:#{@roleName})"
  end
end

#######################################################################
# ApiLicense - Model for a CM license.
#######################################################################
class ApiLicense < BaseApiObject
  
  RO_ATTR = [ 'owner', 'uuid', 'expiration' ]
  RW_ATTR = [ ]
  
  #######################################################################
  # Class Initializer.
  #######################################################################
  def initialize(resource_root, dict)
    BaseApiObject.new(resource_root, dict)
    dict.each do |k, v|
      self.instance_variable_set("@#{k}", v) 
    end
  end
  
  #######################################################################
  # to_s
  #######################################################################
  def to_s
    return "<ApiLicense> (owner:#{@owner}, uuid:#{@uuid}, expiration:#{@expiration})"
  end
end
