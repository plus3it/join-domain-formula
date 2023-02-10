#!/bin/bash
set -eu -o pipefail
#
# Script to join host to domain
#
#################################################################
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

  # Get cleartext password-string
  if PWCLEAR=$(
    echo "${PWCRYPT}" | \
    openssl enc -aes-256-cbc -md sha256 -a -d -salt -pass pass:"${PWUNLOCK}"
  )
  then
    echo "${PWCLEAR}"
    return 0
  else
    echo "Decryption FAILED!"
    return 1
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

  # Toggle SELinux if necessary
  if [[ $( getenforce ) == "Enforcing" ]]
  then
    SEL_TARG="1"
    printf "Toggling SELinux mode... "
    setenforce 0 || (echo "FAILED" ; exit 1 )
    echo SUCCESS
  else
    SEL_TARG=0
  fi

  if [[ -z ${JOIN_OU} ]]
  then
    printf "Joining to %s... " "${JOIN_DOMAIN}"
    # shellcheck disable=SC2005
    echo "$( PWdecrypt )" | \
    realm join -U "${JOIN_USER}" \
      --unattended \
      --os-name="${CLIENT_OSNAME}" \
      --os-version="${CLIENT_OSVERS}" "${JOIN_DOMAIN}" > /dev/null 2>&1 || \
    ( echo "FAILED" ; exit 1)
    echo "Success"

  elif [[ -n ${JOIN_OU} ]]
  then
    printf "Joining to %s under %s OU... " "${JOIN_DOMAIN}" "${JOIN_OU}"
    # shellcheck disable=SC2005
    echo "$( PWdecrypt )" | \
    realm join -U "${JOIN_USER}" \
      --unattended \
      --computer-ou="${JOIN_OU}" \
      --os-name="${CLIENT_OSNAME}" \
      --os-version="${CLIENT_OSVERS}" "${JOIN_DOMAIN}" > /dev/null 2>&1 || \
    ( echo "FAILED" ; exit 1)
    echo "Success"
  else
    echo "Unsupported configuration-options"
    return 1
  fi

  # Revert SEL as necessary
  if [[ ${SEL_TARG} -eq 1 ]]
  then
    printf "Resetting SELinux mode... "
    setenforce "${SEL_TARG}" || ( echo "FAILED" ; exit 1 )
    echo "Success"
  fi

  return 0
}

IsDiscoverable
JoinDomain
