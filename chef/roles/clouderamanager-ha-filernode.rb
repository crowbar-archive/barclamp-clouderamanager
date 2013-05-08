#
# Cookbook: clouderamanager
# Role: clouderamanager-ha-filernode.rb
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

name "clouderamanager-ha-filernode"
description "Cloudera Manager High Availability Filer Role"
run_list(
  "recipe[clouderamanager::node-setup]",
  "recipe[clouderamanager::hadoop-setup]",
  "recipe[clouderamanager::cm-ha-filer-export]"
)
default_attributes()
override_attributes()
