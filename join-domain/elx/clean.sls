{%- join_service = salt.pillar.get('join-domain:lookup:ad_connector', 'sssd') %}
include:
  {%- if join_service = 'sssd' %}
  - elx.sssd.service.clean
  - elx.sssd.package.clean
  {%- endif %}
