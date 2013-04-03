#
# Cookbook: clouderamanager
# Role: clouderamanager-server.rb
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

name "clouderamanager-server"
description "Cloudera Manager Server Role"
run_list(
  "recipe[clouderamanager::default]",
  "recipe[clouderamanager::cm-server]",
  "recipe[clouderamanager::cm-api]"
)
default_attributes()
override_attributes()
