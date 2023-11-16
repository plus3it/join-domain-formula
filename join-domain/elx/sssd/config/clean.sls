{#- Get the `tplroot` from `tpldir` #}
{%- set tplroot = tpldir.split('/')[0] %}
{%- set joiner_files = tplroot ~ '/elx/sssd/files' %}

{%- from tplroot ~ "/map.jinja" import mapdata as join_domain with context %}

Check Realm Status - {{ join_domain.dns_name }}:
  cmd.run:
    - name: '/sbin/realm list | grep -q ''^{{ join_domain.dns_name }}'''

Leave Realm - {{ join_domain.dns_name }}:
  cmd.script:
    - env:
      - DOMAIN_ACTION: 'leave'
      - ENCRYPT_PASS: '{{ join_domain.encrypted_password }}'
      - ENCRYPT_KEY: '{{ join_domain.key }}'
      - JOIN_DOMAIN: '{{ join_domain.dns_name }}'
      - JOIN_OU: '{{ join_domain.oupath }}'
      - JOIN_USER: '{{ join_domain.username }}'
    - cwd: '/root'
    - name: 'join.sh'
    - output_loglevel: quiet
    - require:
      - cmd: 'Check Realm Status - {{ join_domain.dns_name }}'
    - source: 'salt://{{ joiner_files }}/join.sh'



authselect Disable 'with-mkhomedir':
  cmd.run:
    - name: 'authselect disable-feature with-mkhomedir'
    - require:
      - cmd: 'Leave Realm - {{ join_domain.dns_name }}'
