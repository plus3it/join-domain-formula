{#- Get the `tplroot` from `tpldir` #}
{%- set tplroot = tpldir.split('/')[0] %}

{%- from tplroot ~ "/map.jinja" import mapdata as sssd_data with context %}

SSSD Service Dead:
  service.dead:
    - name: sssd
    - enable: False

Remove DDNS Records:
  salt.states.ddns.absent:
    - name: "{{ join_domain.dns_name }}"
    - require:
      - service: SSSD Service Dead

{#- List of files to delete #}
{%- set files_to_delete = [
    "/etc/sssd/conf.d/{{ join_domain.netbios_name }}.conf",
    "/etc/krb5.keytab"
    # Add more file paths here if needed
] %}

{#- Loop through the list of files and create file.absent states #}
{%- for file_path in files_to_delete %}
Delete {{ file_path }}:
  salt.states.file.absent:
    - name: {{ file_path }}
    - require:
      - service: SSSD Service Dead
{%- endfor %}

Empty Kerberos Config Directory:
  salt.states.file.directory_absent:
    - name: "/etc/krb5.conf.d"
    - require:
      - service: SSSD Service Dead

Cleanup Completed:
  cmd.run:
    - name: echo "Cleanup completed."
