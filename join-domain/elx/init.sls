{%- set join_type = salt['pillar.get']('join-domain:lookup:ad_connector') %}

include:
  - join-domain.elx.{{ join_type }}
  - join-domain.elx.{{ join_type }}-grpCfg
