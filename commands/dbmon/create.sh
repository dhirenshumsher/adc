#!/bin/bash

function dbmon_create {
  apiCall -X POST -d "{ \
                      \"name\": \"\${i}\",\
                      \"username\": \"\${u}\",\
                      \"hostname\": \"\${h}\",\
                      \"agentName\": \"\${a}\",\
                      \"type\": \"\${t}\",\
                      \"orapkiSslEnabled\": false,\
                      \"orasslTruststoreLoc\": null,\
                      \"orasslTruststoreType\": null,\
                      \"orasslTruststorePassword\": null,\
                      \"orasslClientAuthEnabled\": false,\
                      \"orasslKeystoreLoc\": null,\
                      \"orasslKeystoreType\": null,\
                      \"orasslKeystorePassword\": null,\
                      \"databaseName\": \"\${n}\",\
                      \"port\": \"\${p}\",\
                      \"password\": \"\${s}\",\
                      \"excludedSchemas\": [],\
                      \"enabled\": true\
                    }" /controller/restui/databases/collectors/createConfiguration "$@"
}

register dbmon_create Create a new database collector
describe dbmon_create << EOF
Create a new database collector. You need to provide the following parameters:

  -i name
  -u user name
  -h host name
  -a agent name
  -t type
  -d database name
  -p port
  -s password
EOF
