#
# Cookbook Name: clouderamanager
# Attributes: default.rb
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
# Crowbar barclamp configuration parameters.
#######################################################################

default[:clouderamanager][:debug] = true

# Cloudera Manager backing store.
# use mysql or postgresal (cloudera default - postgresal).
default[:clouderamanager][:use_mysql] = false 

# This flag determines if the cloudera_manager will be used to deploy
# and maintain the hadoop cluster. If set to false, Crowbar with deploy
# and maintain the baseline hadoop cluster. The intented use is automatic
# smoke testing of the crowbar deployment which we can not do via Cloudera
# manager deployment. See the modify-json file under the smoketest folder.
# The regex inside should flip this flag to false for continuous integration
# testing. 
default[:clouderamanager][:use_cloudera_manager] = "true"

# Crowbar configuration enviroment.
default[:clouderamanager][:config] = {}
default[:clouderamanager][:config][:environment] = "clouderamanager-config-default"

# Cluster attributes.
default[:clouderamanager][:cluster] = {}
default[:clouderamanager][:cluster][:master_name_nodes] = [ ]
default[:clouderamanager][:cluster][:secondary_name_nodes] = [ ]
default[:clouderamanager][:cluster][:edge_nodes] = [ ]
default[:clouderamanager][:cluster][:slave_nodes] = [ ]

# File system ownership settings.
default[:clouderamanager][:cluster][:valid_config] = true
default[:clouderamanager][:cluster][:global_file_system_group] = "hadoop"
default[:clouderamanager][:cluster][:process_file_system_owner] = "root"
default[:clouderamanager][:cluster][:mapred_file_system_owner] = "mapred"
default[:clouderamanager][:cluster][:hdfs_file_system_owner] = "hdfs"
default[:clouderamanager][:cluster][:hdfs_file_system_group] = "hdfs"
