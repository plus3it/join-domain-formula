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
{%- from tpldir ~ '/map.jinja' import auth_config with context %}
{%- set files = tpldir ~ '/files' %}
{%- set sudo_d = '/etc/sudoers.d' %}
{%- set sshd_cfg = '/etc/ssh/sshd_config' %}

{%- for user in auth_config.users %}
# Create a group for {{ user }}, for sshd AllowGroups to work
Create group and add as member for user {{ user }}:
  group.present:
    - name: {{ user }}
    - addusers:
      - {{ user }}
{%- endfor %}

{%- for admin in auth_config.admins %}
# Replace periods in filenames for sudoers.d
{%- set append_name = admin | replace(".","_") %}
# Add to /etc/suders.d/group_{{ append_name }} file
admin_group-{{ admin }}:
  file.managed:
    - name: '{{ sudo_d }}/group_{{ append_name }}'
    - contents: '%{{ admin }}	ALL=(root)	NOPASSWD:ALL'
{%- endfor %}

{%- if auth_config.logins %}
# Add to /etc/ssh/sshd_config
AddDirective-sshd:
  file.append:
    - name: '{{ sshd_cfg }}'
    - text: 'AllowGroups '
    - unless:
      - 'grep -q AllowGroups {{ sshd_cfg }}'

{%- for name in auth_config.logins %}
ssh_allow_group-{{ name }}:
  cmd.script:
    - name: 'ssh-allow-group.sh "{{ name }}"'
    - source: 'salt://{{ files }}/ssh-allow-group.sh'
    - cwd: '/root'
    - stateful: True
    - require:
      - file: AddDirective-sshd
{%- endfor %}
{%- endif %}
