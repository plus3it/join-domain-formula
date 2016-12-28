{%- from tpldir + '/map.jinja' import join_domain with context %}

join standalone system to domain:
  cmd.run:
    - name: '
      if ( ( (Get-WmiObject Win32_ComputerSystem).partofdomain ) -eq $True )
      {
        $domain = (Get-WmiObject Win32_ComputerSystem).domain;
        if ( $domain -eq "{{ join_domain.dns_name }}" )
        {
          "changed=no comment=`"System is joined already to the correct domain
            [$domain].`" domain=$domain";
        }
        else
        {
          throw "System is joined to another domain [$domain]. To join a
            different domain, first remove it from the current domain."
        }
      }
      else
      {
        $AesObject = New-Object System.Security.Cryptography.AesCryptoServiceProvider;
        $AesObject.IV = New-Object Byte[]($AesObject.IV.Length);
        $AesObject.Key = [System.Convert]::FromBase64String("{{ join_domain.key }}");
        $EncryptedStringBytes = [System.Convert]::FromBase64String(
          "{{ join_domain.encrypted_password }}" );
        $cred = New-Object -TypeName System.Management.Automation.PSCredential
          -ArgumentList {{ join_domain.username }}, (ConvertTo-SecureString
          -String "$([System.Text.UnicodeEncoding]::Unicode.GetString(
          ($AesObject.CreateDecryptor()).TransformFinalBlock($EncryptedStringBytes,
          0, $EncryptedStringBytes.Length)))"
          -AsPlainText -Force);
    {%- if join_domain.oupath -%}
        Add-Computer -DomainName {{ join_domain.dns_name }} -Credential $cred
          -OUPath "{{ join_domain.oupath }}"
          -Options JoinWithNewName,AccountCreate -Force -ErrorAction Stop;
    {%- else -%}
        Add-Computer -DomainName {{ join_domain.dns_name }} -Credential $cred
          -Options JoinWithNewName,AccountCreate -Force -ErrorAction Stop;
    {%- endif -%}
        "changed=yes comment=`"Joined system to the domain.`"
        domain={{ join_domain.dns_name }}"
      }'
    - shell: powershell
    - stateful: true

{%- if join_domain.admins %}
{%- set admins = join_domain.admins|string|replace('[','')|replace(']','') %}

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
    - args: -InvokeScript "{{ join_domain.wrapper.name }}" -RunOnceScript "{{ join_domain.new_member.name }}" -Members {{ admins }} -DomainNetBiosName {{ join_domain.netbios_name }}
    - shell: powershell
    - require:
      - file: manage wrapper script
      - file: manage new member script
      - cmd: join standalone system to domain

{%- endif %}
