#
# Cookbook Name: clouderamanager
# Attributes: default.rb
#
# Copyright (c) 2011 Dell Inc.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#######################################################################
# Global configuration parameters.
#######################################################################
default[:clouderamanager][:debug] = false

#######################################################################
# Crowbar configuration parameters.
#######################################################################
default[:clouderamanager][:config] = {}
default[:clouderamanager][:config][:environment] = 'clouderamanager-config-default'

#######################################################################
# CM API configuration parameters.
#######################################################################
default[:clouderamanager][:cmapi] = {}
default[:clouderamanager][:cmapi][:deployment_type] = 'manual'
default[:clouderamanager][:cmapi][:server_port] = '7180'
default[:clouderamanager][:cmapi][:username] = 'admin'
default[:clouderamanager][:cmapi][:password] = 'admin'
default[:clouderamanager][:cmapi][:use_tls] = false
default[:clouderamanager][:cmapi][:version] = '2'

#######################################################################
# CM server configuration parameters.
#######################################################################
default[:clouderamanager][:server][:db_type] = 'postgresql'

#######################################################################
# Cluster configuration parameters.
#######################################################################
default[:clouderamanager][:cluster] = {}
default[:clouderamanager][:cluster][:auto_pkgs_installed] = false
default[:clouderamanager][:cluster][:cm_api_configured] = false
default[:clouderamanager][:cluster][:cluster_name] = 'cluster01'
default[:clouderamanager][:cluster][:cdh_version] = 'CDH4'
default[:clouderamanager][:cluster][:license_key] = ''
default[:clouderamanager][:cluster][:rack_id] = '/default'
