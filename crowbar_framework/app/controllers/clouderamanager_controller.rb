#
# Barclamp: clouderamanager
# Recipe: clouderamanager_controller.rb
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

class ClouderamanagerController < BarclampController

  def nodes
    @cmmasternamenodes              = Node.find_by_role_name("clouderamanager-masternamenode" )
    @cmsecondarynamenodenamenodes   = Node.find_by_role_name("clouderamanager-secondarynamenode")
    @cmedgenodes                    = Node.find_by_role_name("clouderamanager-edgenode")
    @cmslavenodes                   = Node.find_by_role_name("clouderamanager-slavenode")
    @cmhafilernodes                 = Node.find_by_role_name("clouderamanager-ha-filer")
    @cmwebappnodes                  = Node.find_by_role_name("clouderamanager-webapp")
    
    respond_to do |format|
      format.html { render :template => 'barclamp/clouderamanager/nodes' }
      format.text {
        export = ["role, ip, name, cpu, ram, drives"]
        @cmmasternamenodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.master_name_node') + ", #{node.jig_ip}, #{node.name}, #{node.jig_cpu}, #{node.jig_memory}, #{node.jig_number_of_drives}"
        end
        @cmsecondarynamenodenamenodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.secondary_name_node') + ", #{node.jig_ip}, #{node.name}, #{node.jig_cpu}, #{node.jig_memory}, #{node.jig_number_of_drives}"
        end
        @cmedgenodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.edge_node') + ", #{node.jig_ip}, #{node.name}, #{node.jig_cpu}, #{node.jig_memory}, #{node.jig_number_of_drives}"
        end
        @cmslavenodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.slave_nodes') + ", #{node.jig_ip}, #{node.name}, #{node.jig_cpu}, #{node.jig_memory}, #{node.jig_number_of_drives}"
        end
        @cmwebappnodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.web_app_node') + ", #{node.jig_ip}, #{node.name}, #{node.jig_cpu}, #{node.jig_memory}, #{node.jig_number_of_drives}"
        end
        @cmhafilernodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.ha_filer_node') + ", #{node.jig_ip}, #{node.name}, #{node.jig_cpu}, #{node.jig_memory}, #{node.jig_number_of_drives}"
        end
        headers["Content-Disposition"] = "attachment; filename=\"#{I18n.t('nodes.dell.nodes.filename', :default=>'cloudera_inventory.txt')}\""
        render :text => export.join("\n"), :content_type => 'application/text'
      }
    end
  end
  
end

