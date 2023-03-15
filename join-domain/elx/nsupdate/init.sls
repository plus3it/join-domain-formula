#
# Salt state for joining an ELx host to an Active Directory
# Salt state for ensuring that Linux clients are able to update
# their client DNS entries in environments that don't support
# updating through AD-oriented DDNS capabilities.
#
#################################################################
{%- set join_domain = salt.pillar.get('join-domain:lookup', {}) %}
{%- set host_ipv4 = salt.network.get_route('192.0.0.8')['source'] %}
{%- set host_name = salt.grains.get('host') %}
{%- set rev_ipv4 = host_ipv4.split('.') | reverse | join('.') %}
{%- set rev_zone = host_ipv4.split('.')[0:3] | reverse | join('.') %}

Install_dnspython:
  pip.installed:
    - name: dnspython
    - reload_modules: True

DDNS_Forward:
  ddns.present:
    - data: '{{ host_ipv4 }}'
    - nameserver: '{{ join_domain.ddns_server }}'
    - name: '{{ host_name }}.{{ join_domain.dns_name }}.'
    - rdtype: 'A'
    - replace: True
    - require:
      - pip: 'Install_dnspython'
    - ttl: '7200'
    - zone: '{{ join_domain.dns_name }}'

DDNS_Reverse:
  ddns.present:
    - data: '{{ host_name }}.{{ join_domain.dns_name }}.'
    - name: '{{ rev_ipv4 }}.in-addr.arpa.'
    - nameserver: '{{ join_domain.ddns_server }}'
    - rdtype: 'PTR'
    - replace: True
    - require:
      - pip: 'Install_dnspython'
    - ttl: '7200'
    - zone: '{{ rev_zone }}.in-addr.arpa.'
