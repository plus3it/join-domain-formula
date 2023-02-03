#
# Salt state for joining an ELx host to an Active Directory
# domain using the OS-native tools, `sssd` and `realmd`
#
#################################################################
{%- from tpldir ~ '/map.jinja' import join_domain with context %}
{%- from tpldir ~ '/map.jinja' import pkg_list with context %}
{#- Set location for helper-files #}
{%- set joiner_files = tpldir ~ '/files' %}
{%- set common_tools = 'salt://' ~ salt.file.dirname(tpldir) ~ '/common-tools'  %}

install_sssd:
  pkg.installed:
    - allow_updates: True
    - pkgs: {{ pkg_list }}

join_realm:
  cmd.run:
    - unless: 'realm list | grep {{ join_domain.dns_name }}'
    - name: 'echo "Join host to {{ join_domain.dns_name }}"'
    ## - name: echo '<password>' | realm join -U <user> <domain>
