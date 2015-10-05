{%- set os_family = salt['grains.get']('os_family') %}

{%- if os_family is 'Windows' %}

include:
  - join-domain.windows

{%- elif os_family is 'RedHat' %}

include:
  - join-domain.elx

{%- endif %}
