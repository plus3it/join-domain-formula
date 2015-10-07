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
{%- set sssdPkg = pillar['ad_join']['package_name'] %}
{%- set sssdHash = pillar['ad_join']['package_hash'] %}

# Vars for checking for previous installations
{%- set sssdBinDir = pillar['ad_join']['install_bin_dir'] %}
{%- set sssdVarDir = pillar['ad_join']['install_var_dir'] %}
{%- set sssdDbDir = pillar['ad_join']['install_db_dir'] %}
{%- set sssdDbs = pillar['ad_join']['checkFiles'] %}

{%- set sssdRpms = pillar['ad_join']['connectorRpms'] %}
  
