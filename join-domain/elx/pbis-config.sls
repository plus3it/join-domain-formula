# Customize the PBIS configuration to assure a more sane,
# post-join behavior:
# * Set 'LoginShellTemplate' and 'Local_LoginShellTemplate' to
#   desired (friendlier) value ("/bin/bash" - PBIS defaults to
#   "/bin/sh")
# * Set 'HomeDirTemplate' and 'Local_HomeDirTemplate' to flatter
#   default value ("/home/<DOMAIN>/${USER}" - PBIS sets to
#   "/home/local/<DOMAIN>/${USER}")
# * Set 'DomainManagerIgnoreAllTrusts' to "true" to prevent
#   spurious service-faults in multi-domain forrests.
# * Set 'DomainManagerIncludeTrustsList' to match domain FQDN.
#   This setting necessary due to setting of the
#   'DomainManagerIgnoreAllTrusts' value to "true"
#
#################################################################
{%- set pbisBinDir = salt['pillar.get']('join-domain:lookup:install_bin_dir') %}
{%- set domfqdn = salt['pillar.get']('join-domain:lookup:dns_name') %}
{%- set pbisUserHome = [ 'HomeDirTemplate', 'Local_HomeDirTemplate' ] %}
{%- set pbisUserShell = [ 'LoginShellTemplate', 'Local_LoginShellTemplate' ] %}
{%- set loginHome = '%H/%D/%U' %}
{%- set loginShell = '/bin/bash' %}

PBIS-config-iShell:
  cmd.run:
    - name: |
        (
{%- for userShell in pbisUserShell %}
         {{ pbisBinDir }}/bin/config {{ userShell }} "{{ loginShell }}"
{%- endfor %}
         echo
         printf "changed=yes "
         printf "comment='Forced user default-shell to nicer value'\n")
    - stateful: True
    - require:
      - cmd: PBIS-installsh

PBIS-config-uHome:
  cmd.run:
    - name: |
        (
{%- for uHome in pbisUserHome %}
         {{ pbisBinDir }}/bin/config {{ uHome }} "{{ loginHome }}"
{%- endfor %}
         echo
         printf "changed=yes "
         printf "comment='Forced home-directory location to nicer value'\n")
    - stateful: True
    - require:
      - cmd: PBIS-installsh

PBIS-config-TrustIgnore:
  cmd.run:
    - name: |
        ({{ pbisBinDir }}/bin/config DomainManagerIgnoreAllTrusts true
         echo
         printf "changed=yes "
         printf "comment='Forced DomainManagerIgnoreAllTrusts to true'")
    - stateful: True
    - require:
      - cmd: PBIS-installsh

PBIS-config-TrustList:
  cmd.run:
    - name: |
        ({{ pbisBinDir }}/bin/config DomainManagerIncludeTrustsList \
         {{ domfqdn }}
         echo
         printf "changed=yes "
         printf "comment='Forced DomainManagerIncludeTrustsList to "
         printf "{{ domfqdn }}'")
    - stateful: True
    - require:
      - cmd: PBIS-installsh
