#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################
{%- from tpldir ~ '/map.jinja' import join_domain with context %}

{#- Set location for helper-files #}
{%- set files = tpldir ~ '/files' %}

include:
  - .config

PBIS-stageFile:
  file.managed:
    - name: '/var/tmp/{{ join_domain.package_name }}'
    - source: '{{ join_domain.repo_uri_host }}/{{ join_domain.repo_uri_root_path }}/{{ join_domain.package_name }}'
    - source_hash: '{{ join_domain.repo_uri_host }}/{{ join_domain.repo_uri_root_path }}/{{ join_domain.package_hash }}'
    - user: root
    - group: root
    - mode: 0700

PBIS-installsh:
  cmd.script:
    - name: 'install.sh /var/tmp/{{ join_domain.package_name }}'
    - source: 'salt://{{ files }}/install.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - file: PBIS-stageFile

PBIS-NETBIOSfix:
  cmd.script:
    - name: 'fix-hostname.sh'
    - source: 'salt://{{ files }}/fix-hostname.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-installsh

PBIS-KillCollision:
  cmd.script:
    - name: 'fix-collisions.sh "{{ join_domain.dns_name }}" "{{ join_domain.username }}" "{{ join_domain.encrypted_password }}" "{{ join_domain.key }}"'
    - source: 'salt://{{ files }}/fix-collisions.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-NETBIOSfix

PBIS-join:
  cmd.script:
    - name: 'join.sh "{{ join_domain.netbios_name }}" "{{ join_domain.dns_name }}" "{{ join_domain.username }}" "{{ join_domain.encrypted_password }}" "{{ join_domain.key }}" "{{ join_domain.oupath }}"'
    - source: 'salt://{{ files }}/join.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-KillCollision

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
