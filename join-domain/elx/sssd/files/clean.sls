{#- Get the `tplroot` from `tpldir` #}
{%- set tplroot = tpldir.split('/')[0] %}

{%- from tplroot ~ "/map.jinja" import mapdata as join_domain with context %}

Kill weekly computerObject-refresher job:
  file.absent:
    - name: '/etc/cron.weekly/refreshComputerObject.sh'

Delete /etc/sssd/conf.d/{{ join_domain.netbios_name }}.conf:
  file.absent:
    - name: '/etc/sssd/conf.d/{{ join_domain.netbios_name }}.conf'
