maintainer       "Dell, Inc."
maintainer_email "Paul_Webster@Dell.com"
license          "Apache 2.0 License, Copyright (c) 2011 Dell Inc. - http://www.apache.org/licenses/LICENSE-2.0"
description      "Provides end-to-end management for Apache Hadoop CDH4 with the ability to deploy and centrally operate a complete Hadoop stack. Gives you a cluster wide, real time view of nodes and services running and provides a single central place to enact configuration changes across your cluster. Cloudera Manager incorporates a full range of reporting and diagnostic tools to help you optimize cluster performance and utilization."
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "1.0"
recipe           "clouderamanager::cm-agent", "Installs the Cloudera Manager agent component."
recipe           "clouderamanager::cm-common", "Installs Cloudera Manager common components."
recipe           "clouderamanager::cm-server", "Installs the Cloudera Manager server packages."
recipe           "clouderamanager::hadoop-setup", "Configure Hadoop specfic setup parameters."
recipe           "clouderamanager::mysql", "Installs the MySQL server for the Cloudera Manager metadata store."
recipe           "clouderamanager::postgresql", "Installs the PostgreSQL server for the Cloudera Manager metadata store."
recipe           "clouderamanager::node-setup", "Configure cluster node setup parameters."

