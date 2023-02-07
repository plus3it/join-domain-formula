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

fix_domain_separator:
  file.replace:
    - name: '/etc/sssd/sssd.conf'
    - pattern: '(^\[sssd]\n)'
    - repl: '\1override_space = ^\n'
    - unless: 'grep -q "^override_space" /etc/sssd/sssd.conf'

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
  cmd.script:
    - env:
      - ENCRYPT_PASS: '{{ join_domain.encrypted_password }}'
      - ENCRYPT_KEY: '{{ join_domain.key }}'
      - JOIN_DOMAIN: '{{ join_domain.dns_name }}'
      - JOIN_OU: '{{ join_domain.oupath }}'
      - JOIN_USER: '{{ join_domain.username }}'
    - cwd: '/root'
    - name: 'join.sh'
    - source: 'salt://{{ joiner_files }}/join.sh'
    - unless: 'realm list | grep {{ join_domain.dns_name }}'
