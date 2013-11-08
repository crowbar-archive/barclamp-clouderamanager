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
# If we are programmatically configuring the cluster via crowbar, we
# must pre-install the hadoop base packages. We also start up the
# cm-agent processes with a valid config (See cm-agent.rb). If CM sees
# the agents heartbeating, it assumes that the packages are installed
# and that's why we need to install them here in-line.
#######################################################################
if node[:clouderamanager][:cmapi][:deployment_type] == 'auto' and not node[:clouderamanager][:cluster][:auto_pkgs_installed]
  ext_packages=%w{
     bigtop-utils
     bigtop-jsvc
     bigtop-tomcat
     hadoop
     hadoop-hdfs
     hadoop-httpfs
     hadoop-mapreduce
     hadoop-yarn
     hadoop-client
     hadoop-0.20-mapreduce
     hadoop-hdfs-fuse
     zookeeper
     hbase
     hive
     oozie-client
     oozie
     pig
     hue-plugins
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
     sentry
     solr-mapreduce
     flume-ng-solr
     hue-search
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
  
  node[:clouderamanager][:cluster][:auto_pkgs_installed] = true
end

# We will rely on CM to configure startup for these services.
# The CM Host inspector will complain if these rc.d services
# are enabled by default. 
init_disable=%w{
   oozie
   hadoop-httpfs
  }
init_disable.each do |init_script|
    %x{chkconfig #{init_script} off}
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:hadoop-setup") if debug
