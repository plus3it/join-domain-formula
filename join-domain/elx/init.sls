{%- set ad_connector = salt['pillar.get'](
    'join-domain:lookup:ad_connector',
    'pbis'
) %}

include:
  - .{{ ad_connector }}
  - .auth-config
