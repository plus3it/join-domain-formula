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

{%- set admin_users = salt['pillar.get']('join-domain:lookup:admin_users', []) %}
{%- set admin_groups = salt['pillar.get']('join-domain:lookup:admin_groups', []) %}
{%- set login_users = salt['pillar.get']('join-domain:lookup:login_users', []) %}
{%- set login_groups = salt['pillar.get']('join-domain:lookup:login_groups', []) %}
{%- set sudo_d = '/etc/sudoers.d' %}
{%- set sshd_cfg = '/etc/ssh/sshd_config' %}
{%- set users = admin_users + login_users %}
{%- set admins = admin_groups + admin_users %}
{%- set logins = admin_users + admin_groups + login_users + login_groups %}
{%- set scriptDir = 'join-domain/elx/files' %}

{%- for user in users %}
# Create a group for {{ user }}, for sshd AllowGroups to work
Create group for user {{ user }}:
  group.present:
    - name: {{ user }}

Add member {{ user }}:
  file.replace:
    - name: /etc/group
    - pattern: '(^{{ user }}:.*:.*:)(.*$)'
    - repl: '\1{{ user }}'
    - require:
      - group: Create group for user {{ user }}
{%- endfor %}

{%- for admin in admins %}
# Add to /etc/suders.d/group_{{ admin }} file
admin_group-{{ admin }}:
  file.append:
    - name: '{{ sudo_d }}/group_{{ admin }}'
    - text: '%{{ admin }}	ALL=(root)	NOPASSWD:ALL'
    - unless:
      - 'grep -q {{ admin }} {{ sudo_d }}/group_{{ admin }}'
{%- endfor %}

{%- if logins %}
# Add to /etc/ssh/sshd_config
AddDirective-sshd:
  file.append:
    - name: '{{ sshd_cfg }}'
    - text: 'AllowGroups '
    - unless:
      - 'grep -q AllowGroups {{ sshd_cfg }}'

{%- for name in logins %}
ssh_allow_group-{{ login }}:
  cmd.script:
    - name: 'ssh_allow_group.sh "{{ name }}"'
    - source: 'salt://{{ scriptDir }}/ssh_allow_group.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - file: AddDirective-sshd
{%- endfor %}
{%- endif %}
