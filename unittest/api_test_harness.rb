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
server_host = "192.168.124.81"
server_port = "7180"
username = "admin"
password = "admin"
use_tls = false
version = "2"

#######################################################################
# Create the API resource object.
#######################################################################
api = ApiResource.new(server_host, server_port, username, password, use_tls, version, debug)

#----------------------------------------------------------------------
# API related methods.
#----------------------------------------------------------------------

#######################################################################
# api.version
#######################################################################
results = api.version()
print "api.version : [#{results}]\n"

#----------------------------------------------------------------------
# Utility related methods.
#----------------------------------------------------------------------

#######################################################################
# api_time_to_datetime
# Convert a time string received from the API into a datetime object.
# This method is used internally for db date/time conversion with UTC. 
# The input timestamp is expected to be in ISO 8601 format with the "Z"
# sufix to express UTC.
#######################################################################
results = api_time_to_datetime("2012-02-18T01:01:03.234Z")
print "api_time_to_datetime(2012-02-18T01:01:03.234Z) : [#{results}]\n"

#----------------------------------------------------------------------
# Cluster related methods.
#----------------------------------------------------------------------

#######################################################################
# api.get_all_clusters
#######################################################################
view = 'full'
results = api.get_all_clusters(view)
print "api.get_all_clusters() : [#{results}]\n"

#######################################################################
# api.create_cluster
#######################################################################
cdhversion = "CDH4" 
clusters = [ "testcluster1", "testcluster2"]
cluster_object = nil
clusters.each do |cluster_name|
  cluster_object = api.find_cluster(cluster_name)
  if cluster_object == nil
    print "cluster does not exists [#{cluster_name}]\n"
    cluster_object = api.create_cluster(cluster_name, cdhversion)
    print "api.create_cluster(#{cluster_name}, #{cdhversion}) results : [#{cluster_object}]\n"
  else
    print "cluster already exists [#{cluster_name}] results : [#{cluster_object}]\n"
  end
end

#######################################################################
# api.get_cluster
#######################################################################
cluster_name = "testcluster1"
results = api.get_cluster(cluster_name)
print "api.get_cluster(#{cluster_name}) : [#{results}]\n"

#######################################################################
# api.delete_cluster (only testcluster1)
#######################################################################
cluster_name = "testcluster1"
cdhversion = "CDH4" 
results = api.delete_cluster(cluster_name)
print "api.delete_cluster(#{cluster_name}) results : [#{results}]\n"

#----------------------------------------------------------------------
# Service related methods.
#----------------------------------------------------------------------

#######################################################################
# api.get_all_services
#######################################################################
cluster_name = "testcluster2"
results = api.get_all_services(cluster_name, 'full')
print "api.get_all_services() : [#{results}]\n"

#######################################################################
# api.find_service
#######################################################################
cluster_name = "testcluster2"
service_name = "mapreduce01"
service_type = "MAPREDUCE"
service_object = api.find_service(service_name, cluster_name)
if service_object == nil
  print "service does not exists [#{service_name}, #{service_type}, #{cluster_name}]\n" if debug
  service_object = api.create_service(cluster_object, service_name, service_type, cluster_name)
  print "api.create_service([#{service_name}, #{service_type}, #{cluster_name}]) results : [#{service_object}]\n" if debug
else
  print "service already exists [#{service_name}, #{service_type}, #{cluster_name}] results : [#{service_object}]\n" if debug
end

#----------------------------------------------------------------------
# Hosts related methods.
#----------------------------------------------------------------------

#######################################################################
# api.create_host
#######################################################################
rack_id = "/default"
host_list = [
{ :host_id => "d00-ff-ff-ff-ff-f0.hadoop.org", :name => "namenode1", :ipaddr => "192.168.124.150"},
{ :host_id => "d00-ff-ff-ff-ff-f1.hadoop.org", :name => "namenode2", :ipaddr => "192.168.124.151"},
{ :host_id => "d00-ff-ff-ff-ff-f2.hadoop.org", :name => "slavenode1", :ipaddr => "192.168.124.152"},
{ :host_id => "d00-ff-ff-ff-ff-f3.hadoop.org", :name => "slavenode2", :ipaddr => "192.168.124.153"},
{ :host_id => "d00-ff-ff-ff-ff-f4.hadoop.org", :name => "slavenode3", :ipaddr => "192.168.124.154"}
]

host_list.each do |host_rec|
  host_id = host_rec[:host_id]
  name = host_rec[:name]
  ipaddr = host_rec[:ipaddr]
  host_object = api.find_host(host_id)
  if host_object == nil
    print "host does not exists [#{host_id}]\n"
    host_object = api.create_host(host_id, name, ipaddr, rack_id)
    print "api.create_host results(#{host_id}, #{name}, #{ipaddr}, #{rack_id}) results : [#{host_object}]\n"
  else
    print "host already exists [#{host_id}] results : [#{host_object}]\n"
  end
end

#######################################################################
# api.delete_host
#######################################################################
host_id = host_list[0][:host_id]
results = api.delete_host(host_id)
print "api.delete_host results(#{host_id}) : [#{results}]\n"

#######################################################################
# api.get_all_hosts
#######################################################################
results = api.get_all_hosts('full')
print "api.get_all_hosts results : [#{results}]\n"

#######################################################################
# api.get_host
#######################################################################
host_id = "d00-0c-29-06-87-7d.pod.openstack.org"
results = api.get_host(host_id)
print "api.get_host (#{host_id}) results : [#{results}]\n"

#----------------------------------------------------------------------
# User related methods.
#----------------------------------------------------------------------

#######################################################################
# api.get_all_users
#######################################################################
results = api.get_all_users('full')
print "api.get_all_users results : [#{results}]\n"

#----------------------------------------------------------------------
# cms related methods.
#----------------------------------------------------------------------

#######################################################################
# api.get_license
#######################################################################
results = api.get_license()
print "api.api.get_license results : [#{results}]\n"

#######################################################################
# api.update_license
#######################################################################
=begin
f = File.open("dell-devel-06-02282014_cloudera_enterprise_license.txt")
contents = ""
while line = f.gets do
  contents = contents + line
end
f.close

# Update Cloudera Manager with the new license information
results = api.update_license(contents)
print "api.get_license results : [#{results}]\n"
=end

#######################################################################
# api.get_config
# The 'summary' view contains strings as the dictionary values.
# The 'full' view contains ApiConfig instances as the values.
#######################################################################
view = 'summary'
results = api.get_config(view)
if view == 'full'
  print "api.api.get_config results;\n"
  results.each do |apiconfig|
    print "#{apiconfig.to_s}\n"
  end
else
  print "api.api.get_config results;\n"
  results.each do |k, v|
    print "#{k}=#{v}\n"
  end
end

#----------------------------------------------------------------------
# Tool related methods.
#----------------------------------------------------------------------

#######################################################################
# api.echo - Have the server echo a message back.
#######################################################################
results = api.echo("Test API echo method call")
print "api.echo() results : [#{results}]\n"

#######################################################################
# api.echo_error - Generate an error, but we get to set the error message.
# This will always generate an exception when called.
#######################################################################
begin
  results = api.echo_error("Test API echo_error method call")
  print "api.echo_error() results : [#{results}]\n"
rescue Exception => e   
  # Catch the exception
  # puts e.message   
  # puts e.backtrace.inspect   
end
