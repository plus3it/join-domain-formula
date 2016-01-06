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
