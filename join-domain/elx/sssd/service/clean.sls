{%- set tplroot = tpldir.split('/')[0] %}
{%- from tplroot ~ "./elx/sssd/config/map.jinja" import mapdata as sssd_data with context %}

SSSD Service Dead:
  service.dead:
    - name: sssd
    - enable: False
