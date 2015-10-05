{%- set join_domain = salt['pillar.get']('join-domain:windows', {} %}

{%- if join_domain.oupath %}

{%- elif join_domain %}

{%- endif %}
