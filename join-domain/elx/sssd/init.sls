#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################

install_sssd:
  pkg.installed:
    - allow_updates: True
    - pkgs:
      - adcli
      - authselect-compat
      - krb5-workstation
      - oddjob
      - oddjob-mkhomedir
      - realmd
      - samba-common
      - samba-common-tools
      - sssd
