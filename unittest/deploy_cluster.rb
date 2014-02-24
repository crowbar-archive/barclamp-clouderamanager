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

libbase = File.join(File.dirname(__FILE__), '../chef/cookbooks/clouderamanager/libraries' )
require "#{libbase}/api_client.rb"

#######################################################################
# CM API setup parameters.
#######################################################################
debug = true
server_port = "7180"
username = "admin"
password = "admin"
use_tls = false
version = "2"

#######################################################################
# Cluster setup parameters.
#######################################################################
license_key = ''
cluster_name = "cluster01"
cdh_version = "CDH4" 
rack_id = "/default"

#######################################################################
# API logger class for debug/error logging.
#######################################################################
class ApiLogger
  def info(str)
    printf "#{str}\n"
  end
  
  def error(str)
    printf "#{str}\n"
  end
end
logger = ApiLogger.new

#######################################################################
# Cluster node configuration.
#######################################################################
namenodes = [
{ :fqdn => 'd00-0c-29-38-86-df.pod.openstack.org', :ipaddr => '192.168.124.85', :name => 'd00-0c-29-38-86-df.pod.openstack.org', :ssh_key => '' },
{ :fqdn => 'd00-0c-29-bf-b0-fa.pod.openstack.org', :ipaddr => '192.168.124.84', :name => '', :ssh_key => 'd00-0c-29-bf-b0-fa.pod.openstack.org' }
] 

datanodes = [
{ :fqdn => 'd00-0c-29-ab-af-1a.pod.openstack.org', :ipaddr => '192.168.124.81', :name => 'd00-0c-29-ab-af-1a.pod.openstack.org', :ssh_key => '' },
{ :fqdn => 'd00-0c-29-11-5f-c1.pod.openstack.org', :ipaddr => '192.168.124.83', :name => 'd00-0c-29-11-5f-c1.pod.openstack.org', :ssh_key => '' },
{ :fqdn => 'd00-0c-29-8a-58-e8.pod.openstack.org', :ipaddr => '192.168.124.82', :name => 'd00-0c-29-8a-58-e8.pod.openstack.org', :ssh_key => '' }
]

edgenodes = [
{ :fqdn => 'd00-0c-29-06-87-7d.pod.openstack.org', :ipaddr => '192.168.124.86', :name => 'd00-0c-29-06-87-7d.pod.openstack.org', :ssh_key => '' }
] 

cmservernodes = [
{ :fqdn => 'd00-0c-29-06-87-7d.pod.openstack.org', :ipaddr => '192.168.124.86', :name => 'd00-0c-29-06-87-7d.pod.openstack.org', :ssh_key => '' }
]

hafilernodes = [] 
hajournalingnodes =[]  
server_host = cmservernodes[0][:ipaddr]

#######################################################################
# Create the API client object.
#######################################################################
deployment_ok = false
api = CmApiClient.new(logger, server_host, server_port, username, password, use_tls, version, debug)

if api
  deployment_ok = api.deploy_cluster(license_key, cluster_name, cdh_version, rack_id, namenodes,
                                     datanodes, edgenodes, cmservernodes, hafilernodes, hajournalingnodes)
else
  logger.error("CM - ERROR: Cannot create CM API client")
end

if (deployment_ok)
  logger.info("CM - Hadoop cluster deployment successful")
else
  logger.error("CM - ERROR: Hadoop cluster deployment failed")
end

