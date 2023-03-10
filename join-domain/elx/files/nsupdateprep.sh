#!/bin/bash
# shellcheck disable=SC2181,SC2016
#
# Script to ensure that $(hostname --fqdn) returns correctly
#
#################################################################
BASEIPADDR=$( /sbin/ip route show | awk '/ src/{ print $9 }' )
SHORTNAME=$( hostname -s )
DOMNAME=$( hostname -d )

# Make sure we know our domain-name
if [[ -z ${DOMNAME} ]]
then
   printf "Guessing domain from resolv.conf "
   DOMNAME=$( awk '/search/{ print $2 }' /etc/resolv.conf )
   echo "[${DOMNAME}]"
fi

# See if we're good to go...
if [[ $( hostname --fqdn > /dev/null 2>&1 )$? -eq 0 ]]
then
   echo '`hostname --fqdn` returns success.'
elif [[ $( grep -q "${BASEIPADDR}" /etc/hosts )$? -eq 0 ]]
then
   if [[ $( grep -q "${SHORTNAME}.${DOMNAME}" /etc/hosts )$? -eq 0 ]]
   then
      echo "Hostname/IP-mapping already present in /etc/hosts"
   else
      printf "Found %s in /etc/hosts: adding entry for " "${BASEIPADDR}"
      printf "%s.%s " "${SHORTNAME}" "${DOMNAME} "
      sed -i "/${BASEIPADDR}/s/$/ ${SHORTNAME}.${DOMNAME}/" /etc/hosts 
      if [[ $? -eq 0 ]]
      then
         echo "...Success!"
      else
         echo "...Failed!"
	 exit 1
      fi
   fi
else
   printf "Adding host/IP binding %s %s" "${BASEIPADDR}" "${SHORTNAME}"
   printf ".%s to /etc/hosts " "${DOMNAME} "
   printf "%s\t%s.%s\n" "${BASEIPADDR}" "${SHORTNAME}" "${DOMNAME}" \
     >> /etc/hosts
   if [[ $? -eq 0 ]]
   then
      echo "...Success!"
   else
      echo "...Failed!"
	 exit 1
   fi
fi
