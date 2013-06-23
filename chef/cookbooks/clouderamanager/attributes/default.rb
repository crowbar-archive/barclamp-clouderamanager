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

#----------------------------------------------------------------------
# Global configuration parameters.
#----------------------------------------------------------------------
default[:clouderamanager][:debug] = false

#----------------------------------------------------------------------
# Crowbar configuration parameters.
#----------------------------------------------------------------------
default[:clouderamanager][:config] = {}
default[:clouderamanager][:config][:environment] = 'clouderamanager-config-default'

#----------------------------------------------------------------------
# Operating system configuration parameters.
#----------------------------------------------------------------------

# File system type (ext3/ext4). Must be a valid mkfs type (See man mkfs).
default[:clouderamanager][:os][:fs_type] = 'ext4'

# Hadoop open file limits - /etc/security/limits.conf.
default[:clouderamanager][:os][:mapred_openfiles] = '32768'
default[:clouderamanager][:os][:hdfs_openfiles] = '32768'
default[:clouderamanager][:os][:hbase_openfiles] = '32768'

#----------------------------------------------------------------------
# CM API configuration parameters.
#----------------------------------------------------------------------
default[:clouderamanager][:cmapi][:deployment_type] = 'manual'
default[:clouderamanager][:cmapi][:server_port] = '7180'
default[:clouderamanager][:cmapi][:username] = 'admin'
default[:clouderamanager][:cmapi][:password] = 'admin'
default[:clouderamanager][:cmapi][:use_tls] = false
default[:clouderamanager][:cmapi][:version] = '2'

#----------------------------------------------------------------------
# Cluster configuration parameters.
#----------------------------------------------------------------------
default[:clouderamanager][:cluster] = {}
default[:clouderamanager][:cluster][:namenodes] = []
default[:clouderamanager][:cluster][:datanodes] = []
default[:clouderamanager][:cluster][:edgenodes] = []
default[:clouderamanager][:cluster][:cmservernodes] = []
default[:clouderamanager][:cluster][:hafilernodes] = []
default[:clouderamanager][:cluster][:hajournalingnodes] = []

default[:clouderamanager][:cluster][:cluster_name] = 'cluster01'
default[:clouderamanager][:cluster][:cdh_version] = 'CDH4'
default[:clouderamanager][:cluster][:license_key] = ''
default[:clouderamanager][:cluster][:rack_id] = '/default'

#----------------------------------------------------------------------
# HDFS configuration parameters.
#----------------------------------------------------------------------
default[:clouderamanager][:hdfs][:dfs_base_dir] = '/data'
default[:clouderamanager][:hdfs][:hdfs_mounts] = []

#----------------------------------------------------------------------
# Device configuration parameters.
#----------------------------------------------------------------------
default[:clouderamanager][:devices] = []

#----------------------------------------------------------------------
# Hadoop high availability (HA) configuration (CDH4/CM4).
#----------------------------------------------------------------------

# shared_edits_directory - Directory on a shared storage device, such as
# an NFS mount from a NAS, to store the name node edits.
# shared_edits_mount_options specifies the mount options for the
# nfs mount point. These parameters are only used for NFS filer HA mode.
default[:clouderamanager][:ha][:shared_edits_directory] = '/dfs/ha'
default[:clouderamanager][:ha][:shared_edits_export_options] = 'rw,async,no_root_squash,no_subtree_check'
default[:clouderamanager][:ha][:shared_edits_mount_options] = 'rsize=65536,wsize=65536,intr,soft,bg'
