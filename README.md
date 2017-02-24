[![Travis Build Status](https://travis-ci.org/plus3it/join-domain-formula.svg?branch=master)](https://travis-ci.org/plus3it/join-domain-formula)
[![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/plus3it/join-domain-formula?branch=master&svg=true)](https://ci.appveyor.com/project/plus3it/join-domain-formula)

# join-domain-formula

This project uses a [SaltStack](http://saltstack.com/community/) [formula](https://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html)
to automate the joining of a Windows or Linux system to an Active Directory (or
compatible) domain.

This formula has been tested against Windows Server 2012 and Enterprise Linux
6 derivatives (Red Hat, CentOS, Scientific Linux, etc.)

This formula uses data externalized via the SaltStack "[Pillar](https://docs.saltstack.com/en/latest/topics/pillar/)"
feature. See the sections below for the data required to be present within the
supporting pillar.

## join-domain:windows

```yaml
join-domain:
  windows:
    dns_name:
    netbios_name:
    username:
    encrypted_password:
    key:
    oupath:
    admin_users:
    admin_groups:
```

### Generating `key` and `encrypted_password` for Windows

For Windows systems, to generate the `key` and the `encrypted_password` pillar
parameters, use the code snippet below:

```powershell
$String = 'Super secure password'
$StringBytes = [System.Text.UnicodeEncoding]::Unicode.GetBytes($String)
$AesObject = New-Object System.Security.Cryptography.AesCryptoServiceProvider
$AesObject.IV = New-Object Byte[]($AesObject.IV.Length)
$AesObject.GenerateKey()
$KeyBase64 = [System.Convert]::ToBase64String($AesObject.Key)
$EncryptedStringBytes = ($AesObject.CreateEncryptor()).TransformFinalBlock($StringBytes, 0, $StringBytes.Length)
$EncryptedStringBase64 = [System.Convert]::ToBase64String($EncryptedStringBytes)
# Save KeyBase64 in pillar as `key`
"key = $KeyBase64"
# Save EncryptedStringBase64 in pillar as `encrypted_password`
"encrypted_password = $EncryptedStringBase64"
```

## join-domain:linux

The following parameters are usde to join a Linux client to Active Directory.
See the [pillar.example](pillar.example) file for pillar-data structuring.

### Information used to join host to target AD domain

Set of parameters used for joining a AD-client to its domain:

-   *`ad_domain_fqdn`*: The fully-qualified DNS name for the AD domain (e.g.,
    'aws.lab')

-   *`ad_domain_short`*: The "short" or NETBIOS name for the AD domain (e.g.,
    'AWSLAB')

-   *`join_svc_acct`*: The account name used to perform automated joins of
    clients to the AD domain (e.g., 'svc_domjoin_aws'). It is recommended to
    create a service account that has the bare-minimum permissions necessary to
    (re)join a client to an AD domain.

-   *`oupath`*: (OPTIONAL) where in the AD-hierarchy to create the computer
    account. Leave blank if joining to the default OU or provide the
    "/"-delimited path to the OU the computer account will be housed within.

-   *`encrypted_password`*: This is an encrypted representation of the
    `join_svc_acct` service account's password. Use `openssl`'s `aes-256-cbc`
    encryption option to create the encrypted-string.

-   *`key`*: The string passed to `openssl` to encrypt/decrypt the
    `join_svc_acct` service account's password.

### Settings for the URI path-elements to the PBIS installer

These two values are used to determine where to locate the AD-client's
installer software. HTTP is the expected (read "tested") download method. Other
download methods may also work (but have not been tested).

-   *`repo_uri_host`*: '<http://S3BUCKET.F.Q.D.N>'
-   *`repo_uri_root_path`*: 'beyond-trust/linux/pbis'

### Name of installer and hash-file to download

Name of the installation package to download from the repo. The installer
staging-routines expect the downloaded file to have a signature file. The
signature file is used to ensure that the package download was not corrupted
in transit.

-   *`package_name`*: 'pbis-open-8.3.0.3287.linux.x86_64.rpm.sh'
-   *`package_hash`*: 'pbis-open-8.3.0.3287.linux.x86_64.rpm.sh.SHA512'

### Tool used for joining client to AD domain

There are a number of third-party and native options available for joining
Linux clients to AD domains. This parameter is used to tell the formula which
client-behavior should be used. Expected valid values will be 'centrify',
'pbis', 'quest', 'sssd' and 'winbind'. As of this version of the formula,
only 'pbis' is supported.

-   *` ad_connector`*: (e.g., 'pbis')

### Directories where AD-client utilities are installed to the system

List of directories associated with the chosen `ad_connector` software/method.

- *`install_bin_dir`*: Primary installation-directory for the
connector-software (e.g., `/opt/pbis`)

- *`install_var_dir`*: Primary directory for `var`-style
connector-software files (e.g. `/var/lib/pbis`)

- *`install_db_dir`*: Primary directory hosting connector-software's
cache-databases (e.g., `/var/lib/pbis/db`)

### List of RPMs to look for

This is a list of RPMs associated with the AD client. For some client-types,
the formula will evaluate the presence/version of these RPMs to help determine
whether the requested install should be performed as a new install or an
upgrade (where possible).

- *`connectorRpms`*:

  - RPM1
  - RPM2
  - ...
  - RPMn

### List of critical files to look for

This is a list of critical files - typically configuration files - that the
formula will look for to help determine whether the requested install should
be performed as a new install or an upgrade (where possible).

- *`checkFiles`*:

  - CFG1
  - CFG2
  - ...
  - CFGn

### Generating `key` and `encrypted_password` for Linux

The Linux portions of the join-domain-formula make use of a reversible, AES
256-bit ECB-encrypted string to store password data with a Salt pillar. To
create the reversible, crypted string, you need three things:

- The `openssl` tools
- The password of the domain-join account
- A semi-random string to use as the lock/unlock key for the encrypted string.

The lock/unlock key can be either manually or automatically generated. A good
method for automatically generating the key is to execute something similar to
`(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-10};echo )`. This might give
you an output similar to `F_6ln9jV3X`

Once the domain-join account's password and the lock/unlock key are available,
use `openssl`'s `enc` functionality to generate the reversible crypt-sting via
a method similar to the following.

```bash
$ echo "MyP@ssw*rd5tr1ng" | \
   openssl enc -aes-256-cbc -md sha256 -a -e -salt -pass pass:"F_6ln9jV3X"
U2FsdGVkX19pOx6FMnowkQ9vVGmHPuL5xWFwY5+EnB7Wy4rYze5HDmSZoTitwZDO
```

After generating the crypt-string, verify its reversibility by doing something
similar to the following:

```bash
echo "U2FsdGVkX19pOx6FMnowkQ9vVGmHPuL5xWFwY5+EnB7Wy4rYze5HDmSZoTitwZDO" | \
   openssl enc -aes-256-cbc -md sha256 -a -d -salt -pass pass:"F_6ln9jV3X"
MyP@ssw*rd5tr1ng
```

After verification, place the crypt-string and its lock/unlock string into the
appropriate Pillar fields.
