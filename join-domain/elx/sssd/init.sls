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

domain_defaults-{{ join_domain.dns_name }}:
  file.managed:
    - contents: |
        [domain/{{ join_domain.dns_name }}]
        override_homedir = /home/%d/%u
        use_fully_qualified_names = False
    - group: root
    - mode: '0600'
    - name: '/etc/sssd/conf.d/{{ join_domain.netbios_name }}.conf'
    - replace: true
    - user: root

join_realm-{{ join_domain.dns_name }}:
  cmd.run:
    - unless: 'realm list | grep {{ join_domain.dns_name }}'
    - name: 'echo "Join host to {{ join_domain.dns_name }}"'
    ## - name: echo '<password>' | realm join -U <user> <domain>
