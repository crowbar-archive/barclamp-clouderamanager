#
# Cookbook Name: clouderamanager
# Recipe: default.rb
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
# Begin recipe transactions
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CLOUDERAMANAGER : BEGIN clouderamanager:default") if debug

# Local variables
process_owner = node[:clouderamanager][:cluster][:process_file_system_owner]
mapred_owner = node[:clouderamanager][:cluster][:mapred_file_system_owner]
hdfs_owner = node[:clouderamanager][:cluster][:hdfs_file_system_owner]
hadoop_group = node[:clouderamanager][:cluster][:global_file_system_group]

# Configuration filter for our crowbar environment
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

# Install the Oracle/SUN JAVA package (Hadoop requires the JDK).
package "jdk" do
  action :install
end

# Install the hadoop base package.
package "hadoop-0.20" do
  action :install
end

# Logic to validate the cluster configuration so we don't attempt
# to start hadoop processes while the cluster is in an invalid state
# (i.e. deployment state transition).
node[:clouderamanager][:cluster][:valid_config] = true

keys = {}
# Find the master name nodes (there should only be one). 
master_name_nodes = Array.new
master_name_node_objects = Array.new
search(:node, "roles:clouderamanager-masternamenode") do |nmas|
  # search(:node, "roles:clouderamanager-masternamenode#{env_filter}") do |nmas|
  if !nmas[:fqdn].nil? && !nmas[:fqdn].empty?
    Chef::Log.info("CLOUDERAMANAGER : MASTER [#{nmas[:fqdn]}") if debug
    master_name_nodes << nmas[:fqdn]
    master_name_node_objects << nmas
    keys[nmas.name] = nmas["crowbar"]["ssh"]["root_pub_key"] rescue nil
  end
end
node[:clouderamanager][:cluster][:master_name_nodes] = master_name_nodes

# Check for errors
if master_name_nodes.length == 0
  Chef::Log.info("CLOUDERAMANAGER : WARNING - Cannot find Hadoop master name node")
  node[:clouderamanager][:cluster][:valid_config] = false
elsif master_name_nodes.length > 1
  Chef::Log.info("CLOUDERAMANAGER : WARNING - More than one master name node found")
  node[:clouderamanager][:cluster][:valid_config] = false
end

# Find the secondary name nodes (there should only be one). 
secondary_name_nodes = Array.new
secondary_name_node_objects = Array.new
search(:node, "roles:clouderamanager-secondarynamenode") do |nsec|
  # search(:node, "roles:clouderamanager-secondarynamenode#{env_filter}") do |nsec|
  if !nsec[:fqdn].nil? && !nsec[:fqdn].empty?
    Chef::Log.info("CLOUDERAMANAGER : SECONDARY [#{nsec[:fqdn]}") if debug
    secondary_name_nodes << nsec[:fqdn]
    secondary_name_node_objects << nsec
    keys[nsec.name] = nsec["crowbar"]["ssh"]["root_pub_key"] rescue nil
  end
end
node[:clouderamanager][:cluster][:secondary_name_nodes] = secondary_name_nodes

# Check for errors
if secondary_name_nodes.length == 0
  Chef::Log.info("CLOUDERAMANAGER : WARNING - Cannot find Hadoop secondary name node")
  node[:clouderamanager][:cluster][:valid_config] = false
elsif secondary_name_nodes.length > 1
  Chef::Log.info("CLOUDERAMANAGER : WARNING - More than one secondary name node found}")
  node[:clouderamanager][:cluster][:valid_config] = false
end

# Find the edge nodes. 
edge_nodes = Array.new
search(:node, "roles:clouderamanager-edgenode") do |nedge|
  # search(:node, "roles:clouderamanager-edgenode#{env_filter}") do |nedge|
  if !nedge[:fqdn].nil? && !nedge[:fqdn].empty?
    Chef::Log.info("CLOUDERAMANAGER : EDGE [#{nedge[:fqdn]}") if debug
    edge_nodes << nedge[:fqdn] 
    keys[nedge.name] = nedge["crowbar"]["ssh"]["root_pub_key"] rescue nil
  end
end
node[:clouderamanager][:cluster][:edge_nodes] = edge_nodes

# Find the slave nodes. 
Chef::Log.info("CLOUDERAMANAGER : env filter [#{env_filter}]") if debug
slave_nodes = Array.new
search(:node, "roles:clouderamanager-slavenode") do |nslave|
  # search(:node, "roles:clouderamanager-slavenode#{env_filter}") do |nslave|
  if !nslave[:fqdn].nil? && !nslave[:fqdn].empty?
    Chef::Log.info("CLOUDERAMANAGER : SLAVE [#{nslave[:fqdn]}") if debug
    slave_nodes << nslave[:fqdn] 
    keys[nslave.name] = nslave["crowbar"]["ssh"]["root_pub_key"] rescue nil
  end
end
node[:clouderamanager][:cluster][:slave_nodes] = slave_nodes

# Check for errors
if slave_nodes.length == 0
  Chef::Log.info("CLOUDERAMANAGER : WARNING - Cannot find any Hadoop data nodes")
end

if debug
  Chef::Log.info("CLOUDERAMANAGER : MASTER_NAME_NODES    {" + node[:clouderamanager][:cluster][:master_name_nodes] .join(",") + "}")
  Chef::Log.info("CLOUDERAMANAGER : SECONDARY_NAME_NODES {" + node[:clouderamanager][:cluster][:secondary_name_nodes].join(",") + "}")
  Chef::Log.info("CLOUDERAMANAGER : EDGE_NODES           {" + node[:clouderamanager][:cluster][:edge_nodes].join(",") + "}")
  Chef::Log.info("CLOUDERAMANAGER : SLAVE_NODES          {" + node[:clouderamanager][:cluster][:slave_nodes].join(",") + "}")
end

# Set the authoritative name node URI (i.e. hdfs://admin.example.com:8020).
node[:clouderamanager][:core][:fs_default_name] = "file:///"
if master_name_nodes.length > 0
  fqdn = master_name_nodes[0]
  port = node[:clouderamanager][:hdfs][:dfs_access_port]
  fs_default_name = "hdfs://#{fqdn}:#{port}"
  Chef::Log.info("CLOUDERAMANAGER : fs_default_name #{fs_default_name}") if debug
  node[:clouderamanager][:core][:fs_default_name] = fs_default_name
end

# Map/Reduce setup.
# mapred.job.tracker needs to be set to the IP of the Master Node running job tracker.
# mapred.job.tracker.http.address needs to also be set to the above IP.
master_node_ip = "0.0.0.0"
if !master_name_node_objects.nil? && master_name_node_objects.length > 0
  master_node_ip = BarclampLibrary::Barclamp::Inventory.get_network_by_type(master_name_node_objects[0],"admin").address
end
if master_node_ip.nil? || master_node_ip.empty? || master_node_ip == "0.0.0.0"  
  Chef::Log.info("CLOUDERAMANAGER : WARNING - Invalid master name node IP #{master_node_ip}")
  node[:clouderamanager][:cluster][:valid_config] = false
else
  Chef::Log.info("CLOUDERAMANAGER : MASTER NAME NODE IP #{master_node_ip}") if debug
end

# The host and port that the MapReduce job tracker runs at. If "local",
# then jobs are run in-process as a single map and reduce task.
node[:clouderamanager][:mapred][:mapred_job_tracker] = "#{master_node_ip}:50030"

# The job tracker http server address and port the server will listen on.
# If the port is 0 then the server will start on a free port "0.0.0.0:50030".
node[:clouderamanager][:mapred][:mapred_job_tracker_http_address] = "#{master_node_ip}:50031"

secondary_node_ip = "0.0.0.0"
if !secondary_name_node_objects.nil? && secondary_name_node_objects.length > 0
  secondary_node_ip = BarclampLibrary::Barclamp::Inventory.get_network_by_type(secondary_name_node_objects[0],"admin").address
end
if secondary_node_ip.nil? || secondary_node_ip.empty? || secondary_node_ip == "0.0.0.0"  
  Chef::Log.info("CLOUDERAMANAGER : WARNING - Invalid secondary name node IP #{secondary_node_ip}")
  node[:clouderamanager][:cluster][:valid_config] = false
else
  Chef::Log.info("CLOUDERAMANAGER : SECONDARY NAME NODE IP #{secondary_node_ip}") if debug
end

# The secondary namenode http server address and port. If the port is 0
# then the server will start on a free port.
node[:clouderamanager][:hdfs][:dfs_secondary_http_address] = "#{secondary_node_ip}:50090"

if debug
  if node[:clouderamanager][:cluster][:valid_config]
    Chef::Log.info("CLOUDERAMANAGER : CONFIGURATION VALID [true]")
  else
    Chef::Log.info("CLOUDERAMANAGER : CONFIGURATION VALID [false]")
  end
end

# "Add hadoop nodes to authorized key file" 
keys.each do |k,v|
  unless v.nil?
    node["crowbar"]["ssh"] = {} if node["crowbar"]["ssh"].nil?
    node["crowbar"]["ssh"]["access_keys"] = {} if node["crowbar"]["ssh"]["access_keys"].nil?
    node["crowbar"]["ssh"]["access_keys"][k] = v
  end
end

node.save 

# Create hadoop_log_dir and set ownership/permissions (/var/log/hadoop). 
hadoop_log_dir = node[:clouderamanager][:env][:hadoop_log_dir]
directory hadoop_log_dir do
  owner process_owner
  group hadoop_group
  mode "0775"
  action :create
end

# Create hadoop_tmp_dir and ownership/permissions (/tmp/hadoop-crowbar).
hadoop_tmp_dir = node[:clouderamanager][:core][:hadoop_tmp_dir]
directory hadoop_tmp_dir do
  owner process_owner
  group hadoop_group
  mode "0775"
  action :create
end

# Create fs_s3_buffer_dir and ownership/permissions (/tmp/hadoop-crowbar/s3).
fs_s3_buffer_dir = node[:clouderamanager][:core][:fs_s3_buffer_dir]
directory fs_s3_buffer_dir do
  owner hdfs_owner
  group hadoop_group
  mode "0775"
  recursive true
  action :create
end

# Create mapred_system_dir and set ownership/permissions (/mapred/system).
# Directory recursive does not set the parent directory owner, group
# and permissions correctly.
mapred_system_dir = node[:clouderamanager][:mapred][:mapred_system_dir]
mapred_system_dir.each do |path|
  dir = ""
  path.split('/').each do |d|
    next if (d.nil? || d.empty?)
    dir = "#{dir}/#{d}"
    directory dir do
      owner mapred_owner
      group hadoop_group
      mode "0775"
      action :create
    end
  end
end

# Create mapred_local_dir and set ownership/permissions (/var/lib/hadoop-0.20/cache/mapred/mapred/local).
mapred_local_dir = node[:clouderamanager][:mapred][:mapred_local_dir]
mapred_local_dir.each do |path|
  directory path do
    owner mapred_owner
    group hadoop_group
    mode "0755"
    recursive true
    action :create
  end
end

# Create dfs_name_dir and set ownership/permissions (/mnt/hdfs/hdfs01/meta1).
dfs_name_dir = node[:clouderamanager][:hdfs][:dfs_name_dir]
dfs_name_dir.each do |path|
  directory path do
    owner hdfs_owner
    group hadoop_group
    mode "0755"
    recursive true
    action :create
  end
end

#######################################################################
# Process common hadoop related configuration templates.
#######################################################################

# Configure the master nodes.  
template "/etc/hadoop/conf/masters" do
  owner process_owner
  group hadoop_group
  mode "0644"
  source "masters.erb"
end

# Configure the slave nodes.  
template "/etc/hadoop/conf/slaves" do
  owner process_owner
  group hadoop_group
  mode "0644"
  source "slaves.erb"
end

# Configure the hadoop core component.
template "/etc/hadoop/conf/core-site.xml" do
  owner process_owner
  group hadoop_group
  mode "0644"
  source "core-site.xml.erb"
end

# Configure the HDFS component.
template "/etc/hadoop/conf/hdfs-site.xml" do
  owner process_owner
  group hadoop_group
  mode "0644"
  source "hdfs-site.xml.erb"
end

# Configure the MAP/Reduce component.
template "/etc/hadoop/conf/mapred-site.xml" do
  owner process_owner
  group hadoop_group
  mode "0644"
  source "mapred-site.xml.erb"
end

# Configure the Hadoop ENV component.
template "/etc/hadoop/conf/hadoop-env.sh" do
  owner process_owner
  group hadoop_group
  mode "0755"
  source "hadoop-env.sh.erb"
end

# Configure hadoop-metrics.properties.
template "/etc/hadoop/conf/hadoop-metrics.properties" do
  owner process_owner
  group hadoop_group
  mode "0644"
  source "hadoop-metrics.properties.erb"
end

# Configure /etc/security/limits.conf.  
# mapred      -    nofile     32768
# hdfs        -    nofile     32768
# hbase       -    nofile     32768
template "/etc/security/limits.conf" do
  owner "root"
  group "root"
  mode "0644"
  source "limits.conf.erb"
end

#######################################################################
# End of recipe transactions
#######################################################################
Chef::Log.info("CLOUDERAMANAGER : END clouderamanager:default") if debug
