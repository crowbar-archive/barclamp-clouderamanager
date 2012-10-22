#
# Barclamp: clouderamanager
# Recipe: clouderamanager_service.rb
#
# Copyright (c) 2012 Dell Inc.
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

class ClouderamanagerService < ServiceObject
  
  #######################################################################
  # create_proposal - called on proposal creation.
  #######################################################################
  def create_proposal(name)
    @logger.debug("clouderamanager create_proposal: entering")
    base = super(name)
    
    # Compute the Hadoop cluster node distribution.
    admin = []
    namenode = []
    secondary = []
    edge = []
    hafiler = []
    slaves = []
    
    # Find the admin node and delete it from the data set.
    nodes = Node.all
    nodes.each do |n|
      if n.admin?
        admin << n.name
        nodes.delete(n)
      end
    end
    
    # Configure the name, edge, hafiler and slave nodes.
    if nodes.size == 1
      namenode << nodes[0].name if nodes[0].name
    elsif nodes.size == 2
      namenode << nodes[0].name if nodes[0].name
      secondary << nodes[1].name if nodes[1].name
    elsif nodes.size == 3
      namenode << nodes[0].name if nodes[0].name
      secondary << nodes[1].name if nodes[1].name
      hafiler << nodes[2].name if nodes[2].name
    elsif nodes.size == 4
      namenode << nodes[0].name if nodes[0].name
      secondary << nodes[1].name if nodes[1].name
      hafiler << nodes[2].name if nodes[2].name
      edge << nodes[3].name if nodes[3].name
    elsif nodes.size > 4
      namenode << nodes[0].name if nodes[0].name
      secondary << nodes[1].name if nodes[1].name
      hafiler << nodes[2].name if nodes[2].name
      edge << nodes[3].name if nodes[3].name
      nodes[4 .. nodes.size].each { |n|
        slaves << n.name if n.name
      }
    end
    
    # The Cloudera manager web application defaults to the crowbar admin node.
    if admin and !admin.empty?    
      admin.each do |a|
        add_role_to_instance_and_node(a, base.name, "clouderamanager-webapp")
      end
    end
    
    # Master name node.
    if namenode and !namenode.empty?    
      namenode.each do |a|
        add_role_to_instance_and_node(a, base.name, "clouderamanager-masternamenode")
      end
    end    
    
    # Secondary name node.
    if secondary and !secondary.empty?    
      secondary.each do |a|
        add_role_to_instance_and_node(a, base.name, "clouderamanager-secondarynamenode")
      end
    end
    
    # Hadoop High Availability (HA) filer node.
    if hafiler and !hafiler.empty?    
      hafiler.each do |a|
        add_role_to_instance_and_node(a, base.name, "clouderamanager-ha-filer")
      end
    end

    # Edge node with a public exposed network. 
    if edge and !edge.empty?    
      edge.each do |a|
        add_role_to_instance_and_node(a, base.name, "clouderamanager-edgenode")
      end
    end
    
    # Slave nodes.
    if slaves and !slaves.empty?    
      slaves.each do |slave|
        add_role_to_instance_and_node(slave, base.name, "clouderamanager-slavenode")
      end
    end
    
    # @logger.debug("clouderamanager create_proposal: #{base.to_json}")
    @logger.debug("clouderamanager create_proposal: exiting")
    base
  end
  
  #######################################################################
  # apply_role_pre_chef_call - Called before a chef role is applied.
  # This code block is setting up for public IP addresses on the Hadoop
  # edge node.
  #######################################################################
  def apply_role_pre_chef_call(old_config, new_config, all_nodes)
    @logger.debug("clouderamanager apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty? 
    
    # Assign a public IP address to the edge node for external access.
    net_barclamp = Barclamp.find_by_name("network")
    tnodes = new_config.get_nodes_by_role("clouderamanager-edgenode")
    # Allocate the IP addresses for default, public, host.
    tnodes.each do |n|
      net_barclamp.operations(@logger).allocate_ip "default", "public", "host", n.name
    end
    
    @logger.debug("clouderamanager apply_role_pre_chef_call: leaving")
  end
end
