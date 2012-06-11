#
# Cookbook Name: clouderamanager
# Recipe: cm-ha-filer-export.rb
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

#######################################################################
# Begin recipe
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:cm-ha-filer-export") if debug

# Configuration filter for the crowbar environment and local variables.
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"
exports_file = "/etc/exports"
admin_subnet = node[:network][:networks][:admin][:subnet]
admin_netmask = node[:network][:networks][:admin][:netmask]
shared_edits_directory = node[:clouderamanager][:ha][:shared_edits_directory]
shared_edits_export_options = node[:clouderamanager][:ha][:shared_edits_export_options]

# Make sure the nfs & exportfs packages are installed.
# We install the hadoop-hdfs package so we can set the owner and group
# for the remote directory.
pkg_list=%w{
   nfs-utils
  }

pkg_list.each do |pkg|
  package pkg do
    action :install
  end
end

# Create the directory for the HA filer mount point. 
directory shared_edits_directory do
  owner "hdfs"
  group "hadoop"
  mode "0700"
  recursive true
end

# Ensure that rpcbind is running for the HA filer mount point export.
#  /etc/init.d/rpcbind {start|stop|status|restart|reload|force-reload|condrestart|try-restart}
service "rpcbind" do
  supports :start => true, :stop => true, :status => true, :restart => true  
  action [ :enable, :start ]
end

# Ensure that NFS is running for the HA filer file mount point export.
# nfs {start|stop|status|restart|reload|force-reload|condrestart|try-restart|condstop}
service "nfs" do
  supports :start => true, :stop => true, :status => true, :restart => true  
  action [ :enable, :start ]
end

# Ensure that the HA filer file system is exported.
execute "hadoop-ha-nfs-export" do
  command "exportfs -a"
  action :nothing
end

# Add the file system exports line if not ready there.
file exports_file do
  new_lines = "#{shared_edits_directory} #{admin_subnet}/#{admin_netmask}(#{shared_edits_export_options})"
  Chef::Log.info("CM - exportfs check [#{new_lines}]") if debug
  
  # Get current content, check for duplication
  only_if do
    current_content = File.read(exports_file)
    current_content.index(shared_edits_directory).nil?
  end
  
  # Set up the file and content.
  owner "root"
  group "root"
  mode  "0644"
  current_content = File.read(exports_file)
  new_content = current_content + new_lines
  content "#{new_content}\n"
  notifies :run, "execute[hadoop-ha-nfs-export]", :delayed
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-ha-filer-export") if debug
