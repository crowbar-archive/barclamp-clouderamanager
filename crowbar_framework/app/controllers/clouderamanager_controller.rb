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
  def initialize
    @service_object = ClouderamanagerService.new logger
  end
  
  def nodes
    nodeswithroles = NodeObject.all.find_all { |n| n.roles != nil }
    @cmservernodes       = nodeswithroles.find_all { |n| n.roles.include?("clouderamanager-server" ) }
    @cmnamenodes         = nodeswithroles.find_all { |n| n.roles.include?("clouderamanager-namenode" ) }
    @cmdatanodes         = nodeswithroles.find_all { |n| n.roles.include?("clouderamanager-datanode" ) }
    @cmedgenodes         = nodeswithroles.find_all { |n| n.roles.include?("clouderamanager-edgenode" ) }
    @cmhajournalingnodes = nodeswithroles.find_all { |n| n.roles.include?("clouderamanager-ha-journalingnode" ) }
    @cmhafilernodes      = nodeswithroles.find_all { |n| n.roles.include?("clouderamanager-ha-filernode" ) }
    
    respond_to do |format|
      format.html { render :template => 'barclamp/clouderamanager/nodes' }
      format.text {
        export = ["role, ip, name, cpu, ram, drives"]
        @cmservernodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.servernodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @cmnamenodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.namenodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @cmdatanodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.datanodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @cmedgenodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.edgenodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @cmhajournalingnodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.hajournalingnodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @cmhafilernodes.sort_by{|n| n.name }.each do |node|
          export << I18n.t('.barclamp.clouderamanager.nodes.hafilernodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        headers["Content-Disposition"] = "attachment; filename=\"#{I18n.t('nodes.dell.nodes.filename', :default=>'cloudera_inventory.txt')}\""
        render :text => export.join("\n"), :content_type => 'application/text'
      }
    end
  end
end
