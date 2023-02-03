#
# Salt state for joining an ELx host to an Active Directory
# domain using the OS-native tools, `sssd` and `realmd`
#
#################################################################
{%- from tpldir ~ '/map.jinja' import join_domain with context %}
{#- Set location for helper-files #}
{%- set joiner_files = tpldir ~ '/files' %}
{%- set common_tools = 'salt://' ~ salt.file.dirname(tpldir) ~ '/common-tools'  %}
{%- set osrel = salt.grains.get('osmajorrelease') %}
{%- set sssd_pkgs = join_domain.sssd_pkgs %}


install_sssd:
  pkg.installed:
    - allow_updates: True
    - pkgs:
{%- if osrel == '7' %}
      {{ sssd_pkgs.el7 }}
{%- elif osrel == '8' %}
      {{ sssd_pkgs.el8 }}
{%- endif %}

join_realm:
  cmd.run:
    - unless: 'realm list | grep {{ join_domain.dns_name }}'
    - name: 'echo "Join host to {{ join_domain.dns_name }}"'
    ## - name: echo '<password>' | realm join -U <user> <domain>
