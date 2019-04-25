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
LDAPTYPE="AD"

# Miscellaneous output-engine
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
      printf "\t-l <LDAP_QUERY_HOST>  \n"
      printf "\t-t <LDAP_TYPE>  \n"
      printf "\t-u <DIRECTORY_USER> \n"
      echo "  GNU long options:"
      printf "\t--domain-name <LONG_DOMAIN_NAME>  \n"
      printf "\t--help # print this message  \n"
      printf "\t--hostname <FORCED_HOSTNAME>  \n"
      printf "\t--join-crypt <ENCRYPTED_PASSWORD>  \n"
      printf "\t--join-key <DECRYPTION_KEY>  \n"
      printf "\t--join-user <DIRECTORY_USER> \n"
      printf "\t--ldap-host <LDAP_QUERY_HOST>  \n"
      printf "\t--ldap-type <LDAP_TYPE> \n"
   ) >&2
   exit 1
}

# Find domain controllers to talk to
function FindDCs {
   local DNS_SEARCH_STRING
   local IDX
   local SEARCH_LIST

   DNS_SEARCH_STRING="_ldap._tcp.dc._msdcs.${1}"
   IDX=0
   SEARCH_LIST=($( dig -t SRV "${DNS_SEARCH_STRING}" | awk '/IN SRV/{ printf("%s;%s\n",$7,$8)}' ))

   # Parse list of domain-controllers to see who we can connect to
   for DC in "${SEARCH_LIST[@]}"
   do
      timeout 1 bash -c "echo > /dev/tcp/${DC//*;/}/${DC//;*/}" &&
        break
      IDX=$(( ${IDX} + 1 ))
   done

   case "${DC//;*/}" in
      389)
        logIt "Contact ${DC//*;/} on port ${DC[${IDX}]//;*/}" 0
         ;;
      636)
        logIt "Contact ${DC//*;/} on port ${DC[${IDX}]//;*/}" 0
         ;;
      *)
        logIt "${DC//*;/} listening on unrecognized port [${DC[${IDX}]//;*/}]" 1
         ;;
   esac

   # Return info
   echo "${DC[${IDX}]}"
}


#######################
## Main Program Flow ##
#######################

# Ensure parseable arguments have been passed
if [[ $# -eq 0 ]]
then
   logIt "No arguments given. Aborting" 1
fi

# Define flags to look for..
OPTIONBUFR=$(getopt -o c:d:f:hk:l:u:t: --long domain-name:,help,hostname:,join-user:,join-crypt:,join-key:,ldap-host:,ldap-type: -n "${PROGNAME}" -- "$@")
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
      -l|--ldap-host)
         case "$2" in
            "")
               logIt "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            *)
               LDAPHOST="${2}"
               shift 2;
               ;;
         esac
         ;;
      -t|--ldap-type)
         case "$2" in
            "")
               logIt "Error: option required but not specified" 1
               shift 2;
               exit 1
               ;;
            ad|AD)
               LDAPTYPE="AD"
               shift 2;
               ;;
            *)
               logIt "Error: unsupported directory-type" 1
               shift 2;
               exit 1
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

# Search for Domain Controllers
if [[ -z ${LDAPHOST+x} ]]
then
   DCINFO="$( FindDCs "${DOMAINNAME}" )"
else
   DCINFO="389;${LDAPHOST}"
fi

# Set directory-user value as appropriate
if [[ ${LDAPTYPE} == AD ]]
then
   QUERYUSER="${DIRUSER}@${DOMAINNAME}"
else
   QUERYUSER="${DIRUSER}"
fi


# Perform search
ldapsearch -LLL -x -h "${DCINFO//*;/}" -p "${DCINFO//;*/}" -D "${QUERYUSER}" \
  -w "{BINDPASS}" -b "${SEARCHSCOPE}" -s sub cn="${HOSTNAME}" cn
