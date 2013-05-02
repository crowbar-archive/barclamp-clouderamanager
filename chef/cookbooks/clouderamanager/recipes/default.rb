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

# Configuration filter for the crowbar environment
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

#######################################################################
# Install JAVA.
#######################################################################
base_packages=%w{
  jdk
}

base_packages.each do |pkg|
  package pkg do
    action :install
  end
end

#######################################################################
# Setup the hadoop/hdfs/mr user and groups.
#######################################################################

#----------------------------------------------------------------------
# hdfs:x:600:
#----------------------------------------------------------------------
group "hdfs" do
  gid 600
end

#----------------------------------------------------------------------
# hdfs:x:600:600:Hadoop HDFS:/var/lib/hadoop-hdfs:/bin/bash
#----------------------------------------------------------------------
user "hdfs" do
  comment "Hadoop HDFS"
  uid 600
  gid "hdfs"
  home "/var/lib/hadoop-hdfs"
  shell "/bin/bash"
  system true
end

#----------------------------------------------------------------------
# mapred:x:601
#----------------------------------------------------------------------
group "mapred" do
  gid 601
end

#----------------------------------------------------------------------
# mapred:x:601:601:Hadoop MapReduce:/var/lib/hadoop-mapreduce:/bin/bash
#----------------------------------------------------------------------
user "mapred" do
  comment "Hadoop MapReduce"
  uid 601
  gid "mapred"
  home "/var/lib/hadoop-mapreduce"
  shell "/bin/bash"
  system true
end

#----------------------------------------------------------------------
# hadoop:x:602:hdfs
#----------------------------------------------------------------------
group "hadoop" do
  gid 602
  members ['hdfs', 'mapred']
end

#######################################################################
# If we are programmatically configuring the cluster via crowbar, we
# must pre-install the hadoop base packages. We also start up the
# cm-agent processes with a valid config (See cm-agent.rb). If CM sees
# the agents heartbeating, it assumes that the packages are installed
# and that's why we need to install them here in-line.
#######################################################################
if node[:clouderamanager][:cmapi][:deployment_type] == 'auto'
  ext_packages=%w{
    cloudera-manager-agent
    cloudera-manager-daemons
    bigtop-jsvc
    bigtop-tomcat
    hadoop-hdfs
    hadoop-httpfs
    hadoop-mapreduce
    hadoop-client
    hadoop-hdfs-fuse
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
    sqoop
    flume-ng
    impala
    impala-shell
  }
  
  ext_packages.each do |pkg|
    package pkg do
      action :install
    end
  end
end

#######################################################################
# Configure /etc/security/limits.conf.  
# mapred      -    nofile     32768
# hdfs        -    nofile     32768
# hbase       -    nofile     32768
#######################################################################
template "/etc/security/limits.conf" do
  owner "root"
  group "root"
  mode "0644"
  source "limits.conf.erb"
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
# Setup the SSH keys.
#######################################################################
keys = {}

#----------------------------------------------------------------------
# Find the namenodes. 
#----------------------------------------------------------------------
namenodes = []
search(:node, "roles:clouderamanager-namenode#{env_filter}") do |n|
  if n[:fqdn] && !n[:fqdn].empty?
    Chef::Log.info("CM - NAMENODE [#{n[:fqdn]}]") if debug
    namenodes << n[:fqdn]
    keys[n.name] = n[:crowbar][:ssh][:root_pub_key] rescue nil
  end
end
node[:clouderamanager][:cluster][:namenodes] = namenodes

if namenodes.length == 0
  Chef::Log.info("CM - WARNING - Cannot find Hadoop master name node")
end

#----------------------------------------------------------------------
# Find the edgenodes. 
#----------------------------------------------------------------------
edgenodes = []
search(:node, "roles:clouderamanager-edgenode#{env_filter}") do |n|
  if n[:fqdn] && !n[:fqdn].empty?
    Chef::Log.info("CM - EDGENODE [#{n[:fqdn]}]") if debug
    edgenodes << n[:fqdn] 
    keys[n.name] = n[:crowbar][:ssh][:root_pub_key] rescue nil
  end
end
node[:clouderamanager][:cluster][:edgenodes] = edgenodes

#----------------------------------------------------------------------
# Find the slave nodes. 
#----------------------------------------------------------------------
datanodes = []
search(:node, "roles:clouderamanager-datanode#{env_filter}") do |n|
  if n[:fqdn] && !n[:fqdn].empty?
    Chef::Log.info("CM - DATANODE [#{n[:fqdn]}]") if debug
    datanodes << n[:fqdn] 
    keys[n.name] = n[:crowbar][:ssh][:root_pub_key] rescue nil
  end
end
node[:clouderamanager][:cluster][:datanodes] = datanodes

if datanodes.length == 0
  Chef::Log.info("CM - WARNING - Cannot find any Hadoop data nodes")
end

#----------------------------------------------------------------------
# Find the HA filer nodes. 
#----------------------------------------------------------------------
hafilernodes = []
search(:node, "roles:clouderamanager-ha-filernode#{env_filter}") do |n|
  if n[:fqdn] && !n[:fqdn].empty?
    Chef::Log.info("CM - FILERNODE [#{n[:fqdn]}]") if debug
    hafilernodes << n[:fqdn] 
    keys[n.name] = n[:crowbar][:ssh][:root_pub_key] rescue nil
  end
end
node[:clouderamanager][:cluster][:hafilernodes] = hafilernodes

#----------------------------------------------------------------------
# Find the HA journaling nodes. 
#----------------------------------------------------------------------
hajournalingnodes = []
search(:node, "roles:clouderamanager-ha-journalingnode#{env_filter}") do |n|
  if n[:fqdn] && !n[:fqdn].empty?
    Chef::Log.info("CM - JOURNALINGNODE [#{n[:fqdn]}]") if debug
    hajournalingnodes << n[:fqdn] 
    keys[n.name] = n[:crowbar][:ssh][:root_pub_key] rescue nil
  end
end
node[:clouderamanager][:cluster][:hajournalingnodes] = hajournalingnodes

if debug
  Chef::Log.info("CM - namenodes [" + node[:clouderamanager][:cluster][:namenodes].join(",") + "]")
  Chef::Log.info("CM - edgenodes [" + node[:clouderamanager][:cluster][:edgenodes].join(",") + "]")
  Chef::Log.info("CM - datanodes [" + node[:clouderamanager][:cluster][:datanodes].join(",") + "]")
  Chef::Log.info("CM - hafilernodes [" + node[:clouderamanager][:cluster][:hafilernodes].join(",") + "]")
  Chef::Log.info("CM - hajournalingnodes [" + node[:clouderamanager][:cluster][:hajournalingnodes].join(",") + "]")
end

#######################################################################
# Add hadoop nodes to SSH authorized key list. 
#######################################################################
keys.each do |k,v|
  unless v.nil?
    node[:crowbar][:ssh] = {} if node[:crowbar][:ssh].nil?
    node[:crowbar][:ssh][:access_keys] = {} if node[:crowbar][:ssh][:access_keys].nil?
    node[:crowbar][:ssh][:access_keys][k] = v
  end
end

node.save 

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:default") if debug
