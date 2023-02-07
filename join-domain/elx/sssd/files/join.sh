#!/bin/bash
set -eu
#
# Script to join host to domain
#
#################################################################
PROGNAME="$( basename "${0}" )"
JOIN_DOMAIN="${JOIN_DOMAIN:-UNDEF}"
JOIN_OU="${JOIN_OU:-}"
JOIN_USER="${JOIN_USER:-Administrator}"
JOIN_CNAME="${JOIN_CNAME:-UNDEF}"
PWCRYPT="${ENCRYPT_PASS:-UNDEF}"
PWUNLOCK="${ENCRYPT_KEY:-UNDEF}"
CLIENT_OSNAME="$(
   awk -F "=" '/^NAME/{ print $2}' /etc/os-release |
   sed 's/"//g'
)"
CLIENT_OSVERS="$(
   awk -F "=" '/^VERSION_ID/{ print $2 }' /etc/os-release |
   sed 's/"//g'
)"

# Get clear-text password from crypt
function PWdecrypt {
  local PWCLEAR

  PWCLEAR=$(
     echo "${PWCRYPT}" | \
     openssl enc -aes-256-cbc -md sha256 -a -d -salt -pass pass:"${PWUNLOCK}"
  )

  if [[ $? -ne 0 ]]
  then
    echo ""
    return 1
  else
    echo "${PWCLEAR}"
    return 0
  fi
}

# Make sure domain is discoverable
function IsDiscoverable {
   if [[ $( realm discover "${JOIN_DOMAIN}" > /dev/null 2>&1 )$? -eq 0 ]]
   then
      printf "The %s domain is discoverable\n" "${JOIN_DOMAIN}"
      return 0
   else
      printf "The %s domain is not discoverable. Aborting...\n" "${JOIN_DOMAIN}"
      return 1
   fi
}

# Try to join host to domain
function JoinDomain {

   if [[ -z ${JOIN_OU} ]]
   then
      echo "$( PWdecrypt )" | \
      realm join -U "${JOIN_USER}" \
        --os-name="${CLIENT_OSNAME}" \
        --os-version="${CLIENT_OSVERS}" "${JOIN_DOMAIN}"
   elif [[ -n ${JOIN_OU} ]]
   then
      echo "$( PWdecrypt )" | \
      realm join -U "${JOIN_USER}" \
        --computer-ou="${JOIN_OU}" \
        --os-name="${CLIENT_OSNAME}" \
        --os-version="${CLIENT_OSVERS}" "${JOIN_DOMAIN}"
   else
      echo "Unsupported configuration-options"
      return 1
   fi

   return 0

}

IsDiscoverable
JoinDomain
