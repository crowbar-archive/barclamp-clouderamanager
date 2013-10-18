#
# Cookbook Name: clouderamanager
# Recipe: node-setup.rb
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
Chef::Log.info("CM - BEGIN clouderamanager:node-setup") if debug

# Configuration filter for the crowbar environment
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

#######################################################################
# Install the xfs file system support packages.
#######################################################################
fs_type = node[:clouderamanager][:os][:fs_type]
if fs_type == 'xfs'
  xfs_packages=%w{
    xfsprogs
  }
  
  xfs_packages.each do |pkg|
    package pkg do
      action :install
    end
  end
end

#######################################################################
# Ensure localtime is set consistently across the cluster (UTC).
#######################################################################
file "/etc/localtime" do
  action :delete
  only_if "test -F /etc/localtime"
end

link "/etc/localtime" do
  to "/usr/share/zoneinfo/Etc/UTC"
end

#######################################################################
# Ensure THP compaction is disabled/enabled based on the proposal setting.
#######################################################################
cur_thpval = node[:clouderamanager][:os][:thp_compaction]
Chef::Log.info("CM - Checking THP setting [#{cur_thpval}]") if debug

#----------------------------------------------------------------------
# Change it for current session.
#----------------------------------------------------------------------
defrag_file_pathname = "/sys/kernel/mm/redhat_transparent_hugepage/defrag"
Chef::Log.info("CM - Checking the THP setting in #{defrag_file_pathname} [#{cur_thpval}]") if debug

#----------------------------------------------------------------------
# Change it for current session
#----------------------------------------------------------------------
cur_buff = ''
if File.exists?(defrag_file_pathname)
  cur_buff = File.read(defrag_file_pathname)
  cur_buff = cur_buff.strip
end
Chef::Log.info("CM - Current setting [#{cur_buff}]") if debug
# Only rewrite the file if needed.
if (cur_thpval == 'never' and cur_buff != 'always [never]') or (cur_thpval == 'always' and cur_buff != '[always] never')
  # Need to create or re-write the file.
  Chef::Log.info("CM - Updating #{defrag_file_pathname} with the new THP setting [#{cur_thpval}]") if debug
  File.open(defrag_file_pathname, "w") { |file| file.puts "#{cur_thpval}\n" }
else
  # THP setting is correct. No updates required.
  Chef::Log.info("CM - No updates to #{defrag_file_pathname} required") if debug
end

#----------------------------------------------------------------------
# For future reboots, change rc.local file on the node.
#----------------------------------------------------------------------
rc_local_path = "/etc/rc.local"
Chef::Log.info("CM - Checking the THP setting in #{rc_local_path} [#{cur_thpval}]") if debug
# Read the rc.local file is it currently exists.
cur_buff = ''
if File.exists?(rc_local_path)
  cur_buff = File.read(rc_local_path)
end
# Parse the rc.local file for THP settings.
new_buff = nil
thp_array = cur_buff.scan /^[\t ]*echo\s*(.+?)\s*>\s*\/sys\/kernel\/mm\/redhat_transparent_hugepage\/defrag[\t ]*$/m
rep_str = "echo #{cur_thpval} > /sys/kernel/mm/redhat_transparent_hugepage/defrag" 
if thp_array.length <= 0  
  # No current thp entry, append to the end of the file.
  if cur_buff.length == 0 or cur_buff[cur_buff.length - 1] == 10 
    # Last line already has a line ender.
    new_buff = cur_buff + rep_str
  else 
    # Last line does not already have a line ender.
    new_buff = cur_buff + "\n#{rep_str}"
  end
else
  # THP stanza already exists. Check the state and update if needed.
  reg_thpval = thp_array[thp_array.length - 1]
  if reg_thpval.to_s != cur_thpval
    Chef::Log.info("CM - THP setting needs updating [#{reg_thpval},#{cur_thpval}]") if debug
    new_buff = cur_buff.gsub(/^[\t ]*echo\s*(.+?)\s*>\s*\/sys\/kernel\/mm\/redhat_transparent_hugepage\/defrag[\t ]*$/, rep_str) 
  else
    Chef::Log.info("CM - Current THP setting is correct [#{reg_thpval},#{cur_thpval}]") if debug
  end
end  
# Only rewrite the file if needed.
if not new_buff.nil?
  # Need to create or re-write the file.
  Chef::Log.info("CM - Updating #{rc_local_path} with the new THP setting [#{cur_thpval}]") if debug
  File.open(rc_local_path, "w") { |file| file.puts new_buff }
else
  # THP setting is correct. No updates required.
  Chef::Log.info("CM - No THP updates to #{rc_local_path} required") if debug
end
Chef::Log.info("CM - THP setting check complete") if debug

#----------------------------------------------------------------------
# Find the name nodes. 
#----------------------------------------------------------------------
namenodes = []
search(:node, "roles:clouderamanager-namenode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - NAMENODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    namenodes << node_rec
  end
end
node[:clouderamanager][:cluster][:namenodes] = namenodes

#----------------------------------------------------------------------
# Find the data nodes. 
#----------------------------------------------------------------------
datanodes = []
search(:node, "roles:clouderamanager-datanode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    hdfs_mounts = n[:clouderamanager][:hdfs][:hdfs_mounts] 
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key, :hdfs_mounts => hdfs_mounts}
    Chef::Log.info("CM - DATANODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    datanodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:datanodes] = datanodes

#----------------------------------------------------------------------
# Find the edge nodes. 
#----------------------------------------------------------------------
edgenodes = []
search(:node, "roles:clouderamanager-edgenode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - EDGENODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    edgenodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:edgenodes] = edgenodes

#----------------------------------------------------------------------
# Find the CM server nodes. 
#----------------------------------------------------------------------
cmservernodes = []
search(:node, "roles:clouderamanager-server#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - CMSERVERNODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    cmservernodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:cmservernodes] = cmservernodes

#----------------------------------------------------------------------
# Find the HA filer nodes. 
#----------------------------------------------------------------------
hafilernodes = []
search(:node, "roles:clouderamanager-ha-filernode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - FILERNODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    hafilernodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:hafilernodes] = hafilernodes

#----------------------------------------------------------------------
# Find the HA journaling nodes. 
#----------------------------------------------------------------------
hajournalingnodes = []
search(:node, "roles:clouderamanager-ha-journalingnode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - JOURNALINGNODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    hajournalingnodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:hajournalingnodes] = hajournalingnodes

node.save 

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:node-setup") if debug
