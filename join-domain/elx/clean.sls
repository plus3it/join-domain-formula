{%- join_service = salt.pillar.get('join-domain:lookup:ad_connector', 'sssd') %}

include:
  - elx.{{ join_service }}.clean
