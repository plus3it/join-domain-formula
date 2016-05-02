{%- set join_domain = salt['pillar.get']('join-domain:windows', {}) %}

{%- if join_domain %}

{%- do join_domain.update(salt['grains.get']('join-domain', {})) %}

join standalone system to domain:
  cmd.run:
    - name: '
      if ( ( (Get-WmiObject Win32_ComputerSystem).partofdomain ) -eq $True )
      {
        $domain = (Get-WmiObject Win32_ComputerSystem).domain;
        if ( $domain -eq "{{ join_domain.domain_name }}" )
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
        Add-Computer -DomainName {{ join_domain.domain_name }} -Credential $cred
          -OUPath "{{ join_domain.oupath }}"
          -Options JoinWithNewName,AccountCreate -Force -ErrorAction Stop;
    {%- else -%}
        Add-Computer -DomainName {{ join_domain.domain_name }} -Credential $cred
          -Options JoinWithNewName,AccountCreate -Force -ErrorAction Stop;
    {%- endif -%}
        "changed=yes comment=`"Joined system to the domain.`"
        domain={{ join_domain.domain_name }}"
      }'
    - shell: powershell
    - stateful: true

{%- endif %}
