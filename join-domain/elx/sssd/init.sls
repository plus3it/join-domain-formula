#
# Salt state for joining an ELx host to an Active Directory
# domain using the OS-native tools, `sssd` and `realmd`
#
#################################################################
{%- from tpldir ~ '/map.jinja' import join_domain with context %}
{#- Set location for helper-files #}
{%- set joiner_files = tpldir ~ '/files' %}
{%- set common_tools = 'salt://' ~ salt.file.dirname(tpldir) ~ '/common-tools'  %}
{%- set osrel = salt.grains.get('osmajorrelease')|string %}
{%- set pkg_map = {
    '7': [
      'adcli',
      'authconfig',
      'krb5-workstation',
      'oddjob',
      'oddjob-mkhomedir',
      'realmd',
      'sssd',
    ],
    '8': [
      'adcli',
      'authselect-compat',
      'krb5-workstation',
      'oddjob',
      'oddjob-mkhomedir',
      'realmd',
      'samba-common-tools',
      'sssd',
    ]
} %}
{%- set pkg_list = pkg_map[osrel] %}}

install_sssd:
  pkg.installed:
    - allow_updates: True
    - pkgs: {{ pkg_list }}

join_realm:
  cmd.run:
    - unless: 'realm list | grep {{ join_domain.dns_name }}'
    - name: 'echo "Join host to {{ join_domain.dns_name }}"'
    ## - name: echo '<password>' | realm join -U <user> <domain>
