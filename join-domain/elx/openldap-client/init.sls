#
# Salt state for downloading, installing and configuring OS-native
# OpenLDAP clients, then configuring to pull necessary information
# from an LDAP directory-source (e.g., Active Directory)
#
#################################################################
{%- from tpldir ~ '/map.jinja' import join_domain with context %}

{#- Set location for helper-files #}
{%- set files = tpldir ~ '/files' %}

include:
  - .config

RPM-installs:
  pkg.installed:
    - pkgs:
      - openldap-clients
      - bind-utils
    - allow_updates: True

LDAP-FindCollison:
  cmd.script:
    - name: 'find-collisions.sh "{{ join_domain.dns_name }}" "{{ join_domain.username }}" "{{ join_domain.encrypted_password }}" "{{ join_domain.key }}"'
    - source: 'salt://{{ files }}/fix-collisions.sh'
    - cwd: '/root'
    - stateful: True
