#!/bin/bash
# shellcheck disable=SC2236,SC2207
#
# set -euo pipefail
#
# Script to locate collisions within an LDAP directory service
#
######################################################################
PROGNAME="$( basename "${0}" )"
LOGFACIL="user.err"
DEBUGVAL="${DEBUG:-false}"
LDAPTYPE="AD"
DOEXIT="0"

# Function-abort hooks
trap "exit 1" TERM
export TOP_PID=$$

# Need to ignore value set in parent shell because that value is set
# before any wam-initiated renames complete
HOSTNAME=$( uname -n )

# Miscellaneous output-engine
function logIt {
  local LOGSTR
  local ERREXT

  LOGSTR="${1}"
  ERREXT="${2:-}"

  # Spit out message to calling-shell if debug-mode enabled
  if [[ ${DEBUGVAL} == true ]]
  then
      echo "${LOGSTR}" >&2
  fi

  # Send to syslog if passed message-code is non-zero
  if [[ ! -z ${ERREXT} ]] && [[ ${ERREXT} -gt 0 ]]
  then
      logger -st "${PROGNAME}" -p ${LOGFACIL} "${LOGSTR}"
      exit "${ERREXT}"
  fi
}

# Stateful output messaging for Saltstack
function saltOut {
  if [[ ${OUTPUT} == SALTMODE ]]
  then
      case "${2}" in
        no)
            printf "\n"
            printf "changed=no comment='%s'\n" "${1}"
            ;;
        yes)
            printf "\n"
            printf "changed=yes comment='%s'\n" "${1}"
            ;;
      esac
  fi
}

# Print out a basic usage message
function UsageMsg {
  (
      # Special cases
      if [[ ! -z ${MISSINGARGS+x} ]]
      then
        printf "Failed to pass one or more mandatory arguments\n\n"
      elif [[ ! -z ${EXCLUSIVEARGS+x} ]]
      then
        printf "Passed two or more exclusive arguments\n\n"
      fi

      echo "Usage: ${0} [GNU long option] [option] ..."
      echo "  Options:"
      printf "\t-a <AD_SITENAME> \n"
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
      printf "\t--ad-site <AD_SITENAME> \n"
  ) >&2
  exit 1
}

# Verify tool-dependencies
function VerifyDependencies {
  local CHKRPMS
  local RPM

  # RPMs to check for
  CHKRPMS=(
        bind-utils
        openldap-clients
      )

  for RPM in "${CHKRPMS[@]}"
  do
      printf "Is dependency on %s satisfied? " "${RPM}"
      if [[ $( rpm --quiet -q "${RPM}" )$? -eq 0 ]]
      then
        echo "Yes"
      else
        ( echo "No. Aborting..." ; kill -s TERM " ${TOP_PID}" )
      fi
  done
}

# Decrypt Join Password
function PWdecrypt {
  local PWCLEAR
  PWCLEAR=$(echo "${CRYPTSTRING}" | openssl enc -aes-256-cbc -md sha256 -a -d \
            -salt -pass pass:"${CRYPTKEY}")

  # shellcheck disable=SC2181
  if [[ $? -ne 0 ]]
  then
    echo "FAILURE"
  else
    echo "${PWCLEAR}"
  fi
}

# Find domain controllers to talk to
function FindDCs {
  local DNS_SEARCH_STRING
  local IDX
  local DC

  # Select whether to try to use AD
  if [[ ! -z ${ADSITE} ]]
  then
      DNS_SEARCH_STRING="_ldap._tcp.${ADSITE}._sites.dc._msdcs.${1}"
  else
      DNS_SEARCH_STRING="_ldap._tcp.dc._msdcs.${1}"
  fi

  export DNS_SEARCH_STRING

  IDX=0
  DC=($(
        dig -t SRV "${DNS_SEARCH_STRING}" | sed -e '/^$/d' -e '/;/d' | \
        awk '/[ 	]*IN[ 	]*SRV[ 	]*/{ printf("%s;%s\n",$7,$8)}'
      ))

  # Parse list of domain-controllers to see who we can connect to
  if [[ ${#DC} -ne 0 ]]
  then
      for CTLR in "${DC[@]}"
      do
        DC[${IDX}]="${CTLR}"
        timeout 1 bash -c "echo > /dev/tcp/${CTLR//*;/}/${CTLR//;*/}" &&
          break
        IDX=$(( IDX + 1 ))
      done

      case "${DC[${IDX}]//;*/}" in
        389)
          logIt "Contact ${DC[${IDX}]//*;/} on port ${DC[${IDX}]//;*/}" 0
            ;;
        636)
          logIt "Contact ${DC[${IDX}]//*;/} on port ${DC[${IDX}]//;*/}" 0
            ;;
        *)
          logIt "${DC[${IDX}]//*;/} listening on unrecognized port [${DC[${IDX}]//;*/}]" 1
            ;;
      esac

      # Return info
      echo "${DC[${IDX}]}"
  else
      # Return error
      echo "DC_NOT_FOUND"
  fi

}

# Find computer's DN
function FindComputer {
  local COMPUTERNAME
  local SEARCHEXIT
  local SEARCHTERM
  local SHORTHOST

  # AD-hosted objects will always be shortnames
  SHORTHOST=${HOSTNAME//.*/}

  # Need to ensure we look for literal, all-cap and all-lower
  SEARCHTERM="(&(objectCategory=computer)(|(cn=${SHORTHOST})(cn=${SHORTHOST^^})(cn=${SHORTHOST,,})))"
  export SEARCHTERM

  # Searach without STARTLS
  COMPUTERNAME=$( ldapsearch -o ldif-wrap=no -LLL -x -h "${DCINFO//*;/}" \
        -p "${DCINFO//;*/}" -D "${QUERYUSER}" -w "${BINDPASS}" \
        -b "${SEARCHSCOPE}" -s sub "${SEARCHTERM}" dn 2> /dev/null || \
      ldapsearch -o ldif-wrap=no -LLL -Z -x -h "${DCINFO//*;/}" -p \
        "${DCINFO//;*/}" -D "${QUERYUSER}" -w "${BINDPASS}" \
        -b "${SEARCHSCOPE}" -s sub \
        "${SEARCHTERM}" dn 2> /dev/null
  )

  COMPUTERNAME=$( echo "${COMPUTERNAME}" | \
        sed -e 's/^.*dn: *//' -e '/^$/d' -e '/#/d' )

  # Output based on exit status and/or what's found
  if [[ -z ${COMPUTERNAME} ]]
  then
      echo "NOTFOUND"
  else
      echo "${COMPUTERNAME}"
  fi
}

# Nuke computer's DN
function NukeObject {
  local SEARCHEXIT
  local LDAPOBJECT

  LDAPOBJECT="${1}"

  ldapdelete -x -h "${DCINFO//*;/}" -p "${DCINFO//;*/}" -D "${QUERYUSER}" \
    -w "${BINDPASS}" "${LDAPOBJECT}" 2> /dev/null || \
  ldapdelete -Z -x -h "${DCINFO//*;/}" -p "${DCINFO//;*/}" -D "${QUERYUSER}" \
    -w "${BINDPASS}" "${LDAPOBJECT}" 2> /dev/null

  SEARCHEXIT="$?"

  if [[ ${SEARCHEXIT} -eq 0 ]]
  then
      logIt "Delete of ${LDAPOBJECT} succeeded" 0
      saltOut "Delete of computer-object [${HOSTNAME}] succeeded" yes
  else
      logIt "Delete of ${LDAPOBJECT} failed" 0
      saltOut "Delete of computer-object [${HOSTNAME}] failed" no
  fi
}



#######################
## Main Program Flow ##
#######################

# Ensure parseable arguments have been passed
if [[ $# -eq 0 ]]
then
  logIt "No arguments given. Aborting" 1
fi

# Define flags to look for...
OPTIONBUFR=$(getopt -o c:d:f:hk:l:p:s:t:u: --long domain-name:,help,hostname:,join-crypt:,join-key:,join-password:,join-user:,ldap-host:,ldap-type:,mode:,ad-site: -n "${PROGNAME}" -- "$@")

# Check for mutually-exclusive arguments
if [[ ${OPTIONBUFR} =~ p\ |join-password && ${OPTIONBUFR} =~ c\ |join-crypt ]] ||
  [[ ${OPTIONBUFR} =~ p\ |join-password && ${OPTIONBUFR} =~ c\ |join-key ]]
then
  EXCLUSIVEARGS=TRUE
  UsageMsg
fi


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
              BINDPASS="TOBESET"
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
              BINDPASS="TOBESET"
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
      --mode)
        case "$2" in
            "")
              logIt "Error: option required but not specified" 1
              shift 2;
              exit 1
              ;;
            cleanup)
              CLEANUP=TRUE
              OUTPUT=INTERACTIVE
              shift 2;
              ;;
            saltstack)
              CLEANUP=TRUE
              OUTPUT=SALTMODE
              shift 2;
              ;;
            *)
              CLEANUP=FALSE
              OUTPUT=INTERACTIVE
              shift 2;
              ;;
        esac
        ;;
      -p|--join-password)
        case "$2" in
            "")
              logIt "Error: option required but not specified" 1
              shift 2;
              exit 1
              ;;
            *)
              BINDPASS="${2}"
              shift 2;
              ;;
        esac
        ;;
      -s|--ad-site)
        case "$2" in
            "")
              logIt "Error: option required but not specified" 1
              shift 2;
              exit 1
              ;;
            *)
              ADSITE="${2}"
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
  [[ -z  ${BINDPASS+x} ]]
then
  MISSINGARGS=true
  UsageMsg
fi

# Ensure dependencies are met
VerifyDependencies

# Decrypt our query password (as necessary)
if [[ ${BINDPASS} == TOBESET ]]
then
  BINDPASS="$(PWdecrypt)"
  export BINDPASS

  # Bail if needed decrypt failed
  if [[ ${BINDPASS} == FAILURE ]]
  then
      logIt "Failed decrypting password"
      saltOut "Failed decrypting password" no
      exit
  fi
fi


# Search for Domain Controllers
if [[ -z ${LDAPHOST+x} ]]
then
  DCINFO="$( FindDCs "${DOMAINNAME}" )"
else
  DCINFO="389;${LDAPHOST}"
fi
export DCINFO

# Set directory-user value as appropriate
if [[ ${LDAPTYPE} == AD ]]
then
  QUERYUSER="${DIRUSER}@${DOMAINNAME}"
else
  QUERYUSER="${DIRUSER}"
fi
export QUERYUSER

# Convert domain to a search scope
SEARCHSCOPE="$( printf "DC=%s" "${DOMAINNAME//./,DC=}" )"
export SEARCHSCOPE

# Do search
if [[ ${DCINFO} = DC_NOT_FOUND ]]
then
  OBJECTDN="${DCINFO}"
else
  OBJECTDN=$(FindComputer)
fi

case "${OBJECTDN}" in
  DC_NOT_FOUND)
      logIt "Could not find domain-controller to query for ${HOSTNAME}" "${DOEXIT}"
      saltOut "Could not find domain-controller to query for ${HOSTNAME}" no
      logIt "Skipping any requested cleanup attempts"
      CLEANUP="FALSE"
      ;;
  NOTFOUND)
      if [[ ${OUTPUT} != SALTMODE ]]
      then
        DOEXIT=1
      fi
      logIt "Could not find ${HOSTNAME} in ${SEARCHSCOPE}" "${DOEXIT}"
      saltOut "Could not find computer-object [${HOSTNAME}] in directory" no
      logIt "Skipping any requested cleanup attempts"
      CLEANUP="FALSE"
      ;;
  QUERYFAILURE)
      if [[ ${OUTPUT} != SALTMODE ]]
      then
        DOEXIT=1
      fi
      logIt "Query failure when looking for ${HOSTNAME} in ${SEARCHSCOPE}" "${DOEXIT}"
      saltOut "Query failure when looking for computer-object [${HOSTNAME}] in directory" no
      logIt "Skipping any requested cleanup attempts"
      CLEANUP="FALSE"
      ;;
  *)
      logIt "Found ${OBJECTDN}"
      ;;
esac

# Whether to try to NUKE
if [[ ${CLEANUP} == TRUE ]]
then
  NukeObject "${OBJECTDN}"
fi
