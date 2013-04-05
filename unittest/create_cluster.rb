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
# CM API setup parameters.
#######################################################################
debug = true
server_host = "192.168.124.81"
server_port = "7180"
username = "admin"
password = "admin"
use_tls = false
version = "2"

#######################################################################
# Cluster setup paraameters.
#######################################################################
debug = true
clustername = "devel04"
cdhversion = "CDH4" 
rack_id = "/default"

#######################################################################
# Create the API resource object.
#######################################################################
api = ApiResource.new(server_host, server_port, username, password, use_tls, version, debug)

#######################################################################
# Create the cluster if it doesn't already exists.
#######################################################################
cluster_exists = api.cluster_exists?(clustername)
if cluster_exists
  print "cluster already exists [#{clustername}]\n" if debug
else
  print "cluster does not exists [#{clustername}]\n" if debug
  results = api.create_cluster(clustername, cdhversion)
  print "api.create_cluster(#{clustername}, #{cdhversion}) results : [#{results}]\n" if debug
end

host_list = [
{ :host_id => "d00-ff-ff-ff-ff-f0.hadoop.org", :name => "namenode1", :ipaddr => "192.168.124.150"},
{ :host_id => "d00-ff-ff-ff-ff-f1.hadoop.org", :name => "namenode2", :ipaddr => "192.168.124.151"},
{ :host_id => "d00-ff-ff-ff-ff-f2.hadoop.org", :name => "slavenode1", :ipaddr => "192.168.124.152"},
{ :host_id => "d00-ff-ff-ff-ff-f3.hadoop.org", :name => "slavenode2", :ipaddr => "192.168.124.153"},
{ :host_id => "d00-ff-ff-ff-ff-f4.hadoop.org", :name => "slavenode3", :ipaddr => "192.168.124.154"}
]

#######################################################################
# Create the host if it doesn't already exists.
#######################################################################
host_list.each do |host_rec|
  host_id = host_rec[:host_id]
  name = host_rec[:name]
  ipaddr = host_rec[:ipaddr]
  host_exists = api.host_exists?(host_id)
  if host_exists
    print "host already exists [#{host_id}]\n" if debug
  else
    print "host does not exists [#{host_id}]\n" if debug
    results = api.create_host(host_id, name, ipaddr, rack_id)
    print "api.create_host results(#{host_id}, #{name}, #{ipaddr}, #{rack_id}) : [#{results}]\n"
  end
end
