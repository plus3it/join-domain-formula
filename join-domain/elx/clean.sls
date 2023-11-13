{%- set join_service = salt.pillar.get(
    'join-domain:lookup:ad_connector',
    'sssd'
  )
%}

include:
  - .{{ join_service }}.clean
