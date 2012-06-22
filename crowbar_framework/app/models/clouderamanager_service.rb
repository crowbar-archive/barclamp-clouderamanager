#
# Barclamp: clouderamanager
# Recipe: clouderamanager_service.rb
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

class ClouderamanagerService < ServiceObject
  
  #######################################################################
  # initialize - Initialize this service class.
  #######################################################################
  def initialize(thelogger)
    @bc_name = "clouderamanager"
    @logger = thelogger
  end
  
  #######################################################################
  # create_proposal - called on proposal creation.
  #######################################################################
  def create_proposal
    @logger.debug("clouderamanager create_proposal: entering")
    base = super
    
    # Compute the Hadoop cluster node distribution.
    admin = []
    namenode = []
    secondary = []
    edge = []
    hafiler = []
    slaves = []
    
    # Find the admin node and delete it from the data set.
    nodes = NodeObject.all
    nodes.each do |n|
      if n.nil?
        nodes.delete(n)
        next
      end
      if n.admin?
        admin << n[:fqdn] if n[:fqdn]
        nodes.delete(n)
      end
    end
    
    # Configure the name, edge, hafiler and slave nodes.
    if nodes.size == 1
      namenode << nodes[0][:fqdn] if nodes[0][:fqdn]
    elsif nodes.size == 2
      namenode << nodes[0][:fqdn] if nodes[0][:fqdn]
      secondary << nodes[1][:fqdn] if nodes[1][:fqdn]
    elsif nodes.size == 3
      namenode << nodes[0][:fqdn] if nodes[0][:fqdn]
      secondary << nodes[1][:fqdn] if nodes[1][:fqdn]
      hafiler << nodes[2][:fqdn] if nodes[2][:fqdn]
    elsif nodes.size == 4
      namenode << nodes[0][:fqdn] if nodes[0][:fqdn]
      secondary << nodes[1][:fqdn] if nodes[1][:fqdn]
      hafiler << nodes[2][:fqdn] if nodes[2][:fqdn]
      edge << nodes[3][:fqdn] if nodes[3][:fqdn]
    elsif nodes.size > 4
      namenode << nodes[0][:fqdn] if nodes[0][:fqdn]
      secondary << nodes[1][:fqdn] if nodes[1][:fqdn]
      hafiler << nodes[2][:fqdn] if nodes[2][:fqdn]
      edge << nodes[3][:fqdn] if nodes[3][:fqdn]
      nodes[4 .. nodes.size].each { |n|
        slaves << n[:fqdn] if n[:fqdn]
      }
    end
    
    # Add the proposal deployment elements. 
    base["deployment"]["clouderamanager"]["elements"] = {} 
    
    # The Cloudera manager web application defaults to the crowbar admin node.
    if admin and !admin.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-webapp"] = admin 
    end
    
    # Master name node.
    if namenode and !namenode.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-masternamenode"] = namenode 
    end    
    
    # Secondary name node.
    if secondary and !secondary.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-secondarynamenode"] = secondary 
    end
    
    # Hadoop High Availability (HA) filer node.
    if hafiler and !hafiler.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-ha-filer"] = hafiler
    end

    # Edge node with a public exposed network. 
    if edge and !edge.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-edgenode"] = edge
    end
    
    # Slave nodes.
    if slaves and !slaves.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-slavenode"] = slaves   
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
  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("clouderamanager apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    return if all_nodes.empty? 
    
    # Assign a public IP address to the edge node for external access.
    net_svc = NetworkService.new @logger
    [ "clouderamanager-edgenode" ].each do |element|
      tnodes = role.override_attributes["clouderamanager"]["elements"][element]
      next if tnodes.nil? or tnodes.empty?
      
      # Allocate the IP addresses for default, public, host.
      tnodes.each do |n|
        next if n.nil?
        net_svc.allocate_ip "default", "public", "host", n
      end
    end
    
    @logger.debug("clouderamanager apply_role_pre_chef_call: leaving")
  end
end
