#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################

# Vars used to run the domain-join actions
{%- set domainFqdn = pillar['join-domain']['ad_domain_fqdn'] %}
{%- set domainShort = pillar['join-domain']['ad_domain_short'] %}
{%- set domainAcct = pillar['join-domain']['join_svc_acct'] %}
{%- set svcPasswdCrypt = pillar['join-domain']['encrypted_password'] %}
{%- set svcPasswdUlk = pillar['join-domain']['key'] %}
{%- set domainOuPath = pillar['join-domain']['oupath'] %}

# Vars for getting PBIS install-media
{%- set repoHost = pillar['join-domain']['repo_uri_host'] %}
{%- set repoPath = pillar['join-domain']['repo_uri_root_path'] %}
{%- set centrifyPkg = pillar['join-domain']['package_name'] %}
{%- set centrifyHash = pillar['join-domain']['package_hash'] %}

# Vars for checking for previous installations
{%- set centrifyBinDir = pillar['join-domain']['install_bin_dir'] %}
{%- set centrifyVarDir = pillar['join-domain']['install_var_dir'] %}
{%- set centrifyDbDir = pillar['join-domain']['install_db_dir'] %}
{%- set centrifyDbs = pillar['join-domain']['checkFiles'] %}

{%- set centrifyRpms = pillar['join-domain']['connectorRpms'] %}
  
