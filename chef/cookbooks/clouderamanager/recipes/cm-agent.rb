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

# Install the Cloudera Manager agent packages.
agent_packages=%w{
  cloudera-manager-daemons
  cloudera-manager-agent
}

agent_packages.each do |pkg|
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

# Create the agent config file. Do not update after after initial deployment
# of the hadoop cluster (CM will manage this file).
# If we are programmatically configuring the cluster, we need to set the
# cm server FQDN. Otherwise, let CM configure this parameter setting.
agent_config_file = "/etc/cloudera-scm-agent/config.ini"
cm_server = 'not_configured'
if node[:clouderamanager][:cmapi][:deployment_type] == 'auto'
  search(:node, "roles:clouderamanager-server#{env_filter}") do |n|
    if n[:fqdn] && !n[:fqdn].empty? 
      cm_server = n[:fqdn]
      break;
    end
  end
end

# TODO: Need a better check here because the !File.exists check is not
# reliable during node state transition (typical chef role sync problem).
if !File.exists?(agent_config_file) or cm_server != 'not_configured' 
  Chef::Log.info("CM - configuring cm-agent settings [#{agent_config_file}, #{cm_server}]") if debug
  vars = { :cm_server => cm_server } 
  template agent_config_file do
    source "cm-agent-config.erb" 
    variables( :vars => vars )
    notifies :restart, "service[cloudera-scm-agent]"
  end
else
  Chef::Log.info("CM - cm-agent already configured - skipping [#{agent_config_file}]") if debug
end

# Start the cloudera agent service.
service "cloudera-scm-agent" do
  action :start 
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-agent") if debug
