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

# Debug flag.
default[:clouderamanager][:debug] = true

# Crowbar configuration environment.
default[:clouderamanager][:config] = {}
default[:clouderamanager][:config][:environment] = "clouderamanager-config-default"

# Cluster configuration parameters.
default[:clouderamanager][:cluster] = {}
default[:clouderamanager][:cluster][:master_name_nodes] = [ ]
default[:clouderamanager][:cluster][:secondary_name_nodes] = [ ]
default[:clouderamanager][:cluster][:edge_nodes] = [ ]
default[:clouderamanager][:cluster][:slave_nodes] = [ ]

# Hadoop high availability (HA) parameters (CDH4/CM4).
# shared_edits_directory - Directory on a shared storage device, such as an
# NFS mount from a NAS, to store the NameNode edits.
# shared_edits_mount_options specifies the mount options for the nfs mount point.
default[:clouderamanager][:ha][:shared_edits_directory] = "/dfs/ha"
default[:clouderamanager][:ha][:shared_edits_export_options] = "rw,async,no_root_squash,no_subtree_check"
default[:clouderamanager][:ha][:shared_edits_mount_options] = "rsize=65536,wsize=65536,intr,soft,bg"

# File system type (ext3/ext4/xfs) - must be a valid mkfs type.
default[:clouderamanager][:os][:fs_type] = "ext3"

# Hadoop open file limits - /etc/security/limits.conf.
default[:clouderamanager][:os][:mapred_openfiles] = "32768"
default[:clouderamanager][:os][:hdfs_openfiles] = "32768"
default[:clouderamanager][:os][:hbase_openfiles] = "32768"

# HDFS related parameters.
default[:clouderamanager][:hdfs][:dfs_base_dir] = "/data"
default[:clouderamanager][:hdfs][:dfs_data_dir] = []
default[:clouderamanager][:devices] = []
default[:clouderamanager][:mapred][:mapred_local_dir] = []
