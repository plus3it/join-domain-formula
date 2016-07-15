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

{%- for admin in join_domain.admins %}

add local administrator - {{ admin }}:
  cmd.run:
    - name: '
      $group = [ADSI]"WinNT://$env:COMPUTERNAME/Administrators,group";
      $groupmembers = @( @( $group.Invoke("Members") ) | foreach {
        $_.GetType().InvokeMember("Name",
        "GetProperty", $null, $_, $null)
      });
      if ( $groupmembers -contains "{{ admin }}" )
      {
        "changed=no
         comment=`"[{{ admin }}] is already a local administrator.`"
         domain=`"{{ join_domain.netbios_name }}`" user=`"{{ admin }}`""
      }
      else
      {
        try
        {
          $group.Add(
            "WinNT://{{ join_domain.netbios_name }}/{{ admin }},group");
          "changed=yes
           comment=`"Added [{{ admin }}] as a local administrator.`"
           domain=`"{{ join_domain.netbios_name }}`" user=`"{{ admin }}`""
        }
        catch
        {
          throw "Failed to add [{{ admin }}] as a local administor.`n$Error[0]"
        }
      }
    '
    - shell: powershell
    - stateful: true
    - require:
      - cmd: join standalone system to domain

{%- endfor %}
