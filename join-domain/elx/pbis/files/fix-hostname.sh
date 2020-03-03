#!/bin/sh
#
# The NETBIOS character-limit for hostnames is fifteen
# characters. If PBIS attempts to join the host to a domain and
# the host's shortname is greater than fifteeen characters, the
# join operation will fail with one of two errors:
# * LDAP_INSUFFICIENT_ACCESS: this error is thrown when the
#   domain-join operation causes the overlong hostname to be
#   re-written. The PBIS software does not detect the re-write.
#   As PBIS attempts to do computer-object attribute updates,
#   those updates fail because it is using an invalid name for
#   the computer-object actually in AD.
# * LDAP_CONSTRAINT_VIOLATION: this error is thrown when a prior
#   domain-join operation has caused an abbreviated computer-
#   object name to be created in AD and the current operation
#   cannot resolve the deadlock.
#
# This purpose of this script is to detect if the current
# hostname is too long then modify the system configuration to be
# more compatible with the NETBIOS character limits prior to
# attempting the join-operation. In the event the pre-join
# hostname is too long, this script will:
# * Alter the hostname to be compatible with NETBIOS limits
# * Record the node's original hostname to a file
# * Ensure that PBIS's shortening of HOSTNAME in the
#   /etc/sysconfig/network file is reverted
#
#################################################################

# Check if nodename is too long
if [[ $(HOST=$(hostname -s) ; echo ${#HOST}) -gt 15 ]]
then
  # Calculate default-interface
  DEFIF=$(ip route show | awk '/^default/{print $5}')

  if [[ ${DEFIF} = "" ]]
  then
      # Abort if there's no default-route
      printf "\n"
      printf "changed=no comment='Host has no default route. "
      printf "Cant cope.'\n"
      exit 1
  else
      OLDFQDN=$(hostname)
      CURDOM=$(awk -F = '/HOSTNAME/{print $2}' /etc/sysconfig/network | \
              sed "s/$(hostname -s)\.//")
      BASEIP=$(printf '%02X' \
              "$(ip addr show "${DEFIF}" | \
                awk '/inet /{print $2}' | \
                sed -e 's#/.*$##' -e 's/\./ /g' \
              )")

      # Try to make new hostname fully-qualified
      if [[ ${CURDOM} = "" ]]
      then
        NEWFQDN="ip-${BASEIP,,}"
      else
        NEWFQDN="ip-${BASEIP,,}.${CURDOM}"
      fi

      if [[ $(hostname "${NEWFQDN}" )$? -eq 0 ]]
      then
        # Create info-preservation files
        echo "${OLDFQDN}" > /etc/sysconfig/hostname.fqdn-orig
        echo "${NEWFQDN}" > /etc/sysconfig/hostname.fqdn-new

        printf "\n"
        printf "changed=yes comment='Changed hostname from %s to " "${OLDFQDN}"
        printf "%s.'\n" "${NEWFQDN}"
        exit 0
      else
        printf "\n"
        printf "changed=no comment='Failed to change hostname "
        printf "to %s.'\n" "${NEWFQDN}"
        exit 1
      fi
  fi
else
  printf "\n"
  printf "changed=no comment='Host short-name is NETBIOS compliant.'\n"
  exit 0
fi
