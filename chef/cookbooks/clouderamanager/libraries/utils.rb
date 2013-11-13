#!/usr/bin/ruby
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

require 'time'

#######################################################################
# Convert a time string received from the API into a datetime object.
# This method is used internally for db date/time conversion with UTC. 
# The input timestamp is expected to be in ISO 8601 format with the "Z"
# sufix to express UTC.
# @param s: A time string received from the API (e.g "2012-02-18T01:01:03.234Z")
# @return: A datetime object.
#######################################################################
def api_time_to_datetime(s)
  return Time.iso8601(s)
end
