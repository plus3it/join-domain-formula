#!/bin/sh
#
# Add passed group-name to sshd_config's "AllowGroups" directive
# if the passed group-name is not already present.
#
#################################################################
ALLOWGRP="${1:-UNDEF}"
SSHCFG="/etc/ssh/sshd_config"

if [[ ${ALLOWGRP} = "UNDEF" ]]
then
  echo "No group passed. Aborting..." > /dev/stderr
  exit 1
fi

if [[ $(grep -q "AllowGroups.*${ALLOWGRP}" ${SSHCFG})$? -eq 0 ]]
then
  printf "\n"
  printf "changed=no comment='%s already present in sshd_config " "${ALLOWGRP}"
  printf "AllowGroups directive.'\n"
  exit 0
else
  sed -i "s/AllowGroups.*$/& ${ALLOWGRP}/" ${SSHCFG}
  printf "\n"
  printf "changed=yes comment='Added %s to AllowGroups " "${ALLOWGRP}"
  printf "directive in sshd_config.'\n"
  exit 0
fi
