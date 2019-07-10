#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################
{%- from tpldir ~ '/map.jinja' import join_domain with context %}

{#- Set location for helper-files #}
{%- set files = tpldir ~ '/files' %}
{%- set usePbisDdns = salt.pillar.get('join-domain:lookup:update-dns') %}

include:
  - .config

PBIS-install:
  pkg.installed:
    - sources: {{ join_domain.connector_rpms|yaml }}
    - allow_updates: True
    - skip_verify: True

PBIS-NETBIOSfix:
  cmd.script:
    - name: 'fix-hostname.sh'
    - source: 'salt://{{ files }}/fix-hostname.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - pkg: PBIS-install


PBIS-join:
  cmd.script:
    - name: 'join.sh "{{ join_domain.netbios_name }}" "{{ join_domain.dns_name }}" "{{ join_domain.username }}" "{{ join_domain.encrypted_password }}" "{{ join_domain.key }}" "{{ join_domain.oupath }}"'
    - source: 'salt://{{ files }}/join.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-NETBIOSfix

PBIS-PamPasswordDemunge:
  cmd.script:
    - name: 'fix-pam.sh "/etc/pam.d/password-auth"'
    - source: 'salt://{{ files }}/fix-pam.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-join

PBIS-PamSystemDemunge:
  cmd.script:
    - name: 'fix-pam.sh "/etc/pam.d/system-auth"'
    - source: 'salt://{{ files }}/fix-pam.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-join

{%- if usePbisDdns %}
PBIS-DDNS:
  cmd.run:
    - name: {{ join_domain.install_bin_dir }}/bin/update-dns
    - require:
      - cmd: PBIS-join
{%- endif %}
