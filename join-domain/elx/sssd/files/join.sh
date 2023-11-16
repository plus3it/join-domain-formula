#!/bin/bash
set -eu -o pipefail
#
# Script to join host to domain
#
#################################################################
DOMAIN_ACTION="${DOMAIN_ACTION:-join}"
JOIN_DOMAIN="${JOIN_DOMAIN:-UNDEF}"
JOIN_OU="${JOIN_OU:-}"
JOIN_USER="${JOIN_USER:-Administrator}"
JOIN_CNAME="${JOIN_CNAME:-UNDEF}"
JOIN_TRIES="${JOIN_TRIES:-5}"
OS_NAME_SET="${OS_NAME_SET:-False}"
OS_VERS_SET="${OS_VERS_SET:-False}"
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

  local    JOIN_CRED
  local -i LOOP
  local -a REALM_JOIN_OPTS
  local -i RET_CODE

  REALM_JOIN_OPTS=(
    -U "${JOIN_USER}"
    --unattended
  )

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

  # Get credentials used for join operation
  JOIN_CRED="$( PWdecrypt )"

  if [[ ${OS_NAME_SET} = "True" ]]
  then
      REALM_JOIN_OPTS+=("--os-name=\"${CLIENT_OSNAME}\"")
  fi

  if [[ ${OS_VERS_SET} = "True" ]]
  then
      REALM_JOIN_OPTS+=("--os-version=\"${CLIENT_OSVERS}\"")
  fi

  if [[ -n ${JOIN_OU} ]]
  then
      REALM_JOIN_OPTS+=("--computer-ou=${JOIN_OU}")
  fi

  printf "Realm join options: %s\n" "${REALM_JOIN_OPTS[*]}"


  LOOP=0
  while [[ ${LOOP} -lt ${JOIN_TRIES} ]]
  do
    LOOP=$(( LOOP += 1 ))

    printf "Joining to %s (attempt %s)... " "${JOIN_DOMAIN}" "${LOOP}"

    if [[ $(
        echo "${JOIN_CRED}" | \
        realm join \
          "${REALM_JOIN_OPTS[@]}" \
          "${JOIN_DOMAIN}" > /dev/null 2>&1
    )$? -eq 0 ]]
    then
      RET_CODE=0

      echo "Success"

      break
    else
      echo "FAILED: Getting system logs"
      printf "\n==============================\n"
      journalctl -u realmd | \
        grep "$( date '+%b %d %H:%M' )" | \
        sed 's/^.*]: /: /'
      printf "\n==============================\n"

      RET_CODE=1
    fi

    # Either sleep or quit
    if [[ ${LOOP} -lt ${JOIN_TRIES} ]]
    then
      echo "Retrying in 15s..."
      sleep 15
    else
      echo "Giving up."
    fi

  done

  # Revert SEL as necessary
  if [[ ${SEL_TARG} -eq 1 ]]
  then
    printf "Resetting SELinux mode... "
    setenforce "${SEL_TARG}" || ( echo "FAILED" ; exit 1 )
    echo "Success"
  fi

  return ${RET_CODE}
}

# Try to leave and remove host from domain
function LeaveDomain {
  local    LEAVE_CRED
  local -a REALM_OPTS

  REALM_OPTS=(
    -U "${JOIN_USER}"
    --unattended
    --remove
  )

  # Get credentials used for leave operation
  LEAVE_CRED="$( PWdecrypt )"


  printf "Removing %s from to %s" "$( hostname -s )" "${JOIN_DOMAIN}"

  if [[ $(
    echo "${LEAVE_CRED}" |
    realm leave \
      "${REALM_OPTS[@]}" \
      "${JOIN_DOMAIN}" > /dev/null 2>&1
  )$? -eq 0 ]]
  then
    RET_CODE=0

    echo "Success"

  else
      echo "FAILED: Getting system logs"
      printf "\n==============================\n"
      journalctl -u realmd | \
        grep "$( date '+%b %d %H:%M' )" | \
        sed 's/^.*]: /: /'
      printf "\n==============================\n"

      RET_CODE=1
  fi

  return "${RET_CODE}"

}

# Should I stay or should I go, now
if [[ ${DOMAIN_ACTION:-} == "join" ]]
then
  IsDiscoverable
  JoinDomain
elif [[ ${DOMAIN_ACTION:-} == "leave" ]]
then
  LeaveDomain
fi
