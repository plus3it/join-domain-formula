#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################

{#- Set location for helper-files #}
{%- set files = tpldir ~ '/files' %}

include:
  - .config

{#- Vars used to run the domain-join actions #}
{%- set join_elx = salt['pillar.get']('join-domain:lookup', {}) %}
{%- do join_elx.update(salt['grains.get']('join-domain', {})) %}
{%- set domainFqdn = join_elx.dns_name %}
{%- set domainShort = join_elx.netbios_name %}
{%- set domainAcct = join_elx.username %}
{%- set svcPasswdCrypt = join_elx.encrypted_password %}
{%- set svcPasswdUlk = join_elx.key %}
{%- set domainOuPath = join_elx.get('oupath', '') %}

{#- Vars for getting PBIS install-media #}
{%- set repoHost = join_elx.repo_uri_host %}
{%- set repoPath = join_elx.repo_uri_root_path %}
{%- set pbisPkg = join_elx.package_name %}
{%- set pbisHash = join_elx.package_hash %}

{#- Vars for checking for previous installations' config files #}
{%- set pbisBinDir = join_elx.install_bin_dir %}
{%- set pbisVarDir = join_elx.install_var_dir %}
{%- set pbisDbDir = join_elx.install_db_dir %}
{%- set pbisDbs = join_elx.checkFiles %}

{#- Vars for checking for previous installations' config RPMs #}
{%- set pbisRpms = join_elx.connectorRpms %}

{#- Derive service join-password (there's gotta be a less-awful way?) #}
{%-
    set joinPass = salt.cmd.run('echo "' + svcPasswdCrypt + '" | \
        openssl enc -aes-256-ecb -a -d -salt -pass pass:"' + svcPasswdUlk + '"'
    )
%}

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
    - name: 'install.sh /var/tmp/{{ pbisPkg }}'
    - source: 'salt://{{ files }}/install.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - file: PBIS-stageFile

PBIS-NETBIOSfix:
  cmd.script:
    - name: 'fix-hostname.sh'
    - source: 'salt://{{ files }}/fix-hostname.sh'
    - cwd: '/root'
    - require:
      - cmd: PBIS-installsh

PBIS-KillCollision:
  cmd.script:
    - name: 'fix-collisions.sh "{{ domainFqdn }}" "{{ domainAcct }}" "{{ svcPasswdCrypt }}" "{{ svcPasswdUlk }}"'
    - source: 'salt://{{ files }}/fix-collisions.sh'
    - cwd: '/root'
    - require:
      - cmd: PBIS-NETBIOSfix

PBIS-join:
  cmd.script:
    - name: 'join.sh "{{ domainShort }}" "{{ domainFqdn }}" "{{ domainAcct }}" "{{ svcPasswdCrypt }}" "{{ svcPasswdUlk }}" "{{ domainOuPath }}"'
    - source: 'salt://{{ files }}/join.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-KillCollision

PBIS-PamPasswordDemunge:
  cmd.script:
    - name: 'fix-pam.sh "/etc/pam.d/password-auth"'
    - source: 'salt://{{ files }}/fix-pam.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-join

PBIS-PamSystemDemunge:
  cmd.script:
    - name: 'fix-pam.sh "/etc/pam.d/system-auth"'
    - source: 'salt://{{ files }}/fix-pam.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - cmd: PBIS-join
