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
Set of parameters used for joining a AD-client to its domain
- *`ad_domain_fqdn`*: The fully-qualified DNS name for the AD domain (e.g., 'aws.lab')
- *`ad_domain_short`*: The "short" or NETBIOS name for the AD domain (e.g., 'AWSLAB')
- *`join_svc_acct`*: The account name used to perform automated joins of clients to the AD domain (e.g., 'svc_domjoin_aws'). It is recommended to create a service account that has the bare-minimum permissions necessary to (re)join a client to an AD domain
- *`oupath`*: (OPTIONAL) where in the AD-hierarchy to create the computer account. Leave blank if joining to the default OU or provide the "/"-delimited path to the OU the computer account will be housed within
- *`encrypted_password`*: This is an encrypted representation of the `join_svc_acct` service account's password. Use `openssl`'s `aes-256-ecb` encryption option to create the encrypted-string.
- *`key`*: The string passed to `openssl` to encrypt/decrypt the `join_svc_acct` service account's password.

### Programable path-elements for retrieving the PBIS self-installing archive file.
These two values are used to determine where to locate the AD-client's installer software. HTTP is the expected (read "tested") download method. Other download methods may also work (but have not been tested).
- repo_uri_host: 'http://S3BUCKET.F.Q.D.N'
- repo_uri_root_path: 'beyond-trust/linux/pbis'
  
### Name of installer and hash-file to download
Name of the installation package to download from the repo. The installer staging-routines expect the downloaded file to have a signature file. The signature file is used to ensure that the package download was not corrupted in transit.
- package_name: 'pbis-open-8.3.0.3287.linux.x86_64.rpm.sh'
- package_hash: 'pbis-open-8.3.0.3287.linux.x86_64.rpm.sh.SHA512'
  
### Tool used for joining client to AD domain.
There are a number of third-party and native options available for joining Linux clients to AD domains. This parameter is used to tell the formula which client-behavior should be used. Expected valid values will be 'centrify', 'pbis', 'quest', 'sssd' and 'winbind'. As of this version of the formula, only 'pbis' is supported.
-  ad_connector: 'pbis'
  
### Directories where AD-client utilities are installed to the system
List of directories associated with the chosen `ad_connector` software/method.
- install_bin_dir: '/opt/pbis'
- install_var_dir: '/var/lib/pbis'
- install_db_dir: '/var/lib/pbis/db'
  
### List of RPMs to look for
This is a list of RPMs associated with the AD client. For some client-types, the formula will evaluate the presence/version of these RPMs to help determine whether the requested install should be performed as a new install or an upgrade (where possible).
- connectorRpms:
  - RPM1
  - RPM2
  - ...
  - RPMn

###List of critical files to look for
This is a list of critical files - typically configuration files - that the formula will look for to help determine whether the requested install should be performed as a new install or an upgrade (where possible).
- checkFiles:
  - CFG1
  - CFG2
  - ...
  - CFGn
