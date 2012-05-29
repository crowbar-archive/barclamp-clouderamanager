#
# Cookbook Name: clouderamanager
# Recipe: cm-client.rb
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
Chef::Log.info("CM - BEGIN clouderamanager:cm-client") if debug

# Configuration filter for our crowbar environment.
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

# Start the cloudera agent service.
service "cloudera-scm-agent" do
  action :start 
end

#######################################################################
# End of recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-client") if debug
