join-domain:

  lookup:
    ################################
    # Linux-specific pillar settings
    ################################

    # Required domain-specific settings
    dns_name: example.com
    netbios_name: EXAMPLE
    username: notreal
    encrypted_password: 'U2FsdGVkX1+bRR+1ScvICa0tZX2WVWZ0Q0M/mmzlTBWwbhvnUrV0ACzUglAqpA/+'
    key: bLRzZF8m5U

    # Optional domain-specific settings
    oupath: CN=Computers,DC=example,DC=com
    admin_users:
      - admin1
      - admin2
    admin_groups:
      - admingroup1
      - admingroup2
    login_users:
      - user1
      - user2
    login_groups:
      - usergroup1
      - usergroup2

    # AD-connector Tool
    ad_connector: sssd
