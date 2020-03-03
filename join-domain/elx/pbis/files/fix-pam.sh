#!/bin/sh
# shellcheck disable=SC2155
#
# This script is designed to fix PAM stack-order munging that may
# be caused by the PBIS package's "join" operations. When the
# pam_faillock module is present in /etc/pam.d/password-auth,
# PBIS places its edits in the wrong place, preventing
# password-based authentication from PBIS-managed SSH users from
# working.
#
#################################################################
PAMFILE="${1}"

# Resolve sym-links to real file-path so in-place
# replacements don't break things. ...This won't
# prevent hard-link breakage
function FindRealFile() {
  local REALFILE=$(readlink -f "${1}")

  echo "${REALFILE}"
}

# Fix munged stack-ordering
function FixPam() {
  local MOVELSASS=$(grep -q -E \
                    '^auth[ 	][ 	]*.*pam_lsass.so' "${CHKFILE}")$?

  if [[  ${MOVELSASS} -eq 0 ]]
  then
      local NUKIT=$(sed -i '/^auth[ 	][ 	]*.*pam_lsass.so/d' "${CHKFILE}")$?
      if [[ ${NUKIT} -ne 0 ]]
      then
        printf "\n"
        printf "changed=no comment='Failed to remove pam_lass directives. "
        printf "Aborting... \n"
        exit 1
      fi

      ITXT1="auth        requisite    pam_lsass.so    smartcard_prompt    try_first_pass"
      ITXT2="auth        sufficient      pam_lsass.so      try_first_pass"

      sed -i '/^auth.*default=die.*faillock/s/^/'"${ITXT1}"'\n'"${ITXT2}"'\n/' \
        "${CHKFILE}"

      printf "\n"
      printf "changed=yes comment='Moved pam_lsass modules up-stack.'\n"
      exit 0

  else
      printf "\n"
      printf "changed=no comment='Nothing to do: "
      printf "Do not need to move LSASS PAM modules...'\n"
      exit 0
  fi

}


######################
## Main program flow
######################

# Resolve sym-links
CHKFILE=$(FindRealFile "${PAMFILE}")
CKFAILLOCK=$(grep -q -E "^auth[ 	][ 	]*.*pam_faillock" "${CHKFILE}")$?

# Only act if pam_faillock is in play
if [[ ${CKFAILLOCK} -eq 0 ]]
then
  FixPam
else
  printf "\n"
  printf "changed=no comment='The faillock PAM module not present: "
  printf "leaving %s as-is'" "${CHKFILE}"
fi
