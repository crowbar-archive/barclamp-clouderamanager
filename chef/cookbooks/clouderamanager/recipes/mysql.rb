#
# Cookbook Name: clouderamanager
# Recipe: mysql.rb
#
# Copyright (c) 2011 Dell Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
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
Chef::Log.info("CM - BEGIN clouderamanager:mysql") if debug

# Install MYSQL.
package "mysql-server" do
  action :install
end

# Define the MYSQL server service.
# /etc/init.d/mysqld {start|stop|status|condrestart|restart}
service "mysqld" do
  supports :start => true, :stop => true, :status => true, :restart => true
  action :enable
end

# Install the MYSQL JDBC connector. This is used for the CM activity_monitor,
# service_monitor and resource_manager.
if not File.exists?("/usr/share/cmf/lib/mysql-connector-java-5.1.18-bin.jar")
  Chef::Log.info("CM - Installing mysql JDBC connector") if debug
  
  directory "/usr/share/cmf/lib" do
    owner "root"
    group "root"
    mode "0755"
    recursive true
    action :create
  end
  
  cookbook_file "/usr/share/cmf/lib/mysql-connector-java-5.1.18-bin.jar" do
    source "mysql-connector-java-5.1.18-bin.jar"
    mode "0755"
    notifies :restart, resources(:service => "mysqld")
  end
else
  Chef::Log.info("CM - mysql JDBC connector already installed") if debug
end

# Start the MYSQL server.
service "mysqld" do
  action :start
end

#######################################################################
# End of recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:mysql") if debug
