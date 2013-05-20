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

# Create the agent configuration file. Do not update after after initial deployment
# of the hadoop cluster (CM will manage this file). If we are programmatically
# configuring the cluster, we need to set the cm server FQDN. Otherwise, let
# CM configure this parameter setting on initial cluster deployment.
cm_server = 'not_configured'
agent_config_file = "/etc/cloudera-scm-agent/config.ini"
if node[:clouderamanager][:cmapi][:deployment_type] == 'manual'
  # We need to let CM configure and start the cm-agent
  # processes or the Hadoop base packages will not be installed. CM makes the 
  # general assumption that all the Hadoop base packages are installed if it
  # already see's the agents heartbeating on the network.
  # Only update the file the first time around.
  if !File.exists?(agent_config_file) 
    Chef::Log.info("CM - Configuring cm-agent settings [#{agent_config_file}, #{cm_server}]") if debug
    vars = { :cm_server => cm_server } 
    template agent_config_file do
      source "cm-agent-config.erb" 
      variables( :vars => vars )
      notifies :restart, "service[cloudera-scm-agent]"
    end
  else
    Chef::Log.info("CM - cm-agent already configured - skipping [#{agent_config_file}]") if debug
  end
else
  # deployment_type == 'auto'. Ok to start the cm-agents pre-configured because we
  # have already have the Hadoop base packages installed in this mode.
  cmservernodes = node[:clouderamanager][:cluster][:cmservernodes]
  if cmservernodes and cmservernodes.length > 0 
    rec = cmservernodes[0]
    cm_server = rec[:fqdn]
  end
  # Only if we have a valid IP address for the cm-server node.
  if cm_server != 'not_configured'
    # Only update the file the first time around.
    if !File.exists?(agent_config_file) 
      Chef::Log.info("CM - Configuring cm-agent settings [#{agent_config_file}, #{cm_server}]") if debug
      vars = { :cm_server => cm_server } 
      template agent_config_file do
        source "cm-agent-config.erb" 
        variables( :vars => vars )
        notifies :restart, "service[cloudera-scm-agent]"
      end
    else
      Chef::Log.info("CM - cm-agent already configured - skipping [#{agent_config_file}]") if debug
    end
  else
    Chef::Log.info("CM - waiting for a valid cm-server address - skipping [#{agent_config_file}]") if debug
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
