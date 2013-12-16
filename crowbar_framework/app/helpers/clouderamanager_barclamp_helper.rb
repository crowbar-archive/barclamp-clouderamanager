# Copyright 2011-2013, Dell
# Copyright 2013, SUSE LINUX Products GmbH
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
# Author: Dell Crowbar Team
# Author: SUSE LINUX Products GmbH
#

module ClouderamanagerBarclampHelper
  def clouderamanager_role_contraints
    {
      "clouderamanager-cb-adminnode" => {
        "unique" => false,
        "count" => 1,
        "admin" => true
      },
      "clouderamanager-server" => {
        "unique" => false,
        "count" => -1
      },
      "clouderamanager-namenode" => {
        "unique" => false,
        "count" => -1
      },
      "clouderamanager-datanode" => {
        "unique" => false,
        "count" => -1
      },
      "clouderamanager-edgenode" => {
        "unique" => false,
        "count" => -1
      },
      "clouderamanager-ha-journalingnode" => {
        "unique" => false,
        "count" => -1
      },
      "clouderamanager-ha-filernode" => {
        "unique" => false,
        "count" => -1
      }
    }
  end

  def deployments_for_clouderamanager(selected)
    options_for_select(
      [
        ["manual", "manual"],
        ["auto", "auto"]
      ],
      selected.to_s
    )
  end

  def databases_for_clouderamanager(selected)
    options_for_select(
      [
        ["postgresql","postgresql"],
        ["mysql", "mysql"]
      ],
      selected.to_s
    )
  end
end
