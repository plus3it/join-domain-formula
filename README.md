[![Build Status](https://travis-ci.org/lorengordon/join-domain-formula.svg?branch=master)](https://travis-ci.org/lorengordon/join-domain-formula)


# join-domain-formula
This project uses a [SaltStack](http://saltstack.com/community/) [formula](https://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html) to automate the joining of a Windows or Linux system to an Active Directory (or compatible) domain.

This formula has been tested against Windows Server 2012 and Enterprise Linux 6 derivatives (Red Hat, CentOS, Scientific Linux, etc.)

This formula uses data externalized via the SaltStack "[Pillar](https://docs.saltstack.com/en/latest/topics/pillar/)" feature. This formula expects the following data be present within the supporting Pillar:

## windows:
- domain_name:
- username:
- encrypted_password:
- key:
- oupath:

## linux:
The following parameters are usde to join a Linux client to Active Directory. See the 'pillar.example' file for pillar-data structuring.

### Information used to join host to target AD domain
- ad_domain_fqdn: The fully-qualified DNS name for the AD domain (e.g., 'aws.lab')
- ad_domain_short: The "short" or NETBIOS name for the AD domain (e.g., 'AWSLAB')
- join_svc_acct: The account name used to perform automated joins of clients to the AD domain (e.g., 'svc_domjoin_aws'). It is recommended to create a service account that has the bare-minimum permissions necessary to (re)join a client to an AD domain
- oupath: (OPTIONAL) where in the AD-hierarchy to create the computer account. Leave blank if joining to the default OU or provide the "/"-delimited path to the OU the computer account will be housed within
- encrypted_password: This is an encrypted representation of the `join_svc_acct` service account's password. Use `openssl`'s `aes-256-ecb` encryption option to create the encrypted-string.
- key: The string passed to `openssl` to encrypt/decrypt the `join_svc_acct` service account's password.

### Programable path-elements for retrieving the PBIS self-installing archive file.
- repo_uri_host: 'http://S3BUCKET.F.Q.D.N'
- repo_uri_root_path: 'beyond-trust/linux/pbis'
  
### Name of installer and hash-file to download
- package_name: 'pbis-open-8.3.0.3287.linux.x86_64.rpm.sh'
- package_hash: 'pbis-open-8.3.0.3287.linux.x86_64.rpm.sh.SHA512'
  
### Directories where AD-client utilities are installed to the system
- install_bin_dir: '/opt/pbis'
- install_var_dir: '/var/lib/pbis'
- install_db_dir: '/var/lib/pbis/db'
  
### Tool used for joining client to AD domain.
Expected valid values will be 'centrify', 'pbis', 'quest', 'sssd' and 'winbind'. As of this version of the formula, only 'pbis' is supported.
-  ad_connector: 'pbis'
  
### List of RPMs to look for
- connectorRpms:
  - RPM1
  - RPM2
  - ...
  - RPMn

###List of critical files to look for
- checkFiles:
  - CFG1
  - CFG2
  - ...
  - CFGn
