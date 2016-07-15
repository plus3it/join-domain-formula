#
# Salt state for adding Active Directory groups to the sudoers
# and sshd_configurations:
# * Members of login_groups will be added to the AllowGroups
#   parameter in /etc/ssh/sshd_config
# * Members of admin_groups will be added to the AllowGroups
#   parameter in /etc/ssh/sshd_config
# * Members of admin_groups will be added to group-file(s)
#   placed in /etc/sudoers.d
#
#################################################################

{%- set admin_groups = salt['pillar.get']('join-domain:lookup:admin_groups', []) %}
{%- set login_groups = salt['pillar.get']('join-domain:lookup:login_groups', []) %}
{%- set sudo_d = '/etc/sudoers.d' %}
{%- set sshd_cfg = '/etc/ssh/sshd_config' %}
{%- set allow_groups = admin_groups + login_groups %}
{%- set scriptDir = 'join-domain/elx/files' %}

# Add to /etc/suders.d/group_XXX file
{%- for admin in admin_groups %}
admin_group-{{ admin }}:
  file.append:
    - name: '{{ sudo_d }}/group_{{ admin }}'
    - text: '%{{ admin }}	ALL=(root)	NOPASSWD:ALL'
    - unless:
      - 'grep -q {{ admin }} {{ sudo_d }}/group_{{ admin }}'
{%- endfor %}

# Add to /etc/ssh/sshd_config
AddDirective-sshd:
  file.append:
    - name: '{{ sshd_cfg }}'
    - text: 'AllowGroups '
    - unless:
      - 'grep -q AllowGroups {{ sshd_cfg }}'

{%- for group in allow_groups %}
ssh_allow_group-{{ group }}:
  cmd.script:
    - name: 'ssh_allow_group.sh "{{ group }}"'
    - source: 'salt://{{ scriptDir }}/ssh_allow_group.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - file: AddDirective-sshd
{%- endfor %}
