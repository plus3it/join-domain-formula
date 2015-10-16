#
# Salt state for adding Active Directory groups to the sudoers
# and sshd_configurations:
# * Members of sudoer_groups will be added to the AllowGroups
#   parameter in /etc/ssh/sshd_config
# * Members of sudoer_groups will be added to group-file(s)
#   placed in /etc/sudoers.d
#
#################################################################

{%- set adm_list = salt['pillar.get']('join-domain:linux:sudoer_groups', {}) %}
{%- set sudo_d = '/etc/sudoers.d' %}

# Add to /etc/suders.d/group_XXX file
{%- for sudoer_group in adm_list %}
sudoer_group-{{ sudoer_group }}:
  file.append:
    - name: '{{ sudo_d }}/group_{{ sudoer_group }}'
    - text: '%{{ sudoer_group }}	ALL=(root)	NOPASSWD:ALL'
    - unless:
      - 'grep -q {{ sudoer_group }} {{ sudo_d }}/group_{{ sudoer_group }}'
{%- endfor %}
