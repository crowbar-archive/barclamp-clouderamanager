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
    
    adminnodes = [] # Crowbar admin node (size=1).
    namenodes = []  # Hadoop name nodes (active/standby).
    datanodes = []  # Hadoop data nodes (1..N, min=3).
    edgenodes = []  # Hadoop edge nodes (1..N)
    
    #--------------------------------------------------------------------
    # Make a temporary copy of all system nodes.
    # Find the admin node and delete it from the data set.
    #--------------------------------------------------------------------
    nodes = NodeObject.all.dup
    nodes.each do |n|
      if n.nil?
        nodes.delete(n)
        next
      end
      if n.admin?
        if n[:fqdn] and !n[:fqdn].empty?
          adminnodes << n[:fqdn]
        end
        nodes.delete(n)
      end
    end
    
    #--------------------------------------------------------------------
    # Configure the name nodes, edge nodes and data nodes.
    # We don't select any HA nodes by default because the end user needs to
    # make a decision if that want to deploy HA and the method to use
    # (NFS filer/Quorum based storage). These options can be selected in the 
    # the default proposal UI screen after the initial cluster topology has
    # been suggested.  
    #--------------------------------------------------------------------
    if nodes.size == 1
      namenodes << nodes[0][:fqdn] if nodes[0][:fqdn]
    elsif nodes.size == 2
      namenodes << nodes[0][:fqdn] if nodes[0][:fqdn]
      namenodes << nodes[1][:fqdn] if nodes[1][:fqdn]
    elsif nodes.size == 3
      namenodes << nodes[0][:fqdn] if nodes[0][:fqdn]
      namenodes << nodes[1][:fqdn] if nodes[1][:fqdn]
      edgenodes << nodes[2][:fqdn] if nodes[2][:fqdn]
    elsif nodes.size > 3
      namenodes << nodes[0][:fqdn] if nodes[0][:fqdn]
      namenodes << nodes[1][:fqdn] if nodes[1][:fqdn]
      edgenodes << nodes[2][:fqdn] if nodes[2][:fqdn]
      nodes[3 .. nodes.size].each { |n|
        datanodes << n[:fqdn] if n[:fqdn]
      }
    end
    
    #--------------------------------------------------------------------
    # proposal deployment elements. 
    #--------------------------------------------------------------------
    base["deployment"]["clouderamanager"]["elements"] = {} 
    
    # Crowbar admin node setup. CM API code gets executed from here by default.
    if adminnodes and !adminnodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-cb-adminnode"] = [ adminnodes[0] ] 
    end    
    
    # Name node setup (active/standby).
    if namenodes and !namenodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-namenode"] = namenodes 
    end    
    
    # Edge node setup. CM server on the first edge node by default. 
    if edgenodes and !edgenodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-edgenode"] = edgenodes
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-server"] = [ edgenodes[0] ] 
    end
    
    # Data node setup.
    if datanodes and !datanodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-datanode"] = datanodes   
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
