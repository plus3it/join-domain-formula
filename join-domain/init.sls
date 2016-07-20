{%- if 'join-domain' in pillar %}

{%- set os_family = salt['grains.get']('os_family') %}

{%- if os_family == 'Windows' %}

include:
  - join-domain.windows

{%- elif os_family == 'RedHat' %}

include:
  - join-domain.elx

{%- endif %}
{%- endif %}
