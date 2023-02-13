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
  ini.options_present:
    - name: '/etc/sssd/sssd.conf'
    - require:
      - pkg: install_sssd
    - sections:
        sssd:
          override_space: '^'
domain_defaults-{{ join_domain.dns_name }}:
  ini.options_present:
    - name: '/etc/sssd/conf.d/{{ join_domain.netbios_name }}.conf'
    - require:
      - pkg: install_sssd
    - sections:
        domain/{{ join_domain.dns_name }}:
          default_shell: '{{ join_domain.login_shell }}'
          override_homedir: '{{ join_domain.login_home }}'
          shell_fallback: '{{ join_domain.login_shell }}'
          use_fully_qualified_names: 'False'

domain_defaults-{{ join_domain.dns_name }}_ensure_permissions:
  file.managed:
    - group: 'root'
    - mode: '0600'
    - name: '/etc/sssd/conf.d/{{ join_domain.netbios_name }}.conf'
    - require:
      - ini: 'domain_defaults-{{ join_domain.dns_name }}'
    - selinux:
        serange: 's0'
        serole: 'object_r'
        setype: 'sssd_conf_t'
        seuser: 'system_u'
    - user: 'root'

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
    - require:
      - ini: 'fix_domain_separator'
      - file: 'domain_defaults-{{ join_domain.dns_name }}_ensure_permissions'
    - source: 'salt://{{ joiner_files }}/join.sh'
    - unless: 'realm list | grep -qs {{ join_domain.dns_name }}'
