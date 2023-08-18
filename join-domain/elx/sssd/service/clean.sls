{%- set tplroot = tpldir.split('/')[0] %}
{%- from tplroot ~ "/elx/sssd/config/map.jinja" import mapdata as sssd_data with context %}

{% set SSSD_Service_Dead = 'sssd_dead' %}  

SSSD Service Dead:
  service.dead:
    - name: sssd
    - enable: False

{%- set 'SSSD_Service_Dead' = SSSD_Service_Dead %} 
