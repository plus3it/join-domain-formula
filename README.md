[![Travis Build Status](https://travis-ci.org/plus3it/join-domain-formula.svg?branch=master)](https://travis-ci.org/plus3it/join-domain-formula)
[![AppVeyor Build Status](https://ci.appveyor.com/api/projects/status/github/plus3it/join-domain-formula?branch=master&svg=true)](https://ci.appveyor.com/project/plus3it/join-domain-formula)

# join-domain-formula

This project uses a [SaltStack](http://saltstack.com/community/) [formula](https://docs.saltstack.com/en/latest/topics/development/conventions/formulas.html)
to automate the joining of a Windows or Linux system to an Active Directory (or
compatible) domain.

This formula has been tested against Windows Server 2012/2016 and Enterprise Linux
6/7 derivatives (Red Hat, CentOS, Scientific Linux, etc.)

This formula uses data externalized via the SaltStack "[Pillar](https://docs.saltstack.com/en/latest/topics/pillar/)"
feature. See the sections below for the data required to be present within the
supporting pillar.

## join-domain windows

```yaml
join-domain:
  lookup:
    dns_name:
    netbios_name:
    username:

    # Mutually Exclusive Required Settings
    encrypted_password:
    key:
    # or
    password:

    oupath:
    admin_users:
    admin_groups:
    ec2config:
    tries:
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

After generating the encrypted password, verify its reversibility by using the code snippet below:

```powershell
$AesObject = New-Object System.Security.Cryptography.AesCryptoServiceProvider
$AesObject.IV = New-Object Byte[]($AesObject.IV.Length)
$AesObject.Key = [System.Convert]::FromBase64String($KeyBase64)
$EncryptedStringBytes = [System.Convert]::FromBase64String($EncryptedStringBase64)
$UnencryptedString = [System.Text.UnicodeEncoding]::Unicode.GetString(($AesObject.CreateDecryptor()).TransformFinalBlock($EncryptedStringBytes, 0, $EncryptedStringBytes.Length))
"unencrypted_password = $UnencryptedString"
```

Output of verification should display:

```powershell
unecrypted_password = Super secure password
```

### Permissions required to join AD Domain

The following are the permissions required for the service account used to join
computer clients to the AD domain:

| Permission | Applies to |
|:------:|:-:|
| Create/delete computer objects | This object and all descendant objects |
| Validated write to DNS hostname | Descendant Computer objects |
| Validated write to service principal name | Descendant Computer objects |
| Write Description | Descendant Computer objects |
| Write msDS-SupportedEncryptionTypes | Descendant Computer objects |
| Write operating system | Descendant Computer objects |
| Write operating system version | Descendant Computer objects |
| Write operating system service pack | Descendant Computer objects |
| Write operating system hot fix | Descendant Computer objects |
| Write public information | Descendant Computer objects |
| Write servicePrincipalName | Descendant Computer objects |
| Read/Write account restrictions | Descendant Computer objects |
| Read all properties | Descendant Computer objects |

## join-domain:linux

The following parameters are used to join a Linux client to Active Directory.
See the [pillar.example](pillar.example) file for pillar-data structuring.

### Information used to join host to target AD domain

Set of parameters used for joining a AD-client to its domain:

-   *`dns_name`*: The fully-qualified DNS name for the AD domain (e.g.,
    'aws.lab')

-   *`ad_site_name`*: (OPTIONAL) The logical name of an Active Directory Sites
    and Services [site](https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/plan/site-functions)
    to query for domain-controllers.

-   *`netbios_name`*: The "short" or NETBIOS name for the AD domain (e.g.,
    'AWSLAB')

-   *`username`*: The account name used to perform automated joins of
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

### Information used configure domain-joined client's behvior

-   *`admin_users`*: (OPTIONAL) List of users to add to the sudoers system
-   *`admin_groups`*: (OPTIONAL) List of groups to add to the sudoers system
-   *`login_users`*: (OPTIONAL) List of users to add to SSH daemon's `AllowUsers`
    list.  Note: all `admin_users` are automatically included in this list.
-   *`login_groups`*: (OPTIONAL) List of groups to add to SSH daemon's
    `AllowGroups` list. Note: (OPTIONAL)all `admin_groups` are automatically
    included in this list.
-   *`trusted_domains`*: (OPTIONAL) List of domains (within a multi-domin
    forest) to trust

### Settings for the URI path-elements to the PBIS installer

These two values are used to determine where to locate the AD-client's
installer software. HTTP is the expected (read "tested") download method. Other
download methods may also work (but have not been tested).

-   *`connector_rpms`*: Top-level search-key for PBIS-related elements.
    Remaining keys in this block are sub-keys of this key.
-   *`pbis-open`*: URL of the `pbis-open` RPM
-   *`pbis-open-devel`*: URL of the `pbis-open-devel` RPM (rarely used)
-   *`pbis-open-gui`*: URL of the `pbis-open-gui` RPM (rarely used)
-   *`pbis-open-legacy`*: URL of the `pbis-open-legacy` RPM (infrequently used)
-   *`pbis-open-upgrade`*: URL of the `pbis-open-upgrade` RPM

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
$ echo 'MyP@ssw*rd5tr1ng' | \
  openssl enc -aes-256-cbc -md sha256 -a -e -salt -pass pass:'F_6ln9jV3X'
U2FsdGVkX19pOx6FMnowkQ9vVGmHPuL5xWFwY5+EnB7Wy4rYze5HDmSZoTitwZDO
```

After generating the crypt-string, verify its reversibility by doing something
similar to the following:

```bash
echo 'U2FsdGVkX19pOx6FMnowkQ9vVGmHPuL5xWFwY5+EnB7Wy4rYze5HDmSZoTitwZDO' | \
  openssl enc -aes-256-cbc -md sha256 -a -d -salt -pass pass:'F_6ln9jV3X'
MyP@ssw*rd5tr1ng
```

After verification, place the crypt-string and its lock/unlock string into the
appropriate Pillar fields.
