{%- set join_domain = salt['pillar.get']('join-domain:windows', {} %}

{%- if join_domain.oupath %}

join standalone system to domain in specified ou:
  cmd.run:
    - name: '
      $cred = New-Object -TypeName System.Management.Automation.PSCredential
      -ArgumentList {{ join_domain.username }}, (ConvertTo-SecureString 
      -String {{ join_domain.encrypted_password }} 
      -Key ([Byte[]] "{{ join_domain.key }}".split(",")));
      Add-Computer -DomainName {{ join_domain.domain_name }} -Credential $cred
      -Force -OUPath {{ join_domain.oupath }}'
    - shell: powershell
    - unless: '
      try 
      { 
        return "System is joined already to domain named [$(([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).Name)]."
      }
      catch
      {
        throw 'System is not yet joined to a domain.'
      }'

{%- elif join_domain %}

join standalone system to domain in default ou:
  cmd.run:
    - name: '
      $cred = New-Object -TypeName System.Management.Automation.PSCredential
      -ArgumentList {{ join_domain.username }}, (ConvertTo-SecureString 
      -String {{ join_domain.encrypted_password }} 
      -Key ([Byte[]] "{{ join_domain.key }}".split(",")));
      Add-Computer -DomainName {{ join_domain.domain_name }} -Credential $cred
      -Force'
    - shell: powershell
    - unless: '
      try 
      { 
        return "System is joined already to domain named [$(([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).Name)]."
      }
      catch
      {
        throw "System is not yet joined to a domain."
      }'
{%- endif %}
