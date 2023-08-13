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
{%- set elMajor = salt.grains.get('osmajorrelease') | string %}
{%- set pam_no_nullok =
          'ash-linux.el' +
          elMajor +
          '.STIGbyID.cat1.RHEL-0' +
          elMajor +
          '-no_pam_nullok'
%}
{%- set pam_pwhistory =
          'ash-linux.el' +
          elMajor +
          '.STIGbyID.cat2.RHEL-0' +
          elMajor +
          '-pam_pwhistory'
%}
{%- set pam_faillock =
          'ash-linux.el' +
          elMajor +
          '.STIGbyID.cat2.RHEL-0' +
          elMajor +
          '-pam_faillock'
%}

# link to openldap-client so we can use state-exit data
{#- Get the `tplroot` from `tpldir` #}
{%- set tplroot = tpldir.split('/')[0] %}
{%- set sls_package_install = tplroot ~ '.elx.openldap-client.find-collision' %}

include:
  - {{ sls_package_install }}
  {%- if salt.state.sls_exists(pam_no_nullok) %}
  - {{ pam_no_nullok }}
  {%- endif %}
  {%- if salt.state.sls_exists(pam_pwhistory) %}
  - {{ pam_pwhistory }}
  {%- endif %}
  {%- if salt.state.sls_exists(pam_faillock) %}
  - {{ pam_faillock }}
  {%- endif %}

install_sssd:
  pkg.installed:
    - allow_updates: True
    - pkgs: {{ pkg_list }}
    - require:
      - cmd: 'LDAP-FindCollison'

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
      - file: 'domain_defaults-{{ join_domain.dns_name }}_ensure_permissions'
    - sections:
        domain/{{ join_domain.dns_name }}:
        {%- for key,value in join_domain.sssd_conf_parameters.items() %}
          {{ key }}: '{{ value }}'
        {%- endfor %}

domain_defaults-{{ join_domain.dns_name }}_ensure_permissions:
  file.managed:
    - group: 'root'
    - mode: '0600'
    - name: '/etc/sssd/conf.d/{{ join_domain.netbios_name }}.conf'
    - replace: False
    - require:
      - pkg: install_sssd
    - selinux:
        serange: 's0'
        serole: 'object_r'
        setype: 'sssd_conf_t'
        seuser: 'system_u'
    - user: 'root'


sssd-NETBIOSfix:
  cmd.script:
    - name: 'fix-hostname.sh'
    - source: '{{ common_tools }}/fix-hostname.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - pkg: install_sssd

join_realm-{{ join_domain.dns_name }}:
  cmd.script:
    - env:
      - ENCRYPT_PASS: '{{ join_domain.encrypted_password }}'
      - ENCRYPT_KEY: '{{ join_domain.key }}'
      - JOIN_DOMAIN: '{{ join_domain.dns_name }}'
      - JOIN_OU: '{{ join_domain.oupath }}'
      - JOIN_USER: '{{ join_domain.username }}'
      - OS_NAME_SET: '{{ join_domain.attrib_bool_name }}'
      - OS_VERS_SET: '{{ join_domain.attrib_bool_vers }}'
    - cwd: '/root'
    - name: 'join.sh'
    - output_loglevel: quiet
    - require:
      - ini: 'fix_domain_separator'
      - file: 'domain_defaults-{{ join_domain.dns_name }}_ensure_permissions'
      - cmd: 'sssd-NETBIOSfix'
    - require_in:
      {%- if salt.state.sls_exists(pam_no_nullok) %}
      - cmd: Ensure Valid Starting Config (RHEL-0{{ elMajor }}-no_pam_nullok)
      {%- endif %}
      {%- if salt.state.sls_exists(pam_pwhistory) %}
      - cmd: Ensure Valid Starting Config (RHEL-0{{ elMajor }}-pam_pwhistory)
      {%- endif %}
      {%- if salt.state.sls_exists(pam_faillock) %}
      - cmd: Ensure Valid Starting Config (RHEL-0{{ elMajor }}-pam_faillock)
      {%- endif %}
    - source: 'salt://{{ joiner_files }}/join.sh'
    - unless: 'realm list | grep -qs {{ join_domain.dns_name }}'

Ensure with-mkhomedir feature is enabled:
  cmd.run:
    - name: authselect enable-feature with-mkhomedir
    - cwd: /root
    - onlyif:
      - 'rpm -q --quiet authselect'
    - require:
      - cmd: join_realm-{{ join_domain.dns_name }}
      {%- if salt.state.sls_exists(pam_no_nullok) %}
      - cmd: Ensure Valid Starting Config (RHEL-0{{ elMajor }}-no_pam_nullok)
      {%- endif %}
      {%- if salt.state.sls_exists(pam_pwhistory) %}
      - cmd: Ensure Valid Starting Config (RHEL-0{{ elMajor }}-pam_pwhistory)
      {%- endif %}
      {%- if salt.state.sls_exists(pam_faillock) %}
      - cmd: Ensure Valid Starting Config (RHEL-0{{ elMajor }}-pam_faillock)
      {%- endif %}
    - unless:
      {%- if salt.grains.get('osmajorrelease') >= 8 %}
      - 'authselect current | grep -q "with-mkhomedir"'
      {%- endif %}

