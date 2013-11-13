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
# Tools
#######################################################################
class Tools
  
  #######################################################################
  # initialize
  #######################################################################
  def initialize
  end
  
  #######################################################################
  # echo(root_resource, message)
  # Have the server echo our message back.
  #######################################################################
  def self.echo(root_resource, message)
    params = { :message => message }
    path = '/tools/echo'
    return root_resource.get(path, params)
  end
  
  #######################################################################
  # echo_error(root_resource, message)
  # Generate an error, but we get to set the error message.
  #######################################################################
  def self.echo_error(root_resource, message)
    params = { :message => message }
    path = '/tools/echoError'
    return root_resource.get(path, params)
  end
end
