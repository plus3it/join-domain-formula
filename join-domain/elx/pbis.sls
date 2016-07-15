#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################

# Set location for helper-files
{%- set scriptDir = 'join-domain/elx/files' %}

# Move service-config elsewhere
include:
  - join-domain.elx.pbis-config

# Vars used to run the domain-join actions
{%- set join_elx = salt['pillar.get']('join-domain:lookup', {}) %}
{%- do join_elx.update(salt['grains.get']('join-domain', {})) %}
{%- set domainFqdn = join_elx.dns_name %}
{%- set domainShort = join_elx.netbios_name %}
{%- set domainAcct = join_elx.username %}
{%- set svcPasswdCrypt = join_elx.encrypted_password %}
{%- set svcPasswdUlk = join_elx.key %}
{%- set domainOuPath = join_elx.get('oupath', '') %}

# Vars for getting PBIS install-media
{%- set repoHost = join_elx.repo_uri_host %}
{%- set repoPath = join_elx.repo_uri_root_path %}
{%- set pbisPkg = join_elx.package_name %}
{%- set pbisHash = join_elx.package_hash %}

# Vars for checking for previous installations' config files
{%- set pbisBinDir = join_elx.install_bin_dir %}
{%- set pbisVarDir = join_elx.install_var_dir %}
{%- set pbisDbDir = join_elx.install_db_dir %}
{%- set pbisDbs = join_elx.checkFiles %}

# Vars for checking for previous installations' config RPMs
{%- set pbisRpms = join_elx.connectorRpms %}

# Derive service join-password (there's gotta be a less-awful way?)
{%- set joinPass = salt.cmd.run('echo "' + svcPasswdCrypt + '" | \
    openssl enc -aes-256-ecb -a -d -salt -pass pass:"' + svcPasswdUlk + '"') %}

PBIS-stageFile:
  file.managed:
    - name: '/var/tmp/{{ pbisPkg }}'
    - source: '{{ repoHost }}/{{ repoPath }}/{{ pbisPkg}}'
    - source_hash: '{{ repoHost }}/{{ repoPath }}/{{ pbisHash}}'
    - user: root
    - group: root
    - mode: 0700

PBIS-installsh:
  cmd.script:
    - name: 'pbis-install_only.sh /var/tmp/{{ pbisPkg }}'
    - source: 'salt://{{ scriptDir }}/pbis-install_only.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - file: PBIS-stageFile

PBIS-NETBIOSfix:
  cmd.script:
    - name: 'pbis-chkNBcomp.sh'
    - source: 'salt://{{ scriptDir }}/pbis-chkNBcomp.sh'
    - cwd: '/root'
    - require:
      - cmd: PBIS-installsh

PBIS-KillCollision:
  cmd.script:
    - name: 'pbis-clndir.sh "{{ domainFqdn }}" "{{ domainAcct }}" "{{ svcPasswdCrypt }}" "{{ svcPasswdUlk }}"'
    - source: 'salt://{{ scriptDir }}/pbis-clndir.sh'
    - cwd: '/root'
    - require:
      - cmd: PBIS-NETBIOSfix

PBIS-join:
  cmd.script:
    - name: 'pbis-join.sh "{{ domainShort }}" "{{ domainFqdn }}" "{{ domainAcct }}" "{{ svcPasswdCrypt }}" "{{ svcPasswdUlk }}" "{{ domainOuPath }}"'
    - source: 'salt://{{ scriptDir }}/pbis-join.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-KillCollision

PBIS-PamPasswordDemunge:
  cmd.script:
    - name: 'pbis-fix_pam.sh "/etc/pam.d/password-auth"'
    - source: 'salt://{{ scriptDir }}/pbis-fix_pam.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-join

PBIS-PamSystemDemunge:
  cmd.script:
    - name: 'pbis-fix_pam.sh "/etc/pam.d/system-auth"'
    - source: 'salt://{{ scriptDir }}/pbis-fix_pam.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-join
