#
# Salt state for joining an ELx host to an Active Directory
# Salt state for ensuring that Linux clients are able to update
# their client DNS entries in environments that don't support
# updating through AD-oriented DDNS capabilities.
#
#################################################################
{%- from tpldir ~ '/map.jinja' import join_domain with context %}
{%- set nsupdate_cfgdir = '/etc/nsupdate.d' %}
{%- set host_ipv4 = salt.network.get_route('192.0.0.8')['source'] %}
{%- set host_name = salt.grains.get('host') %}

install_nsupdate:
  pkg.installed:
    - allow_updates: True
    - pkgs:
      - bindutils

{{ nsupdate_cfgdir }}-present:
  file.recurse:
    - dir_mode: '0700'
    - group: 'root'
    - name: '{{ nsupdate_cfgdir }}'
    - user: 'root'

A-record_cfg:
  file.managed:
    - contents: |-
        zone {{ dns_domain }}
        server {{ ddns_server }}
        update add {{ host_name }}.{{ dns_domain }}. 3600 A {{ host_ipv4 }}
        send
    - group: 'root'
    - mode: '0600'
    - name: '{{ nsupdate_cfgdir }}/Foward.cfg'
    - selinux:
        serange: 's0'
        serole: 'object_r'
        setype: 'etc_t'
        seuser: 'system_u'
    - user: 'root'

PTR-record_cfg:
  file.managed:
    - contents: |-
        zone {{ dns_domain }}
        server {{ ddns_server }}
    - group: 'root'
    - mode: '0600'
    - name: '{{ nsupdate_cfgdir }}/Reverse.cfg'
    - selinux:
        serange: 's0'
        serole: 'object_r'
        setype: 'etc_t'
        seuser: 'system_u'
    - user: 'root'
