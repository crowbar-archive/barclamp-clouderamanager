#
# Cookbook Name: clouderamanager
# Recipe: cm-agent.rb
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

include_recipe 'clouderamanager::cm-common'

#######################################################################
# Begin recipe
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:cm-agent") if debug

# Configuration filter for the crowbar environment.
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

# Install the Cloudera client packages.
pkg_list=%w{
  cloudera-manager-agent
  cloudera-manager-daemons
}

pkg_list.each do |pkg|
  package pkg do
    action :install
  end
end

# Define the cloudera agent service.
# /etc/init.d/cloudera-manager-agent {start|stop|restart|status}
service "cloudera-scm-agent" do
  supports :start => true, :stop => true, :restart => true, :status => true 
  action :enable 
end

# If in auto deployment mode, install all the CDH packages.
if node[:clouderamanager][:cluster][:node_discovery] && node[:clouderamanager][:cluster][:node_discovery] != 'manual'
  ext_pkg_list=%w{
    bigtop-jsvc
    bigtop-tomcat
    hadoop-hdfs
    hadoop-httpfs
    hadoop-mapreduce
    hadoop-client
    hbase
    hive
    oozie
    pig
    hue-common
    hue-proxy
    hue-about
    hue-help
    hue-filebrowser
    hue-jobbrowser
    hue-jobsub
    hue-beeswax
    hue-useradmin
    hue-shell
    hue
}
  
  ext_pkg_list.each do |pkg|
    package pkg do
      action :install
    end
  end
    
  # If in auto node discovery mode, configure and start the cm agents.
  # The cm server will automatically discover the agents when it see's the heartbeat on that node.
  # First - Locate the Cloudera Manager server node.
  cm_server_ip = nil
  search(:node, "roles:clouderamanager-webapp#{env_filter}") do |cm_node|
    cm_server_ip = BarclampLibrary::Barclamp::Inventory.get_network_by_type(cm_node, "admin").address
    break;
  end
  
  # Update the agent config file with the cm server host if the ip address is valid.
  if cm_server_ip
    Chef::Log.info("CM checking agent server_host setting [#{cm_server_ip}]") if debug
    agent_config_file = "/etc/cloudera-scm-agent/config.ini"
    vars = { :cm_server_ip => cm_server_ip } 
    template agent_config_file do
      source "cm-agent-config.erb" 
      variables( :vars => vars )
      notifies :restart, "service[cloudera-scm-agent]"
    end
  else
    Chef::Log.info("CM - server not found - cannot update agent server_host") if debug
  end
end

# Start the cloudera agent service.
service "cloudera-scm-agent" do
  action :start 
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-agent") if debug
