{% set connect_default = {
    7: 'pbis',
    8: 'sssd',
    9: 'sssd'
} %}

{%- set ad_connector = salt['pillar.get'](
    'join-domain:lookup:ad_connector',
    salt.grains.filter_by(connect_default, grain='osmajorrelease')
) %}

include:
  - .openldap-client.find-collision
  - .{{ ad_connector }}
  - .auth-config
