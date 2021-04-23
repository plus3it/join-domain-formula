{%- from tpldir + '/map.jinja' import join_domain with context %}

manage join domain script:
  file.managed:
    - name: {{ join_domain.script.name }}
    - source: {{ join_domain.script.source }}
    - makedirs: true

join standalone system to domain:
  cmd.run:
    - name: >-
        & "{{ join_domain.script.name }}"
        -DomainName "{{ join_domain.dns_name }}"
        -TargetOU "{{ join_domain.oupath }}"
        {%- if join_domain.get("password") %}
        -Password "{{ join_domain.password }}"
        {%- else %}
        -Key "{{ join_domain.key }}"
        -EncryptedPassword "{{ join_domain.encrypted_password }}"
        {%- endif %}
        -UserName "{{ join_domain.username }}"
        -Tries {{ join_domain.tries }}
        -ErrorAction Stop
    - shell: powershell
    - stateful: true
    - output_loglevel: quiet
    - require:
      - file: manage join domain script

{%- if join_domain.admins %}
{%- set admins = [] %}
{%- for admin in join_domain.admins %}
    {% do admins.append("'%s'" | format(admin)) %}
{%- endfor %}

manage wrapper script:
  file.managed:
    - name: {{ join_domain.wrapper.name }}
    - source: {{ join_domain.wrapper.source }}
    - makedirs: true

manage new member script:
  file.managed:
    - name: {{ join_domain.new_member.name }}
    - source: {{ join_domain.new_member.source }}
    - makedirs: true

register startup task:
  cmd.script:
    - name: salt://{{ tpldir }}/files/Register-RunOnceStartupTask.ps1
    - args: >-
        -InvokeScript "{{ join_domain.wrapper.name }}"
        -RunOnceScript "{{ join_domain.new_member.name }}"
        -Members "{{ admins | join(',') }}"
        -DomainNetBiosName {{ join_domain.netbios_name }}
    - shell: powershell
    - require:
      - file: manage wrapper script
      - file: manage new member script
      - cmd: join standalone system to domain

{%- endif %}

set dns search suffix:
  cmd.script:
    - name: salt://{{ tpldir }}/files/Set-DnsSearchSuffix.ps1
    - args: >-
        -DnsSearchSuffixes {{ join_domain.dns_name }}
        -Ec2ConfigSetDnsSuffixList {{ join_domain.ec2config }}
        -ErrorAction Stop
    - shell: powershell
    - require:
      - cmd: join standalone system to domain
