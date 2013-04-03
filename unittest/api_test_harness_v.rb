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

libbase = File.join(File.dirname(__FILE__), '../chef/cookbooks/clouderamanager/libraries/cmapi' )
require "#{libbase}/api_client.rb"
require "#{libbase}/utils.rb"

#######################################################################
# Local variables.
#######################################################################
server_host = "192.168.124.87"
server_port = "7180"
username = "admin"
password = "admin"
use_tls = false
version = "2"

#######################################################################
# Create the API resource object.
#######################################################################
api = ApiResource.new(server_host, server_port, username, password, use_tls, version)

#######################################################################
# Open the license file for reading
#######################################################################
f = File.open("dell-devel-05-02282014_cloudera_enterprise_license_Vinayak.txt")
contents = ""
while line = f.gets do
    contents = contents + line
end
f.close

# Get current Cloudera License Information
print api.get_license

# Update Cloudera Manager with the new text information
api.update_license(contents)
