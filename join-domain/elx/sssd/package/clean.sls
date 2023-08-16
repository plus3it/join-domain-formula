{%- import "./elx/sssd/service/clean.sls" as service_clean %}

{%- for pkg_name in pkg_list %}
Uninstall {{ pkg_name }}:
  pkg.removed:
    - name: {{ pkg_name }}
    - require:
      - service: {{ service_clean.SSSDServiceDead.name }}
{%- endfor %}
