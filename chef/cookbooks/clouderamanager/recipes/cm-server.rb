#
# Cookbook Name: clouderamanager
# Recipe: cm-server.rb
#
# Copyright (c) 2011 Dell Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License")
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
Chef::Log.info("CM - BEGIN clouderamanager:cm-server") if debug

# Configuration filter for the crowbar environment.
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

# Install the Cloudera Manager server packages.
server_packages=%w{
    cloudera-manager-daemons
    cloudera-manager-server-db
    cloudera-manager-server
  }

server_packages.each do |pkg|
  package pkg do
    action :install
  end
end

#######################################################################
# Setup the postgresql or mysql server for CM management.
#######################################################################
db_type = node[:clouderamanager][:server][:db_type]
if db_type == 'postgresql'
  include_recipe 'clouderamanager::postgresql'
elsif db_type == 'mysql'
  include_recipe 'clouderamanager::mysql'
else
  Chef::Log.error("CM - Invalid server db_type #{db_type}")
end

#######################################################################
# Cloudera Manager needs to have this directory present. Without it,
# the slave node installation will fail. This is an empty directory and the
# RPM package installer does not seem to create it.
#######################################################################
directory "/usr/share/cmf/packages" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

#######################################################################
# Define the Cloudera Manager server service.
# cloudera-scm-server {start|stop|restart|status}
#######################################################################
service "cloudera-scm-server" do
  supports :start => true, :stop => true, :restart => true, :status => true 
  action :enable 
end

#######################################################################
# Define the Cloudera Manager database service.
# cloudera-scm-server-db {start|stop|restart|status|initdb}
#######################################################################
service "cloudera-scm-server-db" do
  supports :start => true, :stop => true, :restart => true, :status => true 
  action :enable 
end

#######################################################################
# Setup the CM server.
# This will only execute if the db is uninitialized, otherwise it returns 1. 
# /var/lib/cloudera-scm-server-db/data is non-empty; perhaps the database
# was already initialized?
#######################################################################
bash "cloudera-scm-server-db" do
  code <<-EOH
/etc/init.d/cloudera-scm-server-db initdb
EOH
  returns [0, 1] 
end

# Start the Cloudera Manager database service.
service "cloudera-scm-server-db" do
  action :start 
end

# Start the Cloudera Manager server service.
service "cloudera-scm-server" do
  action :start 
end

#######################################################################
# Add the cloudera manager link to the crowbar UI.
#######################################################################
server_ip = nil
cmservernodes = node[:hadoop_infrastructure][:cluster][:cmservernodes]
if cmservernodes and cmservernodes.length > 0 
  rec = cmservernodes[0]
  server_ip = rec[:ipaddr]
end
node[:crowbar] = {} if node[:crowbar].nil? 
node[:crowbar][:links] = {} if node[:crowbar][:links].nil?
if server_ip and !server_ip.empty? 
  url = "http://#{server_ip}:7180/cmf/login" 
  Chef::Log.info("CM - Cloudera management services URL [#{url}]") if debug 
  node[:crowbar][:links]["Cloudera Manager"] = url 
else
  node[:crowbar][:links].delete("Cloudera Manager")
end

#######################################################################
# The CM API automatic configuration feature is current disabled by
# default. You must enable it in crowbar before queuing the proposal.
# If this feature is disabled, you must configure the cluster manually
# using the CM user interface.
# Note : This runs in the chef deferred processing phase (enclosed in
# a ruby_block) because it requires the cm-server to be installed and
# running at the point of execution.
#######################################################################
always_run = false
if always_run or (node[:clouderamanager][:cmapi][:deployment_type] == 'auto' and not node[:clouderamanager][:cluster][:cm_api_configured])
  ruby_block "cm-api-deferred-execution" do
    block do
      libbase = File.join(File.dirname(__FILE__), '../libraries' )
      require "#{libbase}/api_client.rb"
      
      #--------------------------------------------------------------------
      # CM API configuration parameters.
      #--------------------------------------------------------------------
      server_port = node[:clouderamanager][:cmapi][:server_port]
      username = node[:clouderamanager][:cmapi][:username]
      password = node[:clouderamanager][:cmapi][:password]
      use_tls = node[:clouderamanager][:cmapi][:use_tls]
      version = node[:clouderamanager][:cmapi][:version]
      
      #--------------------------------------------------------------------
      # Cluster configuration parameters.
      #--------------------------------------------------------------------
      license_key = node[:clouderamanager][:cluster][:license_key] 
      cluster_name = node[:clouderamanager][:cluster][:cluster_name] 
      cdh_version = node[:clouderamanager][:cluster][:cdh_version] 
      rack_id = node[:clouderamanager][:cluster][:rack_id] 
      
      #--------------------------------------------------------------------
      # CB node information (each item is an array of records).
      #--------------------------------------------------------------------
      namenodes = node[:hadoop_infrastructure][:cluster][:namenodes] 
      datanodes = node[:hadoop_infrastructure][:cluster][:datanodes]
      edgenodes = node[:hadoop_infrastructure][:cluster][:edgenodes] 
      cmservernodes = node[:hadoop_infrastructure][:cluster][:cmservernodes]
      hafilernodes = node[:hadoop_infrastructure][:cluster][:hafilernodes] 
      hajournalingnodes = node[:hadoop_infrastructure][:cluster][:hajournalingnodes] 
      server_host = ''
      if cmservernodes and cmservernodes.length > 0 
        server_host = cmservernodes[0][:ipaddr]
      end
      
      #######################################################################
      # API logger class for debug/error logging.
      #######################################################################
      class ApiLogger
        def info(str)
          Chef::Log.info(str)
        end
        
        def error(str)
          Chef::Log.error(str)
        end
      end
      logger = ApiLogger.new
      
      #####################################################################
      # Deploy the CM cluster.
      #####################################################################
      deployment_ok = false
      api = CmApiClient.new(logger, server_host, server_port, username, password, use_tls, version, debug)
      
      if api
        deployment_ok = api.deploy_cluster(license_key, cluster_name, cdh_version, rack_id, namenodes,
                                           datanodes, edgenodes, cmservernodes, hafilernodes, hajournalingnodes)
      else
        logger.error("CM - ERROR: Cannot create CM API client")
      end
      
      if deployment_ok
        logger.info("CM - Hadoop cluster deployment successful") if debug
        node[:clouderamanager][:cluster][:cm_api_configured] = true
        node.save 
      else
        logger.error("CM - ERROR: Hadoop cluster deployment failed, will try again later")
        node[:clouderamanager][:cluster][:cm_api_configured] = false
        node.save 
      end
    end
  end
else
  Chef::Log.info("CM - Automatic CM API feature is disabled") if debug
end

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:cm-server") if debug
