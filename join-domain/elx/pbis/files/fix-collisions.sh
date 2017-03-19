#!/bin/sh
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
   printf "Usage: ${0} <DOMAIN.F.Q.D.N> <JOIN_USER> " > /dev/stderr
   printf "<PASSWORD_CRYPT> <PASSWORD_UNLOCK>"  > /dev/stderr
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
   if [[ $? -ne 0 ]]
   then
     echo ""
   else
     echo "${PWCLEAR}"
   fi
}


# Am I already joined
function CheckMyJoinState() {
   local CHKDOM=$(echo ${DOMAIN} | tr "[:lower:]" "[:upper:]")

   # Try to accommodate back-to-back (ab)use cases
   # This should ensure that the adcache file exists if the
   # host is properly configured to talk to AD
   HAVERPM=$(rpm -qa --quiet pbis-open pbis-enterprise)
   if [[ "${HAVERPM}" != "" ]] &&
      [[ ! -e /var/lib/pbis/db/lsass-adcache.filedb.${CHKDOM} ]]
   then
      service lwsmd restart > /dev/null 2>&1
   fi

   # See if adcache file exists - return value if it does
   if [[ -e /var/lib/pbis/db/lsass-adcache.filedb.${CHKDOM} ]]
   then
      echo "LOCALLYBOUND"
   fi
}


# Check for object-collisions
function CheckObject() {
   local EXISTS=$(${ADTOOL} -d ${DOMAIN} -n ${USERID}@${DOMAIN} \
                  -x "${PASSWORD}" -a search-computer \
                  --name cn="${NODENAME}" -t)

   if [[ -z ${EXISTS} ]]
   then
      echo "NONE"
   else
      echo "${EXISTS}"
   fi
}


# Kill the collision
function NukeCollision() {
   local LOOP=0

   while [ $LOOP -le 5 ]
   do
      ${ADTOOL} -d ${DOMAIN} -n ${USERID}@${DOMAIN} -x "${PASSWORD}" \
         -a delete-object --dn="$(CheckObject)" --force > /dev/null 2>&1

      if [[ $(sleep 5 ; CheckObject) = "NONE" ]]
      then
         printf "\n"
         printf "changed=yes comment='Deleted ${NODENAME} from "
         printf "the directory'\n"
         exit 0
      fi

      local RND=$(shuf -i 1-15 -n 1)
      logger -p user.warn -t "pbis-join(nuke)" "Retrying nuke-attempt in $RND seconds"
      sleep ${RND}

      (( LOOP++ ))
   done

   printf "\n"
   printf "changed=no comment='Failed to delete ${NODENAME} "
   printf "from the directory'\n"
   exit 1
}


######################
## Main program flow
######################
PASSWORD=$(PWdecrypt)

if [[ -z "${PASSWORD}" ]]
then
  printf "\n"
  printf "changed=no comment='Failed to decrypt password'\n"
  exit 1
fi

if [[ $(CheckObject) = NONE ]]
then
   printf "\n"
   printf "changed=no comment='No collisions for ${NODENAME} found "
   printf "in the directory'\n"
   exit 0
elif [[ $(CheckMyJoinState) = "LOCALLYBOUND" ]]
then
   printf "\n"
   printf "changed=no comment='Local system has active join config present "
   printf "in the directory'\n"
   exit 0
else
   NukeCollision
fi
