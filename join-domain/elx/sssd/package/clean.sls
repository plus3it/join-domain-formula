{% include "service/clean.sls" %}

{%- for pkg_name in pkg_list %}
Uninstall {{ pkg_name }}:
  pkg.removed:
    - name: {{ pkg_name }}
    - require:
      - service: SSSD Service Dead
{%- endfor %}