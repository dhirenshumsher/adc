#!/bin/bash
ADC_VERSION="vx.y.z"
ADC_LAST_COMMIT="xxxxxxxxxx"
USER_CONFIG="$HOME/.appdynamics/adc/config.sh"
GLOBAL_CONFIG="/etc/appdynamics/adc/config.sh"

CONFIG_CONTROLLER_COOKIE_LOCATION="/tmp/appdynamics-controller-cookie.txt"
CONFIG_PORTAL_COOKIE_LOCATION="/tmp/appdynamics-portal-cookie.txt"

# Configure default output verbosity. May contain a combination of the following strings:
# - debug
# - error
# - warn
# - info
# - output (msg to stdout)
# An empty string silents all output
CONFIG_OUTPUT_VERBOSITY="error,output"

# Default Colors
COLOR_WARNING="\033[0;33m"
COLOR_INFO="\033[0;32m"
COLOR_ERROR="\033[0;31m"
COLOR_DEBUG="\033[0;35m"
COLOR_RESET="\033[0m"

GLOBAL_COMMANDS=""
GLOBAL_HELP=""
GLOBAL_LONG_HELP_COUNTER=0
declare -a GLOBAL_LONG_HELP_STRINGS
declare -a GLOBAL_LONG_HELP_COMMANDS
SCRIPTNAME=$(basename "$0")

VERBOSITY_COUNTER=0
declare -i VERBOSITY_COUNTER

# register namespace_command help
function register {
  GLOBAL_COMMANDS="$GLOBAL_COMMANDS $1"
  GLOBAL_HELP="$GLOBAL_HELP\n$*"
}

function describe {
  GLOBAL_LONG_HELP_COMMANDS[${#GLOBAL_LONG_HELP_COMMANDS[@]}]="$1"
  GLOBAL_LONG_HELP_STRINGS[${#GLOBAL_LONG_HELP_STRINGS[@]}]=$(cat)
}

source ./helpers/output.sh
source ./helpers/httpClient.sh
source ./helpers/shiftOptInd.sh
source ./helpers/urlencode.sh
source ./helpers/recursiveSource.sh
source ./helpers/apiCall.sh

source ./commands/config.sh
source ./commands/help.sh
source ./commands/version.sh

source ./commands/controller/login.sh
source ./commands/controller/call.sh
source ./commands/controller/ping.sh
source ./commands/controller/status.sh
source ./commands/controller/version.sh
source ./commands/controller/isup.sh

source ./commands/portal/login.sh
source ./commands/portal/download.sh

source ./commands/application/list.sh
source ./commands/application/create.sh
source ./commands/application/delete.sh
source ./commands/application/export.sh

source ./commands/bt/list.sh

source ./commands/tier/list.sh
source ./commands/tier/get.sh
source ./commands/tier/nodes.sh

source ./commands/metric/list.sh
source ./commands/metric/get.sh
source ./commands/metric/tree.sh

source ./commands/dbmon/create.sh
source ./commands/dbmon/get.sh
source ./commands/dbmon/list.sh
source ./commands/dbmon/delete.sh

source ./commands/event/create.sh
source ./commands/event/list.sh

source ./commands/timerange/create.sh
source ./commands/timerange/list.sh
source ./commands/timerange/delete.sh

source ./commands/dashboard/list.sh
source ./commands/dashboard/export.sh
source ./commands/dashboard/import.sh
source ./commands/dashboard/delete.sh
source ./commands/dashboard/update.sh

source ./commands/federation/createkey.sh
source ./commands/federation/establish.sh
source ./commands/federation/setup.sh


if [ -f "${GLOBAL_CONFIG}" ]; then
  debug "Sourcing global config from ${GLOBAL_CONFIG} "
  . ${GLOBAL_CONFIG}
else
  warning "File ${GLOBAL_CONFIG} not found!"
fi


if [ -f "${USER_CONFIG}" ]; then
  debug "Sourcing user config from ${USER_CONFIG} "
  . ${USER_CONFIG}
else
  warning "File ${USER_CONFIG} not found!"
fi

# Parse global options
while getopts "A:H:C:J:D:P:S:F:Nv" opt;
do
  case "${opt}" in
    H)
      CONFIG_CONTROLLER_HOST=${OPTARG}
      debug "Set CONFIG_CONTROLLER_HOST=${CONFIG_CONTROLLER_HOST}"
    ;;
    C)
      CONFIG_CONTROLLER_CREDENTIALS=${OPTARG}
      debug "Set CONFIG_CONTROLLER_CREDENTIALS=${CONFIG_CONTROLLER_CREDENTIALS}"
    ;;
    J)
      CONFIG_CONTROLLER_COOKIE_LOCATION=${OPTARG}
      debug "Set CONFIG_CONTROLLER_COOKIE_LOCATION=${CONFIG_CONTROLLER_COOKIE_LOCATION}"
    ;;
    D)
      CONFIG_OUTPUT_VERBOSITY=${OPTARG}
      debug "Set CONFIG_OUTPUT_VERBOSITY=${CONFIG_OUTPUT_VERBOSITY}"
    ;;
    A)
      CONFIG_CONTROLLER_DEFAULT_APPLICATION=${OPTARG}
      debug "Set CONFIG_CONTROLLER_DEFAULT_APPLICATION=${CONFIG_CONTROLLER_DEFAULT_APPLICATION}"
    ;;
    P)
      CONFIG_USER_PLUGIN_DIRECTORY=${OPTARG}
      debug "Set CONFIG_USER_PLUGIN_DIRECTORY=${CONFIG_USER_PLUGIN_DIRECTORY}"
    ;;
    S)
      CONFIG_PORTAL_CREDENTIALS=${OPTARG}
      debug "Set CONFIG_PORTAL_CREDENTIALS=${CONFIG_PORTAL_CREDENTIALS}"
    ;;
    N)
      COLOR_WARNING=""
      COLOR_INFO=""
      COLOR_ERROR=""
      COLOR_DEBUG=""
      COLOR_RESET=""
    ;;
    F)
      CONTROLLER_INFO_XML=${OPTARG}
      debug "Reading CONFIG_CONTROLLER_HOST from $CONTROLLER_INFO_XML"
      CONTROLLER_INFO_XML_HOST="$(sed -n -e "s/<controller-host>\(.*\)<\/controller-host>/\1/p" $CONTROLLER_INFO_XML)"
      CONTROLLER_INFO_XML_PORT="$(sed -n -e "s/<controller-port>\(.*\)<\/controller-port>/\1/p" $CONTROLLER_INFO_XML)"
      CONTROLLER_INFO_XML_SSL_ENABLED="$(sed -n -e "s/<controller-ssl-enabled>\(.*\)<\/controller-ssl-enabled>/\1/p" $CONTROLLER_INFO_XML)"
      [[ ${CONTROLLER_INFO_XML_SSL_ENABLED// /} == "true" ]] && CONTROLLER_INFO_XML_SCHEMA=https || CONTROLLER_INFO_XML_SCHEMA=http
      CONFIG_CONTROLLER_HOST=${CONTROLLER_INFO_XML_SCHEMA}://${CONTROLLER_INFO_XML_HOST// /}:${CONTROLLER_INFO_XML_PORT// /}
      debug "Set CONFIG_CONTROLLER_HOST=${CONFIG_CONTROLLER_HOST}"
    ;;
    v)
      case $VERBOSITY_COUNTER in
        0)
        CONFIG_OUTPUT_VERBOSITY="${CONFIG_OUTPUT_VERBOSITY},warn"
        ;;
        1)
        CONFIG_OUTPUT_VERBOSITY="${CONFIG_OUTPUT_VERBOSITY},info"
        ;;
        2)
        CONFIG_OUTPUT_VERBOSITY="${CONFIG_OUTPUT_VERBOSITY},debug"
        ;;
      esac
      VERBOSITY_COUNTER=${VERBOSITY_COUNTER}+1
    ;;
  esac
done

shiftOptInd
shift $SHIFTS

debug "CONFIG_CONTROLLER_HOST=$CONFIG_CONTROLLER_HOST"
debug "CONFIG_CONTROLLER_CREDENTIALS=$CONFIG_CONTROLLER_CREDENTIALS"
debug "CONFIG_CONTROLLER_COOKIE_LOCATION=$CONFIG_CONTROLLER_COOKIE_LOCATION"
debug "CONFIG_OUTPUT_VERBOSITY=$CONFIG_OUTPUT_VERBOSITY"
debug "CONFIG_USER_PLUGIN_DIRECTORY=$CONFIG_USER_PLUGIN_DIRECTORY"

recursiveSource "${CONFIG_USER_PLUGIN_DIRECTORY}"

NAMESPACE=$1

COMMAND_RESULT=""

# Check if the namespace is used
if [ "${GLOBAL_COMMANDS/${NAMESPACE}_}" != "$GLOBAL_COMMANDS" ] ; then
  debug "${NAMESPACE} has commands"
  COMMAND=$2
  if [ "$COMMAND" == "" ] || [ "$COMMAND" == "help" ]; then
    debug "Will display help for $NAMESPACE"
    _help ${NAMESPACE}
  elif [ "${GLOBAL_COMMANDS/${NAMESPACE}_${COMMAND}}" != "$GLOBAL_COMMANDS" ] ; then
    debug "${NAMESPACE}_${COMMAND} is a valid command"
    shift 2
    ${NAMESPACE}_${COMMAND} "$@"
  else
    COMMAND_RESULT="Unknown command: $*"
  fi
  # Check if this is a global command
elif [ "${GLOBAL_COMMANDS/_${NAMESPACE}}" != "$GLOBAL_COMMANDS" ] ; then
  debug "_${NAMESPACE} found as global command"
  shift 1
  _${NAMESPACE} "$@"
else
  COMMAND_RESULT="Unknown command: $*"
fi

echo -e "$COMMAND_RESULT"

debug END
