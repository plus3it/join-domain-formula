#!/bin/bash
# shellcheck disable=SC2155
#
# Under least-privileges security models, the PBIS installer can
# have problems joining a client to the domain if the domain
# already contains a matching computer object (even if join-
# account has add/modify/delete permissions to the object). This
# Script is designed to look for conflicting objects in the
# target directory and attempt to delete them. If conflicting
# object exists but is not deletable, this script will exit with
# a salt-compatible failure message.
#
# This script uses the PBIS-included tool, `adtool` to do the
# heavy-lifting. The lookup-routine looks like:
#
#    /opt/pbis/bin/adtool -d DOMAIN.F.Q.D.N -s SERVER \
#      -n <USERID>@<DOMAIN.F.Q.D.N> -x '<PASSWORD>' \
#      -a search-computer --name cn=<NODENAME> -t
#
# This script requires the positional input-parameters
# 1) DOMAIN.F.Q.D.N
# 2) USERID
# 3) PASSWORD
#
# Note: This utility assumes that domain-joiner account's UPN
#       takes the form "USERID@DOMAIN.F.Q.D.N"
#
#################################################################
PROGNAME="$( basename "${0}" )"
STATFILE="/tmp/.${PROGNAME}.err"

# Miscellaneous output-engine
function logIt {
   # Spit out message to calling-shell if debug-mode enabled
   if [[ ${DEBUGVAL} == true ]]
   then
      echo "${1}" >&2
   fi

   # Send to syslog if passed message-code is non-zero
   if [[ ! -z ${2} ]] && [[ ${2} -gt 0 ]]
   then
      logger -st "${PROGNAME}" -p "${LOGFACIL}" "${1}"
      exit "${2}"
   fi
}


# Check if enoug args were passed
if [[ ${#@} -ge 4 ]]
then
  # Positional parameters (we'd use getopts, but humans shouldn't
  # be directly invoking this script)
   DOMAIN=${1}
   USERID=${2}
   PASSCRYPT=${3}
   PASSULOCK=${4}
else
   printf "Usage: %s <DOMAIN.F.Q.D.N> <JOIN_USER> " "${PROGNAME}" >&2
   printf "<PASSWORD_CRYPT> <PASSWORD_UNLOCK>"  >&2
   exit 1
fi

# Generic vars
ADTOOL=$(rpm -qla pbis-open pbis-enterprise | grep adtool$)
NODENAME=$(hostname -s)


#########################
## Function definitions
#########################

# Decrypt Join Password
function PWdecrypt() {
   local PWCLEAR
   PWCLEAR=$(echo "${PASSCRYPT}" | openssl enc -aes-256-cbc -md sha256 -a -d \
             -salt -pass pass:"${PASSULOCK}")
   # shellcheck disable=SC2181
   if [[ $? -ne 0 ]]
   then
     echo ""
   else
     echo "${PWCLEAR}"
   fi
}


# Am I already joined
function CheckMyJoinState() {
   /opt/pbis/bin/lsa ad-get-machine account
}


# Check for object-collisions
function CheckObject() {
   local ADTOOLERR
   local EXISTS=$( "${ADTOOL}" -d "${DOMAIN}" -n "${USERID}@${DOMAIN}" \
                   -x "${PASSWORD}" -a search-computer \
                   --name cn="${NODENAME}" -t 2>&1 | tr -d '\n' )
   ADTOOLERR=$( ${EXISTS// /_} | sed -e 's/(//g' -e 's/)//g' )

   if [[ -z ${EXISTS} ]]
   then
      echo "NONE"
   else
      if [[ ${ADTOOLERR} =~ "ERROR:_400090" ]]
      then
         logIt "authentication credentials not valid"
         printf "authentication credentials not valid" > "${STATFILE}"
         echo "ERROR"
      elif [[ ${ADTOOLERR} =~ "ERROR:_500008" ]]
      then
         logIt "Stronger authentication required"
         printf "Stronger authentication required" > "${STATFILE}"
         echo "ERROR"
      elif [[ ${ADTOOLERR} =~ NERR_SetupNotJoined ]]
      then
         logIt "Not setup/joined"
         printf "Not setup/joined" > "${STATFILE}"
         echo "ERROR"
      else
         logIt "${EXISTS}"
         echo "${EXISTS}"
      fi
   fi
}


# Kill the collision
function NukeCollision() {
   local LOOP=0

   while [ $LOOP -le 5 ]
   do
      "${ADTOOL}" -d "${DOMAIN}" -n "${USERID}@${DOMAIN}" -x "${PASSWORD}" \
         -a delete-object --dn="$(CheckObject)" --force > /dev/null 2>&1

      if [[ $(sleep 5 ; CheckObject) = "NONE" ]]
      then
         printf "\n"
         printf "changed=yes comment='Deleted %s from " "${NODENAME}"
         printf "the directory'\n"
         exit 0
      fi

      local RND=$(shuf -i 1-15 -n 1)
      logger -p user.warn -t "pbis-join(nuke)" "Retrying nuke-attempt in $RND seconds"
      sleep "${RND}"

      (( LOOP++ ))
   done

   printf "\n"
   printf "changed=no comment='Failed to delete %s " "${NODENAME}"
   printf "from the directory'\n"
   exit 1
}


######################
## Main program flow
######################
# If already joined, no point proceeding further
if [[ -n "$(CheckMyJoinState)" ]]
then
   printf "\n"
   printf "changed=no comment='Local system has active join config present "
   printf "in the directory'\n"
   exit 0
fi

# Decrypt our password
PASSWORD=$(PWdecrypt)

# Bail if we can't decryption failed
if [[ -z "${PASSWORD}" ]]
then
  printf "\n"
  printf "changed=no comment='Failed to decrypt password'\n"
  exit 1
fi

# See if we can find an collision, try to nuke if we do
case $(CheckObject) in
   ERROR)
      OUTSTRING=$(<"${STATFILE}")
      printf "\n"
      printf "changed=no comment='Could not check for collision: "
      printf "%s'\n" "${OUTSTRING}"
      rm "${STATFILE}"
      exit 0
      ;;
   NONE)
      printf "\n"
      printf "changed=no comment='No collisions for %s found " "${NODENAME}"
      printf "in the directory'\n"
      exit 0
      ;;
   *)
      NukeCollision
      ;;
esac
