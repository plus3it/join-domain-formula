{%- set tplroot = tpldir.split('/')[0] %}
{%- from tplroot ~ ".join-domain.elx.sssd.config.map" import mapdata as sssd_data with context %}

SSSD Service Dead:
  service.dead:
    - name: sssd
    - enable: False
