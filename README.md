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
Information used to join host to target AD domain
- ad_domain_fqdn: 'aws.lab'
- ad_domain_short: 'AWSLAB'
- join_svc_acct: 'svc_domjoin_aws'
- oupath:
- encrypted_password: 'U2FsdGVkX18ThTf5km4IcWfAlAgbVwPn539BjI6fEpQmXa0B30gVRIK2qya9zPwh'
- key: 'Unlock'

Programable path-elements for retrieving the PBIS self-installing archive file.
- repo_uri_host: 'http://S3BUCKET.F.Q.D.N'
- repo_uri_root_path: 'beyond-trust/linux/pbis'
  
Name of installer and hash-file to download
- package_name: 'pbis-open-8.3.0.3287.linux.x86_64.rpm.sh'
- package_hash: 'pbis-open-8.3.0.3287.linux.x86_64.rpm.sh.SHA512'
  
Directories where AD-client utilities are installed to the system
- install_bin_dir: '/opt/pbis'
- install_var_dir: '/var/lib/pbis'
- install_db_dir: '/var/lib/pbis/db'
  
Tool used for joining client to AD domain. Expected valid values will be 'centrify', 'pbis', 'quest', 'sssd' and 'winbind' (as of this version, only 'pbis' is supported).
-  ad_connector: 'pbis'
  
List of RPMs to look for
- connectorRpms:
  - RPM1
  - RPM2
  - ...
  - RPMn

List of critical files to look for
- checkFiles:
  - CFG1
  - CFG2
  - ...
  - CFGn
