{%- set join_type = salt['pillar.get']('join-domain:linux:ad_connector') %}

include:
  - join-domain.elx.{{ join_type }}
  - join-domain.elx.{{ join_type }}-grpCfg
