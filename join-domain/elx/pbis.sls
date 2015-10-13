#
# Salt state for downloading, installing and configuring PBIS,
# then joining # the instance to Active Directory
#
#################################################################

# Vars used to run the domain-join actions
{%- set join_elx = salt['pillar.get']('join-domain:linux', {}) %}
{%- set domainFqdn = join_elx.ad_domain_fqdn %}
{%- set domainShort = join_elx.ad_domain_short'] %}
{%- set domainAcct = join_elx.join_svc_acct'] %}
{%- set svcPasswdCrypt = join_elx.encrypted_password'] %}
{%- set svcPasswdUlk = join_elx.key'] %}
{%- set domainOuPath = join_elx.oupath'] %}

# Vars for getting PBIS install-media
{%- set repoHost = join_elx.repo_uri_host'] %}
{%- set repoPath = join_elx.repo_uri_root_path'] %}
{%- set pbisPkg = join_elx.package_name'] %}
{%- set pbisHash = join_elx.package_hash'] %}

# Vars for checking for previous installations
{%- set pbisBinDir = join_elx.install_bin_dir'] %}
{%- set pbisVarDir = join_elx.install_var_dir'] %}
{%- set pbisDbDir = join_elx.install_db_dir'] %}
{%- set pbisDbs = join_elx.checkFiles'] %}

{%- set pbisRpms = join_elx.connectorRpms'] %}
  
