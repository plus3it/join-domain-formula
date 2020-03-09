#!/bin/sh
# shellcheck disable=SC2181,SC2236
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
PROGNAME="$( basename "${0}" )"
PATH=/sbin:/usr/sbin:/bin:/usr/bin:/opt/pbis/bin
JOINOPOUTFILE="/var/run/.join.mesg"

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
          yes --userDomainPrefix "${DOMSHORT}" "${DOMFQDN}" \
          "${SVCACCT}" "${SVCPASS}" > "${JOINOPOUTFILE}" 2>&1
        ;;
      *)
        domainjoin-cli join --ou "${JOINOU}" --assumeDefaultDomain \
          yes --userDomainPrefix "${DOMSHORT}" "${DOMFQDN}" \
          "${SVCACCT}" "${SVCPASS}" > "${JOINOPOUTFILE}" 2>&1
        ;;
esac

  if [[ $? -eq 0 ]]
  then
      echo "SUCCESS"
  else
      echo "FAILED"
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
      printf "\t-h # print this message  \n"
      printf "\t-n <NETBIOS_NAME> \n"
      printf "\t-f <FQDN_HOSTNAME>  \n"
      printf "\t-u <USERNAME> \n"
      printf "\t-c <ENCRYPTED_PASSWORD>  \n"
      printf "\t-k <DECRYPTION_KEY>  \n"
      printf "\t-o <OU_PATH>  \n"
      echo "  GNU long options:"
      printf "\t--help # print this message  \n"
      printf "\t--netbios-name <NETBIOS_NAME>  \n"
      printf "\t--join-user <USERNAME> \n"
      printf "\t--hostname <FQDN_HOSTNAME>  \n"
      printf "\t--join-crypt <ENCRYPTED_PASSWORD>  \n"
      printf "\t--join-key <DECRYPTION_KEY>  \n"
      printf "\t--ou-path <OU_PATH>  \n"
  ) >&2
  exit 1
}

#########################
## Main program flow...
#########################

# Ensure parseable arguments have been passed
if [[ $# -eq 0 ]]
then
  logIt "No arguments given. Aborting" 1
fi

# Define flags to look for...
OPTIONBUFR=$(getopt -o hn:f:u:c:k:p:o: --long help,netbios-name:,hostname:,join-user:,join-crypt:,join-key:,join-password:,ou-path: -n "${PROGNAME}" -- "$@")

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
      -h|--help)
        UsageMsg
        ;;
      -n|--netbios-name)
        case "$2" in
            "")
              logIt "Error: option required but not specified" 1
              shift 2;
              exit 1
              ;;
            *)
              DOMSHORT="${2}"
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
              DOMFQDN="${2}"
              shift 2;
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
              SVCACCT="${2}"
              shift 2;
              ;;
        esac
        ;;
      -c|--join-crypt)
        case "$2" in
            "")
              logIt "Error: option required but not specified" 1
              shift 2;
              exit 1
              ;;
            *)
              PWCRYPT="${2}"
              SVCPASS="TOBESET"
              shift 2;
              ;;
        esac
        ;;
      -k|--join-key)
        case "$2" in
            "")
              logIt "Error: option required but not specified" 1
              shift 2;
              exit 1
              ;;
            *)
              PWUNLOCK="${2}"
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
              SVCPASS="${2}"
              shift 2;
              ;;
        esac
        ;;
      -o|--ou-path)
        case "$2" in
            "")
              JOINOU="UNDEF"
              shift 2;
              ;;
            *)
              JOINOU="${2}"
              JOINOU=${JOINOU// /\ }
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
if [[ -z  ${DOMSHORT+x} ]] ||
  [[ -z  ${DOMFQDN+x} ]] ||
  [[ -z  ${SVCACCT+x} ]]
then
  MISSINGARGS=true
  UsageMsg
fi

# Decrypt our query password (as necessary)
if [[ ${SVCPASS} == TOBESET ]]
then
  SVCPASS="$(PWdecrypt)"
  export SVCPASS

  # Bail if needed decrypt failed
  if [[ -z "${SVCPASS}" ]]
  then
    printf "\n"
    printf "changed=no comment='Failed to decrypt password'\n"
    exit 1
  else
    printf "Decrypted password for service-account [%s]\n\n" "${SVCACCT}"
  fi
fi


# Execute join-attempt as necessary...
case $(JoinStatus) in
  Unknown)
      # Make 10 attempts in case DC-syncs are slow
      for RETRY in {1..10}
      do
        printf "Join-attempt #%s... " "${RETRY}"
        if [[ $(DomainJoin) == SUCCESS ]]
        then
            echo "Join-operation succeded"
            printf "##########\n\n"
            cat "${JOINOPOUTFILE}" && rm "${JOINOPOUTFILE}"
            printf "\n\n##########\n"
            printf "\n"
            printf "changed=yes comment='Joined client to domain %s.'\n" "${DOMSHORT}"
            exit 0
        else
            printf "Join-operation failed:\n\n"
            printf "##########\n\n"
            cat "${JOINOPOUTFILE}" && rm "${JOINOPOUTFILE}"
            printf "\n\n##########\n"
            echo "Retrying in $(( RETRY * 10 )) seconds" > /dev/null
            # Increase retry-delay on each iteration...
            sleep $(( RETRY * 10 ))
        fi
      done

      # Report err-exit if final retry fails
      printf "\n"
      printf "changed=no comment='Failed to join client to domain "
      printf "%s.'\n" "${DOMSHORT}"
      exit 1
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
