#
# Cookbook Name: clouderamanager
# Recipe: cm-server.rb
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

include_recipe "clouderamanager::cm-common"

#######################################################################
# Begin recipe transactions
#######################################################################

debug = node[:clouderamanager][:debug]

# mysql or postgresal data backing store
use_mysql = node[:clouderamanager][:use_mysql] 

Chef::Log.info("CLOUDERAMANAGER : BEGIN clouderamanager:cm-server") if debug

# Install the Cloudera Manager server packages.
pkg_list=%w{
    cloudera-manager-daemons
    cloudera-manager-server
  }

pkg_list.each do |pkg|
  package pkg do
    action :install
  end
end

# Cloudera Manager needs to have this directory accessible. Without it,
# slave node installations will fail. This is an empty directory and the
# RPM package installer does not seem to create it.
directory "/usr/share/cmf/packages" do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# Define the cloudera Manager service.
# cloudera-scm-server {start|stop|restart|status}
service "cloudera-scm-server" do
  supports :start => true, :stop => true, :restart => true, :status => true 
  action :enable 
end

# Install the Cloudera Manager database component. 
if use_mysql
  include_recipe 'clouderamanager::mysql'
  
  # Install the JDBC J connector.
  cookbook_file "/usr/share/cmf/lib/mysql-connector-java-5.1.18-bin.jar" do
    source "mysql-connector-java-5.1.18-bin.jar"  
    mode "0755"
    notifies :restart, resources(:service => "cloudera-scm-server")
  end
  
else
  include_recipe 'clouderamanager::postgresql'
end

# Install the Cloudera Manager server db package.
package "cloudera-manager-server-db" do
  action :install
end

# Setup the database tables
if use_mysql
  if !File.exists?("/usr/share/cmf/schema/scm_sql_setup_complete")
    Chef::Log.info("CLOUDERAMANAGER : Running Cloudera Manager SQL setup") if debug
    # Setup the mysql configuration.
    bash "setup-database" do
      user "root"
      code <<-EOH
  mysqladmin -u root password 'crowbar'
  mysqladmin -u root -h $(hostname) password 'crowbar'
  mysql --user=root --password=crowbar -e "create database hue;"
  mysql --user=root --password=crowbar -e "grant all on hue.* to 'hue'@'localhost' identified by 'hue';"
  mysql --user=root --password=crowbar -e "create database oozie;"
  mysql --user=root --password=crowbar -e "grant all on oozie.* to 'oozie'@'localhost' identified by 'oozie';"
  mysql --user=root --password=crowbar -e "create database cmon;"
  mysql --user=root --password=crowbar -e "grant all on cmon.* to 'cmon'@'localhost' identified by 'cmon';"
  /usr/share/cmf/schema/scm_prepare_mysql.sh -p crowbar scm scm scm
  touch /usr/share/cmf/schema/scm_sql_setup_complete
  exit 0  
  EOH
      notifies :restart, resources(:service => "cloudera-scm-server")
    end
  else
    Chef::Log.info("CLOUDERAMANAGER : Cloudera Manager SQL setup already complete") if debug
  end
else
  # Setup the postgresql configuration.
  # This will only run if the db is uninitialized.
  # Otherwise : returns 1 
  # /var/lib/cloudera-scm-server-db/data is non-empty; perhaps the database was already initialized?
  bash "cloudera-scm-server-db" do
    code <<-EOH
/etc/init.d/cloudera-scm-server-db initdb
EOH
    # Should only notify on initial creation only.
    # notifies :restart, resources(:service => "cloudera-scm-server")
    returns [0, 1] 
  end
end

# Start the cloudera SCM server.
service "cloudera-scm-server" do
  action :start 
end

#######################################################################
# End of recipe transactions
#######################################################################
Chef::Log.info("CLOUDERAMANAGER : END clouderamanager:cm-server") if debug
