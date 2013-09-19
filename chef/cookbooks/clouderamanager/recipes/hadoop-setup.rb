#
# Cookbook Name: clouderamanager
# Recipe: hadoop-setup.rb
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
Chef::Log.info("CM - BEGIN clouderamanager:hadoop-setup") if debug

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
# cleanup left over lock files if present.
#----------------------------------------------------------------------
lock_list=%w{
  /etc/passwd.lock
  /etc/shadow.lock
  /etc/group.lock
  /etc/gshadow.lock
}

lock_list.each do |lock_file|
  if File.exists?(lock_file)
    Chef::Log.info("CM - clearing lock #{lock_file}") if debug
    bash "unlock-#{lock_file}" do
      user "root"
      code <<-EOH
rm -f #{lock_file}
  EOH
    end
  end
end

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
if node[:clouderamanager][:cmapi][:deployment_type] == 'auto' and not node[:clouderamanager][:cluster][:auto_pkgs_installed]
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
    oozie-client
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
    solr
    solr-doc
    search
    solr-mapreduce
    flume-ng-solr
    hbase-solr
    hbase-solr-doc
    sqoop2-client
    sqoop2
    hcatalog
    webhcat
  }
  
  ext_packages.each do |pkg|
    package pkg do
      action :install
    end
  end
  
  # Disable extraneous init scripts. 
  # We will reply on CM to start the services. 
  init_disable=%w{
   oozie
   hadoop-httpfs
  }
  init_disable.each do |init_script|
    %x{chkconfig --del #{init_script}}
  end
  
  node[:clouderamanager][:cluster][:auto_pkgs_installed] = true
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
# Setup the SSH keys.
#######################################################################
keys = {}

#----------------------------------------------------------------------
# namenode keys. 
#----------------------------------------------------------------------
if node[:clouderamanager][:cluster][:namenodes]
  node[:clouderamanager][:cluster][:namenodes].each do |n|
    name = n[:name]
    key = n[:ssh_key] rescue nil
    keys[name] = key
  end
end

#----------------------------------------------------------------------
# datanode keys. 
#----------------------------------------------------------------------
if node[:clouderamanager][:cluster][:datanodes]
  node[:clouderamanager][:cluster][:datanodes].each do |n|
    name = n[:name]
    key = n[:ssh_key] rescue nil
    keys[name] = key
  end
end

#----------------------------------------------------------------------
# edgenode keys. 
#----------------------------------------------------------------------
if node[:clouderamanager][:cluster][:edgenodes]
  node[:clouderamanager][:cluster][:edgenodes].each do |n|
    name = n[:name]
    key = n[:ssh_key] rescue nil
    keys[name] = key
  end
end

#----------------------------------------------------------------------
# cmservernodes keys. 
#----------------------------------------------------------------------
if node[:clouderamanager][:cluster][:cmservernodes]
  node[:clouderamanager][:cluster][:cmservernodes].each do |n|
    name = n[:name]
    key = n[:ssh_key] rescue nil
    keys[name] = key
  end
end

#----------------------------------------------------------------------
# hafilernode keys. 
#----------------------------------------------------------------------
if node[:clouderamanager][:cluster][:hafilernodes]
  node[:clouderamanager][:cluster][:hafilernodes].each do |n|
    name = n[:name]
    key = n[:ssh_key] rescue nil
    keys[name] = key
  end
end

#----------------------------------------------------------------------
# hajournalingnode keys. 
#----------------------------------------------------------------------
if node[:clouderamanager][:cluster][:hajournalingnodes]
  node[:clouderamanager][:cluster][:hajournalingnodes].each do |n|
    name = n[:name]
    key = n[:ssh_key] rescue nil
    keys[name] = key
  end
end

#######################################################################
# Add hadoop nodes to SSH authorized key list. 
#######################################################################
keys.each do |k,v|
  unless v.nil? or v.empty?
    node[:crowbar][:ssh] = {} if node[:crowbar][:ssh].nil?
    node[:crowbar][:ssh][:access_keys] = {} if node[:crowbar][:ssh][:access_keys].nil?
    Chef::Log.info("CM - SSH key update [#{k}]") if debug
    node[:crowbar][:ssh][:access_keys][k] = v
  end
end

node.save 

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:hadoop-setup") if debug
