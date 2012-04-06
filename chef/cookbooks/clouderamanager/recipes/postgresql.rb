#
# Cookbook Name: clouderamanager
# Recipe: postgresql.rb
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
# Begin recipe transactions
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:postgresql") if debug

postgresql_list=%w{
    postgresql
    postgresql-server
  }

postgresql_list.each do |pkg|
  package pkg do
    action :install
  end
end

# postgresql {start|stop|status|restart|condrestart|try-restart|reload|force-reload|initdb}
service "postgresql" do
  supports :start => true, :stop => true, :status => true, :restart => true
  action :enable 
end

# Initialize the postgresql database.
if !File.exists?("/var/lib/pgsql/data/PG_VERSION")
  Chef::Log.info("CM - Initializing the postgresql database") if debug
  bash "postgresql-initdb" do
    user "root"
    code <<-EOH
service postgresql initdb
exit 0  
  EOH
  end
else
  Chef::Log.info("CM - postgresql database already initialized") if debug
end

# Start the postgresql service.
service "postgresql" do
  action :start 
end

#######################################################################
# End of recipe transactions
#######################################################################
Chef::Log.info("CM - END clouderamanager:postgresql") if debug
