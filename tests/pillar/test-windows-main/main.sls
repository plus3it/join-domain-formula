join-domain:

  lookup:
    ##################################
    # Windows-specific pillar settings
    ##################################

    # Required Settings
    dns_name: example.com
    netbios_name: EXAMPLE
    username: notreal
    encrypted_password: 'pMd2KSkdJVTfSsBTxqwSEVwmDkQITTqaz6HVMfOVOQNlehNIMDV44SSGEqNy7Us0'
    key: '0noctXEGqVxbVSMr+THyEyOCUcBHjJE1HBWDX+s4XNk='

    # Optional Settings
    oupath: CN=Computers,DC=example,DC=com
    admin_users:
      - admin1
      - admin2
    admin_groups:
      - admingroup1
      - admingroup2
