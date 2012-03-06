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
    secondary = [ ]
    master = [ ]
    edge = [ ]
    slaves = [ ]
    
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
        secondary << n[:fqdn] if n[:fqdn]
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
    base["deployment"]["clouderamanager"]["elements"] = { } 
    
    if master && !master.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-masternamenode"] = master 
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-webapp"] = master 
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-mgmtservices"] = master 
    end    
    
    base["deployment"]["clouderamanager"]["elements"]["clouderamanager-secondarynamenode"] = secondary if secondary && !secondary.empty? 
    base["deployment"]["clouderamanager"]["elements"]["clouderamanager-edgenode"] = edge if edge && !edge.empty?  
    base["deployment"]["clouderamanager"]["elements"]["clouderamanager-slavenode"] = slaves if slaves && !slaves.empty?   
    
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
  
  #######################################################################
  # transition - Called for crowbar state transitions.
  # Add the Cloudera Management web application link to the Crowbar UI.
  #######################################################################
  def transition(inst, name, state)
    @logger.debug("Cloudera Manager transition: Adding Cloudera Management web application URL: #{name} for #{state}")
    
    if state == "discovered"
      @logger.debug("Cloudera Manager transition: discovered state for #{name} for #{state}")
      
      # Set up the Cloudera Management web application URL.
      role = RoleObject.find_role_by_name "clouderamanager-config-#{inst}"
      
      # Get the Cloudera Management web application IP address.
      server_ip = nil
      [ "clouderamanager-webapp" ].each do |element|
        tnodes = role.override_attributes["clouderamanager"]["elements"][element]
        next if tnodes.nil? or tnodes.empty?
        tnodes.each do |n|
          next if n.nil?
          node = NodeObject.find_node_by_name(n)
          if node.get_network_by_type("public")["address"].nil? or node.get_network_by_type("public")["address"].empty?
            server_ip = node.get_network_by_type("admin")["address"]
          else
            server_ip = node.get_network_by_type("public")["address"]
          end
        end
      end
      
      if server_ip
        node = NodeObject.find_node_by_name(name)
        node.crowbar["crowbar"] = {} if node.crowbar["crowbar"].nil?
        node.crowbar["crowbar"]["links"] = {} if node.crowbar["crowbar"]["links"].nil?
        node.crowbar["crowbar"]["links"]["Cloudera Manager"] = "http://#{server_ip}:7180/cmf/login"
        node.save
      end
      
      @logger.debug("Cloudera Manager transition: leaving from discovered state for #{name} for #{state}")
      a = [200, NodeObject.find_node_by_name(name).to_hash ]
      return a
    end
    
    @logger.debug("Cloudera Manager transition: leaving for #{name} for #{state}")
    [200, NodeObject.find_node_by_name(name).to_hash ]
  end
  
end
