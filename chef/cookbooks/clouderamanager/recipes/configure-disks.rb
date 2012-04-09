#
# Cookbook Name: clouderamanager
# Recipe: configure-disks.rb
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
# Begin recipe
#######################################################################

debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:configure-disks") if debug

# Find all the disks.
to_use_disks = []
found_disks = []
all_disks = node[:crowbar][:disks]

all_disks.each { |k,v|
  to_use_disks << k if v["usage"] == "Storage"  
}

Chef::Log.info("CM - found disk: #{to_use_disks.join(':')}") if debug  

dfs_base_dir = node[:clouderamanager][:hdfs][:dfs_base_dir]

# Walk over each of the disks, configuring it if we have to.
node[:clouderamanager][:devices] = []
node[:clouderamanager][:hdfs][:dfs_data_dir] = []
node[:clouderamanager][:mapred][:mapred_local_dir] = []
wait_for_format = false

def get_uuid(disk)
  uuid=nil
  IO.popen("blkid -c /dev/null -s UUID -o value #{disk}"){ |f|
    uuid=f.read.strip
  }
  uuid
end

to_use_disks.sort.each { |k|
  # By default, we will format first partition.
  target_suffix= k + "1" 
  target_dev = "/dev/#{k}"
  target_dev_part = "/dev/#{target_suffix}"
  # Protect against OS's that confuse ohai. if the device isn't there,
  # don't try to use it.
  if ! File.exists?(target_dev)
    Chef::Log.warn("CM - device: #{target_dev} doesn't seem to exist. ignoring")
    next
  end
  disk = Hash.new
  disk[:name] = target_dev_part
  
  # Make sure that the kernel is aware of the current state of the 
  # drive partition tables.
  ::Kernel.system("partprobe #{target_dev}")
  # Let udev catch up, if needed
  sleep 3
  
  # Create the first partition on the disk if it does not already exist.
  # This takes barely any time, so don't bother parallelizing it.
  # Create the first partition starting at 1MB into the disk, and use GPT.
  # This ensures that it is optimally aligned from an RMW cycle minimization
  # standpoint for just about everything -- RAID stripes, SSD erase blocks, 
  # 4k sector drives, you name it, and we can have >2TB volumes.
  unless ::Kernel.system("grep -q \'#{target_suffix}$\' /proc/partitions")
    Chef::Log.info("CM - Creating hadoop partition on #{target_dev}")
    ::Kernel.system("parted -s #{target_dev} -- unit s mklabel gpt mkpart primary ext2 2048s -1M")
    ::Kernel.system("partprobe #{target_dev}")
    sleep 3
    ::Kernel.system("dd if=/dev/zero of=#{target_dev_part} bs=1024 count=65")
  end
  
  # Check to see if there is a volume on the first partition of the 
  # drive.  If not, fork and exec our formatter.  We will wait later.
  if ::Kernel.system("blkid -c /dev/null #{target_dev_part} &>/dev/null")
    # This filesystem already exists.  Save its UUID for later.
    disk[:uuid]=get_uuid target_dev_part
  else
    Chef::Log.info("CM - formatting #{target_dev_part}") if debug
    ::Kernel.exec "mkfs.ext3 #{target_dev_part}" unless ::Process.fork
    disk[:fresh] = true
    wait_for_format = true
  end
  
  found_disks << disk.dup
}

# Wait for formatting to finish
if wait_for_format
  Chef::Log.info("CM - Waiting on all drives to finish formatting") if debug
  ::Process.waitall
end

# Setup the mount points, if needed
found_disks.each { |disk|
  if disk[:fresh]
    # We just created this filesystem.  
    # Grab its UUID and create a mount point.
    disk[:uuid]=get_uuid disk[:name]
    Chef::Log.info("CM - Adding #{disk[:name]} (#{disk[:uuid]}) to the Hadoop configuration.")
    disk[:mount_point]="#{dfs_base_dir}/#{disk[:uuid]}"
    ::Kernel.system("mkdir -p #{disk[:mount_point]}")
  elsif disk[:uuid]
    # This filesystem already existed.
    # If we did not create a mountpoint for it, print a warning and skip it.
    disk[:mount_point]="#{dfs_base_dir}/#{disk[:uuid]}"
    unless ::File.exists?(disk[:mount_point]) and ::File.directory?(disk[:mount_point])
      Chef::Log.warn("CM - #{disk[:name]} (#{disk[:uuid]}) was not created by configure-disks, ignoring.")
      Chef::Log.warn("CM - If you want to use this disk, please erase any data on it and zero the partition information.")
      next
    end
  end
  
  node[:clouderamanager][:devices] << disk
  node[:clouderamanager][:hdfs][:dfs_data_dir] << ::File.join(disk[:mount_point],"data")
  node[:clouderamanager][:mapred][:mapred_local_dir] << ::File.join(disk[:mount_point],"mapred")
  mount disk[:mount_point]  do  
    device disk[:uuid]
    device_type :uuid
    options "noatime,nodiratime"
    dump 0  
    pass 0 # no FSCK testing.
    fstype "ext3"
    action [:mount, :enable]
  end
}

# Prevent unneeded churn in the recipes by making sure things are sorted.
node[:clouderamanager][:hdfs][:dfs_data_dir].sort!
node[:clouderamanager][:mapred][:mapred_local_dir].sort!
node.save

#######################################################################
# End of recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:configure-disks") if debug
