#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################

# Vars used to run the domain-join actions
{%- set domainFqdn = pillar['join-domain']['lookup']['dns_name'] %}
{%- set domainShort = pillar['join-domain']['lookup']['netbios_name'] %}
{%- set domainAcct = pillar['join-domain']['lookup']['username'] %}
{%- if join_domain.get("password") %}
{%- set password = pillar['join-domain']['lookup']['password'] %}
{%- else %}
{%- set svcPasswdCrypt = pillar['join-domain']['lookup']['encrypted_password'] %}
{%- set svcPasswdUlk = pillar['join-domain']['lookup']['key'] %}
{%- endif %}
{%- set domainOuPath = pillar['join-domain']['lookup']['oupath'] %}

# Vars for getting PBIS install-media
{%- set repoHost = pillar['join-domain']['lookup']['repo_uri_host'] %}
{%- set repoPath = pillar['join-domain']['lookup']['repo_uri_root_path'] %}
{%- set winbindPkg = pillar['join-domain']['lookup']['package_name'] %}
{%- set winbindHash = pillar['join-domain']['lookup']['package_hash'] %}

# Vars for checking for previous installations
{%- set winbindBinDir = pillar['join-domain']['lookup']['install_bin_dir'] %}
{%- set winbindVarDir = pillar['join-domain']['lookup']['install_var_dir'] %}
{%- set winbindDbDir = pillar['join-domain']['lookup']['install_db_dir'] %}
{%- set winbindDbs = pillar['join-domain']['lookup']['checkFiles'] %}

{%- set winbindRpms = pillar['join-domain']['lookup']['connectorRpms'] %}
