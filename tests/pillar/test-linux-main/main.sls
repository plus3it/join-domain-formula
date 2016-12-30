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
    ad_connector: pbis

    # Programable path-elements for retrieving the PBIS self-installing
    # archive file.
    repo_uri_host: 'https://host/repo'
    repo_uri_root_path: 'beyond-trust/linux/pbis'

    # Name of installer and hash-file to download
    package_name: 'pbis-open-8.5.0.153.linux.x86_64.rpm.sh'
    package_hash: 'pbis-open-8.5.0.153.linux.x86_64.rpm.sh.SHA512'

    # Directories where PBIS is installed to the system
    #install_bin_dir: '/opt/pbis'
    #install_var_dir: '/var/lib/pbis'
    #install_db_dir: '/var/lib/pbis/db'

    # List of RPMs to look for
    #connector_rpms:
    #  - 'pbis-open-legacy'
    #  - 'pbis-open'
    #  - 'pbis-open-devel'
    #  - 'pbis-open-gui'
    #  - 'pbis-open-upgrade'

    # List of critical files to look for
    #check_files:
    #  - 'registry.db'
    #  - 'sam.db'
    #  - 'lwi_events.db'
    #  - 'lsass-adcache.filedb.FQDN'
