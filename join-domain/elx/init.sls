{%- set join_domain = salt['pillar.get']('join-domain:linux', {}) %}

{%- if join_domain.oupath %}

{%- elif join_domain %}

{%- endif %}
