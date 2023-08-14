{% include "salt://join-domain/join-domain/elx/sssd/map.jinja" ignore missing %}
{% from "map.jinja" import mapdata as sssd_data with context %}

SSSD Service Dead:
  service.dead:
    - name: sssd
    - enable: False
