#
# Salt state for removing an ELx host from an Active Directory
# domain using the OS-native tools, `sssd` and `realmd`
#
#################################################################

include:
  - .config.clean
  - .files.clean
  - .service.clean
