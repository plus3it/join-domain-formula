#
# Salt state for downloading, installing and configuring OS-native
# OpenLDAP clients, then configuring to pull necessary information
# from an LDAP directory-source (e.g., Active Directory)
#
#################################################################
{%- from tpldir ~ '/map.jinja' import join_domain with context %}

{#- Set location for helper-files #}
{%- set files = tpldir ~ '/files' %}

RPM-installs:
  pkg.installed:
    - pkgs:
      - openldap-clients
      - bind-utils
    - allow_updates: True

LDAP-FindCollison:
  cmd.script:
    - cwd: '/root'
    - name: 'find-collisions.sh -d "{{ join_domain.dns_name }}" -u "{{ join_domain.username }}" -c "{{ join_domain.encrypted_password }}" -k "{{ join_domain.key }}" --mode saltstack'
    - require:
      - pkg: RPM-installs
    - source: 'salt://{{ files }}/find-collisions.sh'
    - stateful: True

