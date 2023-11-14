{#- Get the `tplroot` from `tpldir` #}
{%- set tplroot = tpldir.split('/')[0] %}

{%- from tplroot ~ "/map.jinja" import mapdata as join_domain with context %}

Check Realm Status - {{ join_domain.dns_name }}:
  cmd.run:
    - name: '/sbin/realm list | grep -q ''^{{ join_domain.dns_name }}'''

Leave Realm - {{ join_domain.dns_name }}:
  cmd.run:
    - name: '/sbin/realm leave {{ join_domain.dns_name }}'
    - require:
      - cmd: 'Check Realm Status - {{ join_domain.dns_name }}'

authselect Disable 'with-mkhomedir':
  cmd.run:
    - name: 'authselect disable-feature with-mkhomedir'
    - require:
      - cmd: 'Leave Realm - {{ join_domain.dns_name }}'
