#
# Salt state for adding Active Directory groups to the sudoers
# and sshd_configurations:
# * Members of sudoer_groups will be added to the AllowGroups
#   parameter in /etc/ssh/sshd_config
# * Members of sudoer_groups will be added to group-file(s)
#   placed in /etc/sudoers.d
#
#################################################################

