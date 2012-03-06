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

# Crowbar configuration enviroment.
default[:clouderamanager][:config] = {}
default[:clouderamanager][:config][:environment] = "clouderamanager-config-default"

# Configuration parameters.
default[:clouderamanager][:cluster] = {}
default[:clouderamanager][:cluster][:master_name_nodes] = [ ]
default[:clouderamanager][:cluster][:secondary_name_nodes] = [ ]
default[:clouderamanager][:cluster][:edge_nodes] = [ ]
default[:clouderamanager][:cluster][:slave_nodes] = [ ]

default[:clouderamanager][:hdfs][:dfs_base_dir] = "/mnt/hdfs"
default[:clouderamanager][:hdfs][:dfs_data_dir] = []
default[:clouderamanager][:devices] = []
default[:clouderamanager][:mapred][:mapred_local_dir] = []
