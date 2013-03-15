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
server_host = "192.168.124.82"
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
# Get the API version
#######################################################################
#----------------------------------------------------------------------
# API related methods.
#----------------------------------------------------------------------

# api.version
results = api.version()
print "api.version : [#{results}]\n"

#----------------------------------------------------------------------
# Utils related methods.
#----------------------------------------------------------------------

# Convert a time string received from the API into a datetime object.
# This method is used internally for db date/time conversion with UTC. 
# The input timestamp is expected to be in ISO 8601 format with the "Z"
# sufix to express UTC.
results = api_time_to_datetime("2012-02-18T01:01:03.234Z")
print "api_time_to_datetime(2012-02-18T01:01:03.234Z) : [#{results}]\n"

#----------------------------------------------------------------------
# Cluster related methods.
#----------------------------------------------------------------------

# api.get_all_clusters()
results = api.get_all_clusters()
print "api.get_all_clusters() : [#{results}]\n"

# create_cluster
clustername = "testcluster1"
cdhversion = "CDH4" 
results = api.create_cluster(clustername, cdhversion)
print "api.create_cluster(#{clustername}, #{cdhversion}) results : [#{results}]\n"

# api.get_cluster
clustername = "testcluster1"
results = api.get_cluster(clustername)
print "api.get_cluster(#{clustername}) : [#{results}]\n"

# delete cluster
clustername = "testcluster1"
cdhversion = "CDH4" 
results = api.delete_cluster(clustername)
print "api.delete_cluster(#{clustername}) results : [#{results}]\n"

#----------------------------------------------------------------------
# Hosts related methods.
#----------------------------------------------------------------------

# api.create_host
host_id = "d00-0c-29-06-87-ff.pod.openstack.org"
name = "testhost"
ipaddr = "192.168.124.86"
rack_id = "/default"
# results = api.create_host(host_id, name, ipaddr, rack_id)
# print "api.create_host results(#{host_id}, #{name}, #{ipaddr}, #{rack_id}) : [#{results}]\n"

# api.get_all_hosts
results = api.get_all_hosts('full')
print "api.get_all_hosts results : [#{results}]\n"

# api.get_host
host_id = "d00-0c-29-06-87-7d.pod.openstack.org"
results = api.get_host(host_id)
print "api.get_host (#{host_id}) results : [#{results}]\n"

#----------------------------------------------------------------------
# User related methods.
#----------------------------------------------------------------------

# api.get_all_users
results = api.get_all_users('full')
print "api.get_all_users results : [#{results}]\n"

#----------------------------------------------------------------------
# cms related methods.
#----------------------------------------------------------------------

# api.get_license
results = api.get_license()
print "api.api.get_license results : [#{results}]\n"

#----------------------------------------------------------------------
# Tool related methods.
#----------------------------------------------------------------------

# api.echo - Have the server echo a message back.
results = api.echo("Test API echo method call")
print "api.echo() results : [#{results}]\n"

# api.echo_error - Generate an error, but we get to set the error message.
# This will always generate an exception when called.
begin
  results = api.echo_error("Test API echo_error method call")
  print "api.echo_error() results : [#{results}]\n"
rescue Exception => e   
  # Catch the exception
  # puts e.message   
  # puts e.backtrace.inspect   
end