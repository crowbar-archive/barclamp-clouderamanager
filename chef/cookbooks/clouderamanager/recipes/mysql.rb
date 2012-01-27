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
Chef::Log.info("CLOUDERAMANAGER : BEGIN clouderamanager:mysql") if debug

# Install MYSQL.
package "mysql-server" do
  action :install
end

# Start the MYSQL server.
# /etc/init.d/mysqld {start|stop|status|condrestart|restart}
service "mysqld" do
  supports :start => true, :stop => true, :status => true, :restart => true
  action [ :enable, :start ] 
end

#######################################################################
# End of recipe transactions
#######################################################################
Chef::Log.info("CLOUDERAMANAGER : END clouderamanager:mysql") if debug
