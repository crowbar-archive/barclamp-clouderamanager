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

libbase = File.join(File.dirname(__FILE__), '../chef/cookbooks/clouderamanager/libraries' )
require "#{libbase}/api_client.rb"
require "#{libbase}/utils.rb"

#######################################################################
# Local variables.
#######################################################################
debug = true
server_host = "192.168.124.83"
server_port = "7180"
username = "admin"
password = "admin"
use_tls = false
version = "2"

#######################################################################
# Create the API resource object.
#######################################################################
print "create API resource [#{server_host}, #{server_port}, #{username}, #{password}, #{use_tls}, #{version}, #{debug}]\n" if debug
api = ApiResource.new(server_host, server_port, username, password, use_tls, version, debug)

#######################################################################
# api.version
#######################################################################
results = api.version()
print "api.version : [#{results}]\n"

#####################################################################
# Check the license key and update if needed.
#####################################################################
def check_license_key(debug, api, license_key)
  license_check  = api.get_license()
  print "api.api.get_license results : [#{license_check}]\n"
  # Note: get_license will report nil until the cm-server has been restarted.
  if license_check.nil?
    results = api.update_license(license_key)
    print "api.update_license results : [#{results}]\n"
  end
end

#####################################################################
# MAIN
#####################################################################
license_path = File.join(File.dirname(__FILE__), 'license_file.txt' )
f = File.open(license_path)
license_key = ""
while line = f.gets do
  license_key = license_key + line
end
f.close
check_license_key(debug, api, license_key)



