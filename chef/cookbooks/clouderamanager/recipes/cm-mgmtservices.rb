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
# Recipe definition for Cloudera Management Services
# (service_monitor, activity_monitor and resource_manager).
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

# CM db config parameters from crowbar config.
mysql_admin_user = node[:clouderamanager][:database][:mysql_admin_user]
mysql_admin_pass = node[:clouderamanager][:database][:mysql_admin_pass]

sm_db_name = node[:clouderamanager][:database][:sm_db_name] 
sm_db_user = node[:clouderamanager][:database][:sm_db_user] 
sm_db_pass = node[:clouderamanager][:database][:sm_db_pass] 

am_db_name = node[:clouderamanager][:database][:am_db_name] 
am_db_user = node[:clouderamanager][:database][:am_db_user]
am_db_pass = node[:clouderamanager][:database][:am_db_pass]

rm_db_name = node[:clouderamanager][:database][:rm_db_name]
rm_db_user = node[:clouderamanager][:database][:rm_db_user]
rm_db_pass = node[:clouderamanager][:database][:rm_db_pass]

directory "/usr/share/cmf/config" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# Create the management service databases.
if !File.exists?("/usr/share/cmf/config/scm-config-database")
  Chef::Log.info("CM - Creating activity monitor databases") if debug
  bash "scm-config-database" do
    user "root"
    code <<-EOH
mysqladmin -u #{mysql_admin_user} password '#{mysql_admin_pass}'
mysqladmin -u #{mysql_admin_user} -h $(hostname) password '#{mysql_admin_pass}'
mysql --user=#{mysql_admin_user} --password=#{mysql_admin_pass} -e "create database #{sm_db_name};"
mysql --user=#{mysql_admin_user} --password=#{mysql_admin_pass} -e "create database #{am_db_name};"
mysql --user=#{mysql_admin_user} --password=#{mysql_admin_pass} -e "create database #{rm_db_name};"
touch /usr/share/cmf/config/scm-config-database
exit 0  
  EOH
  end
else
  Chef::Log.info("CM - Activity monitor databases already created") if debug
end

# Grant permissions for specific role hosts.
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
mysql --user=#{mysql_admin_user} --password=#{mysql_admin_pass} -e "grant all on #{sm_db_name}.* TO '#{sm_db_user}'@'#{fqdn}' identified by '#{mysql_admin_pass}';"
mysql --user=#{mysql_admin_user} --password=#{mysql_admin_pass} -e "grant all on #{am_db_name}.* TO '#{am_db_user}'@'#{fqdn}' identified by '#{mysql_admin_pass}';"
mysql --user=#{mysql_admin_user} --password=#{mysql_admin_pass} -e "grant all on #{rm_db_name}.* TO '#{rm_db_user}'@'#{fqdn}' identified by '#{mysql_admin_pass}';"
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
