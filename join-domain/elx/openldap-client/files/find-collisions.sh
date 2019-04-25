#!/bin/bash
# shellcheck disable=
#
# Script to locate collisions within an LDAP directory service
#
######################################################################
PROGNAME="$( basename "${0}" )"
PROGDIR="$( dirname "${0}" )"
LOGFACIL="user.err"
DEBUGVAL="${DEBUG:-false}"

function logIt {
   # Spit out message to calling-shell if debug-mode enabled
   if [[ ${DEBUGVAL} == true ]]
   then
      echo "${1}"
   fi

   # Send to syslog if passed message-code is non-zero
   if [[ ! -z ${2} ]] && [[ ${2} -gt 0 ]]
   then
      logger -st "${PROGNAME}" -p ${LOGFACIL} "${1}"
      exit ${2}
   fi
}

# Print out a basic usage message
function UsageMsg {
   (
      if [[ ! -z ${MISSINGARGS+x} ]]
      then
         printf "Failed to pass one or more mandatory arguments\n\n"
      fi
      echo "Usage: ${0} [GNU long option] [option] ..."
      echo "  Options:"
      printf "\t-c <ENCRYPTED_PASSWORD>  \n"
      printf "\t-d <LONG_DOMAIN_NAME>  \n"
      printf "\t-f <FORCED_HOSTNAME>  \n"
      printf "\t-h # print this message  \n"
      printf "\t-k <DECRYPTION_KEY>  \n"
      printf "\t-u <DIRECTORY_USER> \n"
      echo "  GNU long options:"
      printf "\t--domain-name <LONG_DOMAIN_NAME>  \n"
      printf "\t--help # print this message  \n"
      printf "\t--hostname <FORCED_HOSTNAME>  \n"
      printf "\t--join-crypt <ENCRYPTED_PASSWORD>  \n"
      printf "\t--join-key  <DECRYPTION_KEY>  \n"
      printf "\t--join-user  <DIRECTORY_USER> \n"
   ) >&2
   exit 1
}


if [[ $# -eq 0 ]]
then
   logIt "No arguments given. Aborting" 1
fi
# Define flags to look for..
OPTIONBUFR=$(getopt -o c:d:f:hk:u: --long domain-name:,help,hostname:,join-user:,join-crypt:,join-key: -n "${PROGNAME}" -- "$@")
eval set -- "${OPTIONBUFR}"

###################################
# Parse contents of ${OPTIONBUFR}
###################################
while true
do
   case "$1" in
      -c|--join-crypt)
         case "$2" in
            "")
               logIt "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            *)
               CRYPTSTRING="${2}"
               shift 2;
               ;;
         esac
         ;;
      -d|--domain-name)
         case "$2" in
            "")
               logIt "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            *)
               DOMAINNAME="${2}"
               shift 2;
               ;;
         esac
         ;;
      -f|--hostname)
         case "$2" in
            "")
               logIt "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            *)
               HOSTNAME="${2}"
               shift 2;
               ;;
         esac
         ;;
      -h|--help)
         UsageMsg
         ;;
      -k|--join-key)
         case "$2" in
            "")
               logIt "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            *)
               CRYPTKEY="${2}"
               shift 2;
               ;;
         esac
         ;;
      -u|--join-user)
         case "$2" in
            "")
               logIt "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            *)
               DIRUSER="${2}"
               shift 2;
               ;;
         esac
         ;;
      --)
         shift
         break
         ;;
      *)
         logIt "Missing value" 1
         exit 1
         ;;
   esac
done

# Check that mandatory options have been passed
if [[ -z  ${DOMAINNAME+x} ]] ||
   [[ -z  ${DIRUSER+x} ]] ||
   [[ -z  ${CRYPTSTRING+x} ]] ||
   [[ -z  ${CRYPTKEY+x} ]]
then
   MISSINGARGS=true
   UsageMsg
fi
