#
# Cookbook Name: clouderamanager
# Recipe: cm-mgmtservices.rb
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
#######################################################################
# Role definition for Cloudera Management Services parameters
# (service_monitor, activity_monitor and resource_manager).
# Requires installation of MYSQL and MYSQL JDBC connector.   
#######################################################################

include_recipe 'clouderamanager::cm-common'

#######################################################################
# Begin recipe
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:mgmtservices") if debug

# Configuration filter for our crowbar environment.
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

# Install mysql for cloudera managements services.
include_recipe 'clouderamanager::mysql'

directory "/usr/share/cmf/config" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# Create the management service databases.
if !File.exists?("/usr/share/cmf/config/scm-monitoring-databases")
  Chef::Log.info("CM - Creating activity monitor databases") if debug
  bash "scm-monitoring-databases" do
    user "root"
    code <<-EOH
mysqladmin -u root password 'crowbar'
mysqladmin -u root -h $(hostname) password 'crowbar'
mysql --user=root --password=crowbar -e "create database activity_monitor;"
mysql --user=root --password=crowbar -e "create database service_monitor;"
mysql --user=root --password=crowbar -e "create database resource_manager;"
touch /usr/share/cmf/config/scm-monitoring-databases
exit 0  
  EOH
  end
else
  Chef::Log.info("CM - Activity monitor databases already created") if debug
end

# Grant permissions for local host.
if !File.exists?("/usr/share/cmf/config/scm-config-localhost")
  Chef::Log.info("CM - Configuring management services local hosts") if debug
  bash "scm-config-localhost" do
    user "root"
    code <<-EOH
mysql --user=root --password=crowbar -e "grant all on activity_monitor.* TO 'scm'@'localhost' identified by 'crowbar';"
mysql --user=root --password=crowbar -e "grant all on service_monitor.* TO 'scm'@'localhost' identified by 'crowbar';"
mysql --user=root --password=crowbar -e "grant all on resource_manager.* TO 'scm'@'localhost' identified by 'crowbar';"
touch /usr/share/cmf/config/scm-config-localhost
exit 0  
  EOH
  end
else
  Chef::Log.info("CM - Management services local hosts already configured") if debug
end

# Grant permissions for specific role host.
mgmt_service_fqdns = node[:clouderamanager][:cluster][:mgmt_service_nodes] 
Chef::Log.info("CM - Management service nodes {" + mgmt_service_fqdns.join(",") + "}") if debug 

fqdn = ""
if mgmt_service_fqdns and mgmt_service_fqdns.length > 0
  fqdn = mgmt_service_fqdns[0]
end
node[:clouderamanager][:database][:sm_db_host] = fqdn
node[:clouderamanager][:database][:am_db_host]  = fqdn
node[:clouderamanager][:database][:rm_db_host] = fqdn
node.save

if !File.exists?("/usr/share/cmf/config/scm-config-hosts")
  Chef::Log.info("CM - Configuring management services hosts") if debug
  if !fqdn.empty? 
    Chef::Log.info("CM - Management service node [#{fqdn}]")
    bash "scm-config-hosts" do
      user "root"
      code <<-EOH
mysql --user=root --password=crowbar -e "grant all on activity_monitor.* TO 'scm'@'#{fqdn}' identified by 'crowbar';"
mysql --user=root --password=crowbar -e "grant all on service_monitor.* TO 'scm'@'#{fqdn}' identified by 'crowbar';"
mysql --user=root --password=crowbar -e "grant all on resource_manager.* TO 'scm'@'#{fqdn}' identified by 'crowbar';"
touch /usr/share/cmf/config/scm-config-hosts
exit 0  
  EOH
    end
  else    
    Chef::Log.info("CM - WARNING - management service nodes not found}")
  end
else
  Chef::Log.info("CM - Management services hosts already configured") if debug
end

#######################################################################
# End of recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:mgmtservices") if debug
