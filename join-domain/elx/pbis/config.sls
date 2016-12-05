# Customize the PBIS configuration to assure a more sane,
# post-join behavior:
# * Set 'LoginShellTemplate' and 'Local_LoginShellTemplate' to
#   desired (friendlier) value ("/bin/bash" - PBIS defaults to
#   "/bin/sh")
# * Set 'HomeDirTemplate' and 'Local_HomeDirTemplate' to flatter
#   default value ("/home/<DOMAIN>/${USER}" - PBIS defaults to
#   "/home/local/<DOMAIN>/${USER}")
# * Set 'DomainManagerIgnoreAllTrusts' to "true" to prevent
#   spurious service-faults in multi-domain forests.
# * Set 'DomainManagerIncludeTrustsList' to match domain FQDN.
#   This setting is necessary due to setting of the
#   'DomainManagerIgnoreAllTrusts' value to "true"
#
#################################################################
{%- from tpldir ~ '/map.jinja' import join_domain with context %}

{%- for shell in join_domain.pbis_user_shell %}
PBIS-config-Shell-{{ shell }}:
  cmd.run:
    - name: |
        if [[ $({{ join_domain.install_bin_dir }}/bin/config --show {{ shell }} | grep -q -i "{{ join_domain.login_shell }}")$? -eq 0 ]]
        then
          printf "\n";
          printf "changed=no ";
          printf "comment='{{ shell }} already set to {{ join_domain.login_shell }}'";
        else
           {{ join_domain.install_bin_dir }}/bin/config {{ shell }} "{{ join_domain.login_shell }}";
           printf "\n";
           printf "changed=yes ";
           printf "comment='Forced {{ shell }} to {{ join_domain.login_shell }}'";
        fi
    - stateful: True
    - require:
      - cmd: PBIS-installsh
{%- endfor %}

{%- for home in join_domain.pbis_user_home %}
PBIS-config-Home-{{ home }}:
  cmd.run:
    - name: |
        if [[ $({{ join_domain.install_bin_dir }}/bin/config --show {{ home }} | grep -q -i "{{ join_domain.login_home }}")$? -eq 0 ]]
        then
          printf "\n";
          printf "changed=no ";
          printf "comment='{{ home }} already set to %s'" "{{ join_domain.login_home }}";
        else
           {{ join_domain.install_bin_dir }}/bin/config {{ home }} "{{ join_domain.login_home }}";
           printf "\n";
           printf "changed=yes ";
           printf "comment='Forced {{ home }} to %s'" "{{ join_domain.login_home }}";
        fi
    - stateful: True
    - require:
      - cmd: PBIS-installsh
{%- endfor %}

PBIS-config-TrustIgnore:
  cmd.run:
    - name: |
        if [[ $({{ join_domain.install_bin_dir }}/bin/config --show DomainManagerIgnoreAllTrusts | grep -q -i true)$? -eq 0 ]]
        then
          printf "\n";
          printf "changed=no ";
          printf "comment='DomainManagerIgnoreAllTrusts already set to true'";
        else
          {{ join_domain.install_bin_dir }}/bin/config DomainManagerIgnoreAllTrusts true
          printf "\n";
          printf "changed=yes ";
          printf "comment='Forced DomainManagerIgnoreAllTrusts to true'";
        fi
    - stateful: True
    - require:
      - cmd: PBIS-installsh

PBIS-config-TrustList:
  cmd.run:
    - name: |
        if [[ $({{ join_domain.install_bin_dir }}/bin/config --show DomainManagerIncludeTrustsList | grep -q -i "{{ join_domain.dns_name }}")$? -eq 0 ]]
        then
          printf "\n";
          printf "changed=no ";
          printf "comment='DomainManagerIncludeTrustsList already includes ";
          printf "{{ join_domain.dns_name }}'";
        else
          {{ join_domain.install_bin_dir }}/bin/config DomainManagerIncludeTrustsList \
          {{ join_domain.dns_name }};
          printf "\n";
          printf "changed=yes ";
          printf "comment='Forced DomainManagerIncludeTrustsList to ";
          printf "{{ join_domain.dns_name }}'";
        fi
    - stateful: True
    - require:
      - cmd: PBIS-installsh
