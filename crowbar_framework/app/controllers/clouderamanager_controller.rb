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
  # nodes - render the nodes template.
  #######################################################################
  def nodes
    @hadoop_config = @service_object.get_hadoop_config
    
    respond_to do |format|
      format.html { render :template => 'barclamp/hadoop_infrastructure/nodes' }
      format.text {
        export = ["role, ip, name, cpu, ram, drives"]
        @hadoop_config[:adminnodes].each do |node|
          export << I18n.t('.barclamp.hadoop_infrastructure.nodes.adminnodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @hadoop_config[:servernodes].each do |node|
          export << I18n.t('.barclamp.hadoop_infrastructure.nodes.servernodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @hadoop_config[:namenodes].each do |node|
          export << I18n.t('.barclamp.hadoop_infrastructure.nodes.namenodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @hadoop_config[:edgenodes].each do |node|
          export << I18n.t('.barclamp.hadoop_infrastructure.nodes.edgenodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @hadoop_config[:datanodes].each do |node|
          export << I18n.t('.barclamp.hadoop_infrastructure.nodes.datanodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @hadoop_config[:hajournalingnodes].each do |node|
          export << I18n.t('.barclamp.hadoop_infrastructure.nodes.hajournalingnodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        @hadoop_config[:hafilernodes].each do |node|
          export << I18n.t('.barclamp.hadoop_infrastructure.nodes.hafilernodes') + ", #{node.ip}, #{node.name}, #{node.cpu}, #{node.memory}, #{node.number_of_drives}"
        end
        headers["Content-Disposition"] = "attachment; filename=\"#{I18n.t('nodes.dell.nodes.filename', :default=>'hadoop_infrastructure_inventory.txt')}\""
        render :text => export.join("\n"), :content_type => 'application/text'
      }
    end
  end
end
