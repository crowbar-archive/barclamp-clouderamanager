# Copyright 2012, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#
class ClouderamanagerNavs < ActiveRecord::Migration
  def self.up
    Nav.find_or_create_by_item :item=>'clouderamanager_ug', :parent_item=>'help', :name=>'nav.cloueramanager_ug', :description=>'nav.cloueramanager_dg_description', :path=>'\'"/dell_cloudera_apache_hadoop_users_guide.pdf", { :link => { :target => "_blank" } }\'', :order=>500
    Nav.find_or_create_by_item :item=>'clouderamanager_dg', :parent_item=>'help', :name=>'nav.cloueramanager_dg', :description=>'nav.cloueramanager_dg_description', :path=>'\'"/dell_cloudera_apache_hadoop_deployment_guide.pdf", { :link => { :target => "_blank" } }\'', :order=>600
  end

  def self.down
    Nav.delete_by_item 'clouderamanager_ug'
    Nav.delete_by_item 'clouderamanager_dg'
  end
end
