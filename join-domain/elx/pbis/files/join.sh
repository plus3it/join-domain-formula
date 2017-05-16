#!/bin/sh
#
# Helper-script to more-intelligently handle joining PBIS client
# to domain. Script replaces "PBIS-join" cmd.run method with
# stateful cmd.script method. Script accepts following arguments:
#
# * DOMSHORT: Windows 2000-style short domain name. Passed via
#       the Salt-parameter 'domainShort'.
# * DOMFQDN: DNS-style, fully-qualified domain name of the
#       directory service domain. Passed via the Salt-parameter
#       'domainFqdn'.
# * SVCACCT: Service account userid used to join the PBIS client
#       to the directory service domain. Passed via the Salt-
#       parameter 'domainAcct'.
# * PWCRYPT: Obfuscated password for the ${SVCACCT} domain-joiner
#       account. Passed via the Salt-parameter 'svcPasswdCrypt'.
# * PWUNLOCK: String used to return Obfuscated password to clear-
#       text. Passed via the Salt-parameter 'svcPasswdUlk'.
# * JOINOU: OU to use for targeted-OU domain-join attempts.
#       Passed via the Salt-parameter 'domainOuPath'.
#
#################################################################
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/pbis/bin
DOMSHORT=${1:-UNDEF}
DOMFQDN=${2:-UNDEF}
SVCACCT=${3:-UNDEF}
PWCRYPT=${4:-UNDEF}
PWUNLOCK=${5:-UNDEF}
JOINOU=${6:-UNDEF}
JOINOU=${JOINOU// /\ }


# Get clear-text password from crypt
function PWdecrypt() {
   local PWCLEAR
   PWCLEAR=$(echo "${PWCRYPT}" | openssl enc -aes-256-cbc -md sha256 -a -d \
             -salt -pass pass:"${PWUNLOCK}")
   if [[ $? -ne 0 ]]
   then
     echo ""
   else
     echo "${PWCLEAR}"
   fi
}

# Clear lsass service and get current join-status
function JoinStatus() {
   /opt/pbis/bin/lwsm restart lsass > /dev/null 2>&1
   # Will take a few seconds for the status to refresh
   sleep 3
   /opt/pbis/bin/pbis-status | awk '/^[\t][\t]*Status:/{print $2}'
}

# Attempt to join client to domain
function DomainJoin() {
   # Srsly? Shellacked by '/" encapsulation...
   case "${JOINOU}" in
      none|None|NONE|UNDEF)
         domainjoin-cli join --assumeDefaultDomain \
           yes --userDomainPrefix ${DOMSHORT} ${DOMFQDN} \
           "${SVCACCT}" "${SVCPASS}" # > /dev/null 2>&1
         ;;
      *)
         domainjoin-cli join --ou "${JOINOU}" --assumeDefaultDomain \
           yes --userDomainPrefix ${DOMSHORT} ${DOMFQDN} \
           "${SVCACCT}" "${SVCPASS}" # > /dev/null 2>&1
         ;;
esac

   if [[ $? -eq 0 ]]
   then
      printf "\n"
      printf "changed=yes comment='Joined client to domain ${DOMSHORT}.'\n"
      exit 0
   else
      printf "\n"
      printf "changed=no comment='Failed to join client to domain "
      printf "${DOMSHORT}.'\n"
      exit 1
   fi
}


#########################
## Main program flow...
#########################

# Make sure all were the parms were passed
if [[ ${DOMSHORT} = UNDEF ]] || \
   [[ ${DOMFQDN} = UNDEF ]] || \
   [[ ${SVCACCT} = UNDEF ]] || \
   [[ ${PWCRYPT} = UNDEF ]] || \
   [[ ${PWUNLOCK} = UNDEF ]]
then
   printf "Usage: $0 <SHORT_DOMAIN> <DOMAIN_FQDN> <SVC_ACCT> "
   printf "<JOIN_PASS_CRYPT> <JOIN_PASS_UNLOCK>\n"
   echo "Failed to pass a required parameter. Aborting."
   exit 1
fi


# Execute join-attempt as necessary...
case $(JoinStatus) in
   Unknown)
      SVCPASS="$(PWdecrypt)"
      if [[ -z "${SVCPASS}" ]]
      then
        printf "\n"
        printf "changed=no comment='Failed to decrypt password'\n"
        exit 1
      fi
      DomainJoin
      ;;
   Online)
      printf "\n"
      printf "changed=no comment='Already joined to a domain.'\n"
      exit 0
      ;;
   *)
      printf "\n"
      printf "changed=no comment='Unable to determine status.'\n"
      exit 1
      ;;
esac
