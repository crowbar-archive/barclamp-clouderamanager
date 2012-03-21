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
    # You need at least 3 nodes (secondary namenode, master namenode
    # and slavenode) to implement a baseline Hadoop framework. The edgenode
    # is added if the node count is 4 or higher. 
    admin = []
    master = []
    edge = []
    slaves = []
    
    # Get the node list, find the admin node, put the Hadoop
    # secondary name node on the crowbar admin node (as specified by
    # the RA) and delete the admin node from the array.
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
    
    # Add the master, slave and edge nodes.
    if nodes.size == 1
      master << nodes[0][:fqdn] if nodes[0][:fqdn]
    elsif nodes.size == 2
      master << nodes[0][:fqdn] if nodes[0][:fqdn]
      slaves << nodes[1][:fqdn] if nodes[1][:fqdn]        
    elsif nodes.size == 3
      master << nodes[0][:fqdn] if nodes[0][:fqdn]
      slaves << nodes[1][:fqdn] if nodes[1][:fqdn]        
      edge << nodes[2][:fqdn] if nodes[2][:fqdn]
    elsif nodes.size > 3
      master << nodes[0][:fqdn] if nodes[0][:fqdn]
      slaves << nodes[1][:fqdn] if nodes[1][:fqdn]        
      edge << nodes[2][:fqdn] if nodes[2][:fqdn]
      nodes[3 .. nodes.size].each { |n|
        slaves << n[:fqdn] if n[:fqdn]
      }
    end
    
    # Add the proposal deployment elements. The Cloudera Management
    # server/UI goes on the Hadoop master name node by default and
    # this can be changed by the user at proposal deployment time.
    base["deployment"]["clouderamanager"]["elements"] = {} 
    
    if admin and !admin.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-webapp"] = admin 
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-secondarynamenode"] = admin 
    end
    
    if master and !master.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-masternamenode"] = master 
    end    
    
    if edge and !edge.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-edgenode"] = edge
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-mgmtservices"] = edge 
    end
    
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
    
    # Make sure that the front-end pieces have public ip addreses.
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
