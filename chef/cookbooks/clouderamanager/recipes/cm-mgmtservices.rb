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
# Role definition for Cloudera Management Services (Event Server,
# Activity Monitor, Alert Publisher, Service Monitor and Resource Manager).
# Requires installation of MYSQL and MYSQL JDBC connector.   
#######################################################################

include_recipe 'clouderamanager::cm-common'

#######################################################################
# Begin recipe
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:mgmtservices") if debug

# Install the Cloudera Manager mysql database component.
include_recipe 'clouderamanager::mysql'

# Initialize the mysql database.
if !File.exists?("/usr/share/cmf/schema/scm_sql_setup_complete")
  Chef::Log.info("CM - Configuring activity monitor services") if debug
  # Setup the mysql configuration.
  bash "configure-cloudera-management-services" do
    user "root"
    code <<-EOH
mysqladmin -u root password 'crowbar'
mysqladmin -u root -h $(hostname) password 'crowbar'
mysql --user=root --password=crowbar -e "create database activity_monitor;"
mysql --user=root --password=crowbar -e "grant all on activity_monitor.* TO 'scm'@'localhost' identified by 'crowbar';"
mysql --user=root --password=crowbar -e "create database service_monitor;"
mysql --user=root --password=crowbar -e "grant all on service_monitor.* TO 'scm'@'localhost' identified by 'crowbar';"
mysql --user=root --password=crowbar -e "create database resource_manager;"
mysql --user=root --password=crowbar -e "grant all on resource_manager.* TO 'scm'@'localhost' identified by 'crowbar';"
touch /usr/share/cmf/schema/scm_sql_setup_complete
exit 0  
  EOH
  end
else
  Chef::Log.info("CM - Activity monitor services already configured") if debug
end

#######################################################################
# End of recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:mgmtservices") if debug
