{%- set ad_connector = salt['pillar.get'](
    'join-domain:lookup:ad_connector',
    'sssd'
) %}

include:
  - .openldap-client.find-collision
  - .{{ ad_connector }}
  - .auth-config
