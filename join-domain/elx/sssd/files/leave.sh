#!/bin/bash
# shellcheck disable=SC1091
set -eu -o pipefail
#
# Script to disable directory-based authentication and remove computerObject
# from the directory-service
#
################################################################################
PROGDIR="$( dirname "${0}" )"

# Set envs that are common to both join and leave scripts
source "${PROGDIR}/script.envs"

# Import shared password-decrypt function
source "${PROGDIR}/pw-decrypt.func"


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

  exit "${RET_CODE}"

}

LeaveDomain
