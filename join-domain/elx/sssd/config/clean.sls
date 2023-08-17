{%- set tplroot = tpldir.split('/')[0] %}
{%- from tplroot ~ "/elx/sssd/config/map.jinja" import mapdata as sssd_data with context %}
{%- from "join-domain/elx/sssd/service/clean.sls" import SSSD_Service_Dead with context %}

{%- set join_domain = salt['grains.get']('join-domain', {}) %}

# Remove DDNS Records
ddns.absent:
  salt.states.ddns.absent:
    - name: "{{ join_domain.dns_name }}"
    - require:
      - service: {{ SSSD_Service_Dead }}

# Loop through the list of files from mapdata and create file.absent states
{%- for file_path in sssd_data.files_to_delete %}
Delete {{ file_path }}:
  file.absent:
    - name: {{ file_path }}
    - require:
      - service: {{ SSSD_Service_Dead }}
{% endfor %}

# Empty Kerberos Config Directory
file.directory_absent:
  file.directory_absent:
    - name: "/etc/krb5.conf.d"
    - require:
      - service: {{ SSSD_Service_Dead }}
