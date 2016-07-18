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
{%- from tpldir ~ '/map.jinja' import join_domain with context %}

PBIS-config-iShell:
  cmd.run:
    - name: |
        (
{%- for shell in join_domain.pbis_user_shell %}
         {{ join_domain.install_bin_dir }}/bin/config {{ shell }} "{{ join_domain.login_shell }}"
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
{%- for home in join_domain.pbis_user_home %}
         {{ join_domain.install_bin_dir }}/bin/config {{ home }} "{{ join_domain.login_home }}"
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
        ({{ join_domain.install_bin_dir }}/bin/config DomainManagerIgnoreAllTrusts true
         echo
         printf "changed=yes "
         printf "comment='Forced DomainManagerIgnoreAllTrusts to true'")
    - stateful: True
    - require:
      - cmd: PBIS-installsh

PBIS-config-TrustList:
  cmd.run:
    - name: |
        ({{ join_domain.install_bin_dir }}/bin/config DomainManagerIncludeTrustsList \
         {{ join_domain.dns_name }}
         echo
         printf "changed=yes "
         printf "comment='Forced DomainManagerIncludeTrustsList to "
         printf "{{ join_domain.dns_name }}'")
    - stateful: True
    - require:
      - cmd: PBIS-installsh
