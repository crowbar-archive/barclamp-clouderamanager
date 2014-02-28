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
    @hadoop_config = {
      :adminnodes => [],
      :servernodes => [],
      :namenodes => [],
      :edgenodes => [],
      :datanodes => [],
      :hajournalingnodes => [],
      :hafilernodes => [] 
    }
  end
  
  #######################################################################
  # get_hadoop_config - Get the Hadoop related configuration.
  #######################################################################
  def get_hadoop_config
    nodeswithroles    = NodeObject.all.find_all { |n| n.roles != nil }
    adminnodes        = nodeswithroles.find_all { |n| n.roles.include?("hadoop_infrastructure-cb-adminnode" ) }
    servernodes       = nodeswithroles.find_all { |n| n.roles.include?("hadoop_infrastructure-server" ) }
    namenodes         = nodeswithroles.find_all { |n| n.roles.include?("hadoop_infrastructure-namenode" ) }
    edgenodes         = nodeswithroles.find_all { |n| n.roles.include?("hadoop_infrastructure-edgenode" ) }
    datanodes         = nodeswithroles.find_all { |n| n.roles.include?("hadoop_infrastructure-datanode" ) }
    hajournalingnodes = nodeswithroles.find_all { |n| n.roles.include?("hadoop_infrastructure-ha-journalingnode" ) }
    hafilernodes      = nodeswithroles.find_all { |n| n.roles.include?("hadoop_infrastructure-ha-filernode" ) }
    @hadoop_config[:adminnodes] = adminnodes.sort { |a,b| a.license_key <=> b.license_key } 
    @hadoop_config[:servernodes] = servernodes.sort { |a,b| a.license_key <=> b.license_key } 
    @hadoop_config[:namenodes] = namenodes.sort { |a,b| a.license_key <=> b.license_key } 
    @hadoop_config[:edgenodes] = edgenodes.sort { |a,b| a.license_key <=> b.license_key } 
    @hadoop_config[:datanodes] = datanodes.sort { |a,b| a.license_key <=> b.license_key } 
    @hadoop_config[:hajournalingnodes] = hajournalingnodes.sort { |a,b| a.license_key <=> b.license_key } 
    @hadoop_config[:hafilernodes] = hafilernodes.sort { |a,b| a.license_key <=> b.license_key }
    return @hadoop_config
  end
  
  #######################################################################
  # to_fqdn_array - Convert a node array to a FQDN array.
  #######################################################################
  def to_fqdn_array(nodes)
    fqdn_array = []
    nodes.each do |n|
      if n[:fqdn] and not n[:fqdn].empty?
        fqdn_array << n[:fqdn]
      end
    end
    return fqdn_array
  end
  
  #######################################################################
  # create_proposal - called on proposal creation.
  #######################################################################
  def create_proposal
    @logger.debug("clouderamanager create_proposal: entering")
    base = super
    hadoop_config = get_hadoop_config
    
    #--------------------------------------------------------------------
    # Convert to an array of fqdn strings. 
    #--------------------------------------------------------------------
    adminnodes        = to_fqdn_array(hadoop_config[:adminnodes])
    servernodes       = to_fqdn_array(hadoop_config[:servernodes])
    namenodes         = to_fqdn_array(hadoop_config[:namenodes])
    edgenodes         = to_fqdn_array(hadoop_config[:edgenodes])
    datanodes         = to_fqdn_array(hadoop_config[:datanodes])
    hajournalingnodes = to_fqdn_array(hadoop_config[:hajournalingnodes])
    hafilernodes      = to_fqdn_array(hadoop_config[:hafilernodes])
    
    #--------------------------------------------------------------------
    # proposal deployment elements. 
    #--------------------------------------------------------------------
    base["deployment"]["clouderamanager"]["elements"] = {} 
    
    # Crowbar adminnode.
    if not adminnodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-cb-adminnode"] = adminnodes 
    end    
    
    # Hadoop cm servernodes.  
    if not servernodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-server"] = servernodes 
    end
    
    # Hadoop namenodes.
    if not namenodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-namenode"] = namenodes 
    end    
    
    # Hadoop edgenodes. 
    if not edgenodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-edgenode"] = edgenodes
    end
    
    # Hadoop datanodes.
    if not datanodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-datanode"] = datanodes   
    end
    
    # Hadoop hafilernodes.
    if not hafilernodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-ha-filernode"] = hafilernodes 
    end
    
    # Hadoop hajournaling nodes. 
    if not hajournalingnodes.empty?    
      base["deployment"]["clouderamanager"]["elements"]["clouderamanager-ha-journalingnode"] = hajournalingnodes 
    end
    
    # @logger.debug("clouderamanager create_proposal: #{base.to_json}")
    @logger.debug("clouderamanager create_proposal: exiting")
    base
  end
  
  #######################################################################
  # apply_role_pre_chef_call - Called before a chef role is applied.
  #######################################################################
  def apply_role_pre_chef_call(old_role, role, all_nodes)
    @logger.debug("clouderamanager apply_role_pre_chef_call: entering #{all_nodes.inspect}")
    nodeswithroles = NodeObject.all.find_all { |n| n.roles != nil }
    servernodes    = nodeswithroles.find_all { |n| n.roles.include?("hadoop_infrastructure-server" ) }
    
    # Set the CM server UI link on the CB node screen.
    link_name = 'Cloudera Manager'
    if servernodes and not servernodes.empty?
      servernodes.each do |node|
        use_pub_network = false
        pub = node.get_network_by_type("public")
        if use_pub_network and pub and pub["address"] and not pub["address"].empty?
          server_ip = pub["address"]
        else
          server_ip = node.get_network_by_type("admin")["address"]
        end
        node.crowbar["crowbar"] = {} if node.crowbar["crowbar"].nil?
        node.crowbar["crowbar"]["links"] = {} if node.crowbar["crowbar"]["links"].nil?
        if server_ip and not server_ip.empty? 
          url = "http://#{server_ip}:7180/cmf/login" 
          @logger.debug("clouderamanager server URL [#{url}]")
          node.crowbar["crowbar"]["links"][link_name] = url
        else
          @logger.debug("clouderamanager server URL [clear]")
          node.crowbar["crowbar"]["links"].delete(link_name)
        end
        node.save
      end
    end
    
    @logger.debug("clouderamanager apply_role_pre_chef_call: leaving")
  end
end
