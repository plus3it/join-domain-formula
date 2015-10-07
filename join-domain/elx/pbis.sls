#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################

# Vars used to run the domain-join actions
{%- set domainFqdn = pillar['ad_join']['ad_domain'] %}
{%- set domainAcct = pillar['ad_join']['join_svc_acct'] %}
{%- set svcPasswdCrypt = pillar['ad_join']['encrypted_password'] %}
{%- set svcPasswdUlk = pillar['ad_join']['key'] %}
{%- set domainOuPath = pillar['ad_join']['oupath'] %}

# Vars for getting PBIS install-media
{%- set repoHost = pillar['ad_join']['repo_uri_host'] %}
{%- set repoPath = pillar['ad_join']['repo_uri_root_path'] %}
{%- set pbisPkg = pillar['ad_join']['package_name'] %}
{%- set pbisHash = pillar['ad_join']['package_hash'] %}

# Vars for checking for previous installations
{%- set pbisBinDir = pillar['ad_join']['install_bin_dir'] %}
{%- set pbisVarDir = pillar['ad_join']['install_var_dir'] %}
{%- set pbisDbDir = pillar['ad_join']['install_db_dir'] %}
{%- set pbisDbs = pillar['ad_join']['checkFiles'] %}

{%- set pbisRpms = pillar['ad_join']['connectorRpms'] %}
  
