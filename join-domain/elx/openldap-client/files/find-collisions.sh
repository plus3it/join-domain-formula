#!/bin/bash
#
set -euo pipefail
#
# Script to locate collisions within an LDAP directory service
#
######################################################################
PROGNAME="$( basename "${0}" )"
BINDPASS="${CLEARPASS:-}"
CRYPTKEY="${CRYPTKEY:-}"
CRYPTSTRING="${CRYPTSTRING:-}"
DEBUG="${DEBUG:-false}"
DIR_DOMAIN="${JOIN_DOMAIN:-}"
DIRUSER="${JOIN_USER:-}"
DOMAINNAME="${JOIN_DOMAIN:-}"
DS_LIST=()
LDAPPASSWD=""
LDAPTYPE="AD"
LOGFACIL="user.err"
REQ_TLS="${REQ_TLS:-true}"

# Make interactive-execution more-verbose unless explicitly told not to
if [[ $( tty -s ) -eq 0 ]] && [[ ${DEBUG} == "UNDEF" ]]
then
   DEBUG="true"
fi

# Error handler function
function err_exit {
   local ERRSTR
   local ISNUM
   local SCRIPTEXIT

   ERRSTR="${1}"
   ISNUM='^[0-9]+$'
   SCRIPTEXIT="${2:-1}"

   if [[ ${DEBUG} == true ]]
   then
      # Our output channels
      logger -i -t "${PROGNAME}" -p kern.crit -s -- "${ERRSTR}"
   else
      logger -i -t "${PROGNAME}" -p kern.crit -- "${ERRSTR}"
   fi

   # Only exit if requested exit is numerical
   if [[ ${SCRIPTEXIT} =~ ${ISNUM} ]]
   then
      return "${SCRIPTEXIT}"
   fi
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
      err_exit "Checking if dependency on ${RPM} is satisfied... " 0
      if [[ $( rpm --quiet -q "${RPM}" )$? -eq 0 ]]
      then
        err_exit "Dependency on ${RPM} *is* satisfied" 0
      else
        err_exit "Dependency on ${RPM} *not* satisfied" 1
      fi
  done
}

# Get Candidate DCs
function CandidateDirServ {
  local DNS_SEARCH_STRING

  # Select whether to try to use AD "sites"
  if [[ -n ${ADSITE:-} ]]
  then
    DNS_SEARCH_STRING="_ldap._tcp.${ADSITE}._sites.dc._msdcs.${DIR_DOMAIN}"
  else
    DNS_SEARCH_STRING="_ldap._tcp.dc._msdcs.${DIR_DOMAIN}"
  fi

  # Populate global directory-server array
  mapfile -t DS_LIST < <(
    dig -t SRV "${DNS_SEARCH_STRING}" | \
    sed -e '/^$/d' -e '/;/d' | \
    awk '/\s\s*IN\s\s*SRV\s\s*/{ printf("%s;%s\n",$7,$8) }' | \
    sed -e 's/\.$//'
  )

  if [[ ${#DS_LIST[@]} -eq 0 ]]
  then
    err_exit "Unable to generate a list of candidate servers" 1
    return 1
  else
    err_exit "Found ${#DS_LIST[@]} candidate directory-servers" 0
    return 0
  fi
}

# Make sure directory-server ports are open
function PingDirServ {
  local    DIR_SERV
  local    DS_NAME
  local    DS_PORT
  local -a GOOD_DS_LIST


  for DIR_SERV in "${DS_LIST[@]}"
  do
    DS_NAME="${DIR_SERV//*;/}"
    DS_PORT="${DIR_SERV//;*/}"

    if [[ $(
        timeout 1 bash -c "echo > /dev/tcp/${DS_NAME}/${DS_PORT}"
      ) -eq 0 ]]
    then
      GOOD_DS_LIST+=("${DIR_SERV}")
      err_exit "${DIR_SERV//*;} responds to port-ping" 0
    fi
  done

  if [[ ${#GOOD_DS_LIST[@]} -gt 0 ]]
  then
    # Overwrite global directory-server array with successfully-pinged
    # servers' info
    DS_LIST=("${GOOD_DS_LIST[@]}")
    err_exit "Found ${#DS_LIST[@]} port-pingable directory servers" 0
    return 0
  else
    err_exit "All candidate servers failed port-ping" 1
    return 1
  fi
}

# Decrypt password to use for LDAP queries
function PWdecrypt {
  local PWCLEAR

  # Bail if either of crypt-string or decrpytion-key are null
  if [[ -z ${CRYPTSTRING} ]] || [[ -z ${CRYPTKEY} ]]
  then
    logIt "Missing keystring-decryption values" 1
  fi

  # Lets decrypt!
  if PWCLEAR=$(
    echo "${CRYPTSTRING}" | \
    openssl enc -aes-256-cbc -md sha256 -a -d -salt -pass pass:"${CRYPTKEY}"
  )
  then
    echo "${PWCLEAR}"
    return 0
  else
    echo "Decryption FAILED!"
    return 1
  fi
}

# Check if directory-servers support TLS
function CheckTLSsupt {
  local    DIR_SERV
  local    DS_NAME
  local    DS_PORT
  local -a GOOD_DS_LIST

  for DIR_SERV in "${DS_LIST[@]}"
  do
    DS_NAME="${DIR_SERV//*;/}"
    DS_PORT="${DIR_SERV//;*/}"

    if [[ $(
        echo | \
        openssl s_client -showcerts -starttls ldap \
          -connect "${DS_NAME}:${DS_PORT}" 2> /dev/null | \
        openssl verify > /dev/null 2>&1
      )$? -eq 0 ]]
    then
      GOOD_DS_LIST+=("${DIR_SERV}")
      err_exit "Appending ${DS_NAME} to 'good servers' list" 0
    fi

    # shellcheck disable=SC2199
    # Add servers with good certs to list
    if [[ ${GOOD_DS_LIST[@]+"${GOOD_DS_LIST[@]}"} -gt 0 ]]
    then
      # Overwrite global directory-server array with successfully-pinged
      # servers' info
      DS_LIST=("${GOOD_DS_LIST[@]}")
      return 0
    else
      # Null the list
      DS_LIST=()
      err_exit "${DS_NAME} failed cert-check" 0
    fi
  done
}



################
# Main program #
################

LDAPPASSWD="$( PWdecrypt )"

# Verify that RPM-dependencies are met
VerifyDependencies

# Identify list of candidate directory servers
CandidateDirServ

# Port-ping candidate directory servers
PingDirServ

# Verify candidate directory servers' properly-functioning TLS support
if [[ ${REQ_TLS} == "true" ]]
then
  err_exit "Performing TLS-support test" 0
  CheckTLSsupt
else
  err_exit "Skipping TLS-support test" 0
fi

err_exit "Found ${#DS_LIST[@]} potentially-good directory servers" 0
