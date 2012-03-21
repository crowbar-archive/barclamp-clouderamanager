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
# Begin recipe
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:default") if debug

# Configuration filter for our crowbar environment
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

# Install the Oracle/SUN JAVA package (Hadoop requires the JDK).
package "jdk" do
  action :install
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

# Find the master name nodes (there should only be one). 
keys = {}
master_name_nodes = []
master_name_node_objects = []
search(:node, "roles:clouderamanager-masternamenode#{env_filter}") do |nmas|
  if !nmas[:fqdn].nil? && !nmas[:fqdn].empty?
    Chef::Log.info("CM - MASTER [#{nmas[:fqdn]}") if debug
    master_name_nodes << nmas[:fqdn]
    master_name_node_objects << nmas
    keys[nmas.name] = nmas[:crowbar][:ssh][:root_pub_key] rescue nil
  end
end
node[:clouderamanager][:cluster][:master_name_nodes] = master_name_nodes

# Check for errors
if master_name_nodes.length == 0
  Chef::Log.info("CM - WARNING - Cannot find Hadoop master name node")
elsif master_name_nodes.length > 1
  Chef::Log.info("CM - WARNING - More than one master name node found")
end

# Find the secondary name nodes (there should only be one). 
secondary_name_nodes = []
secondary_name_node_objects = []
search(:node, "roles:clouderamanager-secondarynamenode#{env_filter}") do |nsec|
  if !nsec[:fqdn].nil? && !nsec[:fqdn].empty?
    Chef::Log.info("CM - SECONDARY [#{nsec[:fqdn]}") if debug
    secondary_name_nodes << nsec[:fqdn]
    secondary_name_node_objects << nsec
    keys[nsec.name] = nsec[:crowbar][:ssh][:root_pub_key] rescue nil
  end
end
node[:clouderamanager][:cluster][:secondary_name_nodes] = secondary_name_nodes

# Check for errors
if secondary_name_nodes.length == 0
  Chef::Log.info("CM - WARNING - Cannot find Hadoop secondary name node")
elsif secondary_name_nodes.length > 1
  Chef::Log.info("CM - WARNING - More than one secondary name node found}")
end

# Find the edge nodes. 
edge_nodes = []
search(:node, "roles:clouderamanager-edgenode#{env_filter}") do |nedge|
  if !nedge[:fqdn].nil? && !nedge[:fqdn].empty?
    Chef::Log.info("CM - EDGE [#{nedge[:fqdn]}") if debug
    edge_nodes << nedge[:fqdn] 
    keys[nedge.name] = nedge[:crowbar][:ssh][:root_pub_key] rescue nil
  end
end
node[:clouderamanager][:cluster][:edge_nodes] = edge_nodes

# Find the slave nodes. 
Chef::Log.info("CM - env filter [#{env_filter}]") if debug
slave_nodes = []
search(:node, "roles:clouderamanager-slavenode#{env_filter}") do |nslave|
  if !nslave[:fqdn].nil? && !nslave[:fqdn].empty?
    Chef::Log.info("CM - SLAVE [#{nslave[:fqdn]}") if debug
    slave_nodes << nslave[:fqdn] 
    keys[nslave.name] = nslave[:crowbar][:ssh][:root_pub_key] rescue nil
  end
end
node[:clouderamanager][:cluster][:slave_nodes] = slave_nodes

# Check for errors
if slave_nodes.length == 0
  Chef::Log.info("CM - WARNING - Cannot find any Hadoop data nodes")
end

if debug
  Chef::Log.info("CM - MASTER_NAME_NODES    {" + node[:clouderamanager][:cluster][:master_name_nodes].join(",") + "}")
  Chef::Log.info("CM - SECONDARY_NAME_NODES {" + node[:clouderamanager][:cluster][:secondary_name_nodes].join(",") + "}")
  Chef::Log.info("CM - EDGE_NODES           {" + node[:clouderamanager][:cluster][:edge_nodes].join(",") + "}")
  Chef::Log.info("CM - SLAVE_NODES          {" + node[:clouderamanager][:cluster][:slave_nodes].join(",") + "}")
end

# Add hadoop nodes to ssh authorized key file 
keys.each do |k,v|
  unless v.nil?
    node[:crowbar][:ssh] = {} if node[:crowbar][:ssh].nil?
    node[:crowbar][:ssh][:access_keys] = {} if node[:crowbar][:ssh][:access_keys].nil?
    node[:crowbar][:ssh][:access_keys][k] = v
  end
end

node.save 

#######################################################################
# End of recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:default") if debug
