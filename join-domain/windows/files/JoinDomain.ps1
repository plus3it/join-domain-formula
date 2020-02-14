#Borrowed largely from: https://github.com/jformacek/S.DS.P/blob/master/S.DS.P.psm1

[CmdLetBinding()]
Param(
    [parameter(Mandatory = $true)]
    [String]
        #FQDN of the Domain to search.
    $DomainName,

    [Parameter(Mandatory=$false,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [String]
        #OU to place the computer object
    $TargetOU = "null",

    [parameter(Mandatory = $true)]
    [String]
        #Username of account used to domain join the target computer
    $UserName,

    [parameter(Mandatory = $true, ParameterSetName = 'EncryptedPassword')]
    [String]
        #Key used to decrypt the join domain key
    $Key,

    [parameter(Mandatory = $true, ParameterSetName = 'EncryptedPassword')]
    [String]
        #Encrypted join domain password
    $EncryptedPassword,

    [parameter(Mandatory = $true, ParameterSetName = 'Password')]
    [String]
        #Unencrypted join domain password
    $Password,

    [parameter(Mandatory = $false)]
    [String]
        #Number of times to attempt the domain join
    $Tries = 3
    )

Add-Type @'
public enum EncryptionType
{
    None=0,
    Kerberos,
    SSL
}
'@
Add-Type -AssemblyName System.DirectoryServices.Protocols

Function Get-LdapConnection
{
    Param(
        [parameter(Mandatory = $false)]
        [String]
            #LDAP server name
            #Default: Domain Controller of current domain
        $LdapServer=[String]::Empty,

        [parameter(Mandatory = $false)]
        [Int32]
            #LDAP server port
            #Default: 389
        $Port=389,

        [parameter(Mandatory = $false)]
        [System.Net.NetworkCredential]
            #Use different credentials when connecting
        $Credential=$null,

        [parameter(Mandatory = $false)]
        [EncryptionType]
            #Type of encryption to use.
        $EncryptionType="None",

        [Switch]
            #enable support for Fast Concurrent Bind
        $FastConcurrentBind,

        [parameter(Mandatory = $false)]
        [Timespan]
            #NTime before connection times out.
            #Default: 120 seconds
        $Timeout = (New-Object System.TimeSpan(0,0,120))
    )

    Process
    {

        if($Credential -ne $null)
        {
            $LdapConnection=new-object System.DirectoryServices.Protocols.LdapConnection((new-object System.DirectoryServices.Protocols.LdapDirectoryIdentifier($LdapServer, $Port)), $Credential)
        }
        else
        {
            $LdapConnection=new-object System.DirectoryServices.Protocols.LdapConnection(new-object System.DirectoryServices.Protocols.LdapDirectoryIdentifier($LdapServer, $Port))
        }

        if($FastConcurrentBind)
        {
            $LdapConnection.SessionOptions.FastConcurrentBind()
        }
        switch($EncryptionType)
        {
            "None"
            {
                break
            }
            "SSL"
            {
                $LdapConnection.SessionOptions.ProtocolVersion=3
                $LdapConnection.SessionOptions.StartTransportLayerSecurity($null)
                break
            }
            "Kerberos"
            {
                $LdapConnection.SessionOptions.Sealing=$true
                $LdapConnection.SessionOptions.Signing=$true
                break
            }
        }
        $LdapConnection.Timeout = $Timeout
        $LdapConnection
    }

}

Function Get-DomainJoinStatus
{
    #Return the domain name if found, else return null
    if(((Get-WmiObject Win32_ComputerSystem).partofdomain) -eq $True)
    {
        return (Get-WmiObject Win32_ComputerSystem).domain
    }
}

Function Find-LdapObject
{
    Param(
        [parameter(Mandatory = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #existing LDAPConnection object retrieved with cmdlet Get-LdapConnection
            #When we perform many searches, it is more effective to use the same conbnection rather than create new connection for each search request.
        $LdapConnection,

        [parameter(Mandatory = $true)]
        [String]
            #Search filter in LDAP syntax
        $searchFilter,

        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [Object]
            #DN of container where to search
        $searchBase,

        [parameter(Mandatory = $false)]
        [System.DirectoryServices.Protocols.SearchScope]
            #Search scope
            #Default: Subtree
        $searchScope="Subtree",

        [parameter(Mandatory = $false)]
        [String[]]
            #List of properties we want to return for objects we find.
            #Default: empty array, meaning no properties are returned
        $PropertiesToLoad=@(),

        [parameter(Mandatory = $false)]
        [String]
            #Name of attribute for ASQ search. Note that searchScope must be set to Base for this type of seach
            #Default: empty string
        $ASQ,

        [parameter(Mandatory = $false)]
        [UInt32]
            #Page size for paged search. Zero means that paging is disabled
            #Default: 100
        $PageSize=100,

        [parameter(Mandatory = $false)]
        [String[]]
            #List of properties that we want to load as byte stream.
            #Note: Those properties must also be present in PropertiesToLoad parameter. Properties not listed here are loaded as strings
            #Default: empty list, which means that all properties are loaded as strings
        $BinaryProperties=@(),

        [parameter(Mandatory = $false)]
        [String[]]
            #List of properties that we want to be defined on output object, but we do not want to load them from AD.
            #Properties listed here must NOT occur in propertiesToLoad list
            #Command defines properties on output objects and sets the value to $null
            #Good for having output object with all props that we need for further processing, so we do not need to add them ourselves
            #Default: empty list, which means that we don't want any additional propertis defined on output object
        $AdditionalProperties=@(),

        [parameter(Mandatory = $false)]
        [timespan]
            #Number of seconds before connection times out.
            #Default: 120 seconds
        $Timeout = (New-Object System.TimeSpan(0,0,120))
    )

    Process
    {
        #range size for ranged attribute retrieval
        #Note that default in query policy is 1500; we set to 1000
        $rangeSize=1000

        #preserve original value of referral chasing
        $referralChasing = $LdapConnection.SessionOptions.ReferralChasing
        if($pageSize -gt 0)
        {
            #paged search silently fails when chasing referrals
            $LdapConnection.SessionOptions.ReferralChasing="None"
        }
        try
        {

            #build request
            $rq=new-object System.DirectoryServices.Protocols.SearchRequest

            #search base
            switch($searchBase.GetType().Name)
            {
                "String"
                {
                    $rq.DistinguishedName=$searchBase
                }
                default
                {
                    if($searchBase.distinguishedName -ne $null)
                    {
                        $rq.DistinguishedName=$searchBase.distinguishedName
                    }
                    else
                    {
                        Write-Error "SearchBase must be specified"
                        return
                    }
                }
            }

            #search filter in LDAP syntax
            $rq.Filter=$searchFilter

            #search scope
            $rq.Scope=$searchScope

            #attributes we want to return - nothing now, and then use ranged retrieval for the propsToLoad
            $rq.Attributes.Add("1.1") | Out-Null

            #paged search control for paged search
            if($pageSize -gt 0)
            {
                [System.DirectoryServices.Protocols.PageResultRequestControl]$pagedRqc = new-object System.DirectoryServices.Protocols.PageResultRequestControl($pageSize)
                $rq.Controls.Add($pagedRqc) | Out-Null
            }

            #server side timeout
            $rq.TimeLimit=$Timeout

            if(-not [String]::IsNullOrEmpty($asq))
            {
                [System.DirectoryServices.Protocols.AsqRequestControl]$asqRqc=new-object System.DirectoryServices.Protocols.AsqRequestControl($ASQ)
                $rq.Controls.Add($asqRqc) | Out-Null
            }

            #initialize output objects via hashtable --> faster than add-member
            #create default initializer beforehand
            $propDef=@{}
            #we always return at least distinguishedName
            #so add it explicitly to object template and remove from propsToLoad if specified
            #also remove '1.1' if present as this is special prop and is in conflict with standard props
            $propDef.Add('distinguishedName','')
            $PropertiesToLoad=@($propertiesToLoad | where-object {$_ -notin @('distinguishedName','1.1')})

            #prepare template for output object
            foreach($prop in $PropertiesToLoad)
            {
              $propDef.Add($prop,@())
            }

            #define additional properties
            foreach($prop in $AdditionalProperties)
            {
                if($propDef.ContainsKey($prop))
                {
                    continue
                }
                $propDef.Add($prop,$null)
            }

            #process paged search in cycle or go through the processing at least once for non-paged search
            while ($true)
            {
                $rsp = $LdapConnection.SendRequest($rq, $Timeout) -as [System.DirectoryServices.Protocols.SearchResponse];

                #for paged search, the response for paged search result control - we will need a cookie from result later
                if($pageSize -gt 0)
                {
                    [System.DirectoryServices.Protocols.PageResultResponseControl] $prrc=$null;
                    if ($rsp.Controls.Length -gt 0)
                    {
                        foreach ($ctrl in $rsp.Controls)
                        {
                            if ($ctrl -is [System.DirectoryServices.Protocols.PageResultResponseControl])
                            {
                                $prrc = $ctrl;
                                break;
                            }
                        }
                    }
                    if($prrc -eq $null)
                    {
                        #server was unable to process paged search
                        throw "Find-LdapObject: Server failed to return paged response for request $SearchFilter"
                    }
                }
                #now process the returned list of distinguishedNames and fetch required properties using ranged retrieval
                foreach ($sr in $rsp.Entries)
                {
                    $dn=$sr.DistinguishedName
                    #we return results as powershell custom objects to pipeline
                    #initialize members of result object (server response does not contain empty attributes, so classes would not have the same layout
                    #create empty custom object for result, including only distinguishedName as a default
                    $data=new-object PSObject -Property $propDef
                    $data.distinguishedName=$dn

                    #load properties of custom object, if requested, using ranged retrieval
                    foreach ($attrName in $PropertiesToLoad)
                    {
                        $rqAttr=new-object System.DirectoryServices.Protocols.SearchRequest
                        $rqAttr.DistinguishedName=$dn
                        $rqAttr.Scope="Base"

                        $start=-$rangeSize
                        $lastRange=$false
                        while ($lastRange -eq $false)
                        {
                            $start += $rangeSize
                            $rng = "$($attrName.ToLower());range=$start`-$($start+$rangeSize-1)"
                            $rqAttr.Attributes.Clear() | Out-Null
                            $rqAttr.Attributes.Add($rng) | Out-Null
                            $rspAttr = $LdapConnection.SendRequest($rqAttr)
                            foreach ($sr in $rspAttr.Entries)
                            {
                                if($sr.Attributes.AttributeNames -ne $null)
                                {
                                    #LDAP server changes upper bound to * on last chunk
                                    $returnedAttrName=$($sr.Attributes.AttributeNames)
                                    #load binary properties as byte stream, other properties as strings
                                    if($BinaryProperties -contains $attrName)
                                    {
                                        $vals=$sr.Attributes[$returnedAttrName].GetValues([byte[]])
                                    }
                                    else
                                    {
                                        $vals = $sr.Attributes[$returnedAttrName].GetValues(([string])) #-as [string[]];
                                    }
                                    $data.$attrName+=$vals
                                    if($returnedAttrName.EndsWith("-*") -or $returnedAttrName -eq $attrName)
                                    {
                                        #last chunk arrived
                                        $lastRange = $true
                                    }
                                }
                                else
                                {
                                    #nothing was found
                                    write-host "No results"
                                    $lastRange = $true
                                }
                            }
                        }

                        #return single value as value, multiple values as array, empty value as null
                        switch($data.$attrName.Count)
                        {
                            0 {
                                $data.$attrName=$null
                                break;
                            }
                            1 {
                                $data.$attrName = $data.$attrName[0]
                                break;
                            }
                            default
                            {
                                break;
                            }
                        }
                    }
                    #return result to pipeline
                    $data
                }
                if($pageSize -gt 0)
                {
                    if($prrc.Cookie.Length -eq 0)
                    {
                        #last page --> we're done
                        break;
                    }
                    #pass the search cookie back to server in next paged request
                    $pagedRqc.Cookie = $prrc.Cookie;
                }
                else
                {
                    #exit the processing for non-paged search
                    break;
                }
            }
        }
        finally
        {
            if($pageSize -gt 0)
            {
                #paged search silently fails when chasing referrals
                $LdapConnection.SessionOptions.ReferralChasing=$ReferralChasing
            }
        }
    }
}

Function Remove-LdapObject
{
    Param(
        [parameter(Mandatory = $true, ValueFromPipeline=$true)]
        [Object]
            #either string containing distinguishedName
            #or object with DistinguishedName property
        $Object,

        [parameter(Mandatory = $true)]
        [System.DirectoryServices.Protocols.LdapConnection]
            #existing LDAPConnection object.
        $LdapConnection,

        [parameter(Mandatory = $false)]
        [Switch]
            #whether or not to use TreeDeleteControl.
        $UseTreeDelete
    )

    Process
    {
        [System.DirectoryServices.Protocols.DeleteRequest]$rqDel=new-object System.DirectoryServices.Protocols.DeleteRequest
        switch($Object.GetType().Name)
        {
            "String"
            {
                $rqDel.DistinguishedName=$Object
            }
            default
            {
                if($Object.distinguishedName -ne $null)
                {
                    $rqDel.DistinguishedName=$Object.distinguishedName
                }
                else
                {
                    throw (new-object System.ArgumentException("DistinguishedName must be passed"))
                }
            }
        }
        if($UseTreeDelete)
        {
            $rqDel.Controls.Add((new-object System.DirectoryServices.Protocols.TreeDeleteControl)) | Out-Null
        }
        $LdapConnection.SendRequest($rqDel) -as [System.DirectoryServices.Protocols.DeleteResponse] | Out-Null

    }
}

Function Retry-TestCommand
{
    Param(
        [Parameter(Mandatory=$true)]
        [string]
        $Test,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $Args = @{},

        [Parameter(Mandatory=$false)]
        [string]
        $TestProperty,

        [Parameter(Mandatory=$false)]
        [int]
        $Tries = 5,

        [Parameter(Mandatory=$false)]
        [int]
        $InitialDelay = 2,  # in seconds

        [Parameter(Mandatory=$false)]
        [int]
        $MaxDelay = 32,  # in seconds

        [Parameter(Mandatory=$false)]
        [switch]
        $ExpectNull
    )
    $TryCount = 0
    $Delay = $InitialDelay
    $Completed = $false
    $MsgFailed = "Command [{0}] failed" -f $Test
    $MsgSucceeded = "Command [{0}] succeeded." -f $Test

    while (-not $Completed)
    {
        try
        {
            $Result = & $Test @Args
            $TestResult = if ($TestProperty) { $Result.$TestProperty } else { $Result }
            if (-not $TestResult -and -not $ExpectNull)
            {
                throw $MsgFailed
            }
            else
            {
                Write-Verbose $MsgSucceeded
                Write-Output $TestResult
                $Completed = $true
            }
        }
        catch
        {
            $TryCount++
            if ($TryCount -ge $Tries)
            {
                $Completed = $true
                Write-Output $null
                Write-Warning ($PSItem | Select -Property * | Out-String)
                Write-Warning ("Command [{0}] failed the maximum number of {1} time(s)." -f $Test, $Tries)
                $PSCmdlet.ThrowTerminatingError($PSItem)
            }
            else
            {
                $Msg = $PSItem.ToString()
                if ($Msg -ne $MsgFailed) { Write-Warning $Msg }
                Write-Warning ("Command [{0}] failed. Retrying in {1} second(s)." -f $Test, $Delay)
                Start-Sleep $Delay
                $Delay *= 2
                $Delay = [Math]::Min($MaxDelay, $Delay)
            }
        }
    }
}

Function xAdd-Computer
{
    Param(
        [Parameter(Mandatory = $true)]
        [String]
            #FQDN of the Domain to search.
        $DomainName,

        [Parameter(Mandatory = $false,ValueFromPipeLine = $false,ValueFromPipeLineByPropertyName = $false)]
        [String]
            #OU to place the computer object
        $TargetOU,

        [parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter(Mandatory=$false)]
        [System.Collections.Hashtable]
        $Args = @{}
    )

    #wrapper for the Add-Computer cmdlet that adds an OU conditional
    if($TargetOU -eq "" -and $TargetOU -eq [String]::Empty)
    {
        Add-Computer -DomainName $DomainName -Credential $cred @Args;
    }
    else
    {
        Add-Computer -DomainName $DomainName -Credential $cred -OUPath $TargetOU @Args;
    }
}

#JoinDomain Main

#Check local system for domain join status.
$DomainJoinStatus = Get-DomainJoinStatus -DomainFQDN $DomainName
if($DomainJoinStatus -eq $null)
{
    #If the object is found, remove it, else add the computer to the domain.
    #Create the credential from the Password parameter set
    if($PSCmdlet.ParameterSetName -eq "Password")
    {
        $SecPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $SecPassword
    }
    else
    {
        #Create the credential from the EncryptedPassword parameter set
        $AesObject = New-Object System.Security.Cryptography.AesCryptoServiceProvider
        $AesObject.IV = New-Object Byte[]($AesObject.IV.Length)
        $AesObject.Key = [System.Convert]::FromBase64String($Key)
        $EncryptedStringBytes = [System.Convert]::FromBase64String($EncryptedPassword)
        $ReEncryptedPassword = ConvertTo-SecureString -String "$([System.Text.UnicodeEncoding]::Unicode.GetString(($AesObject.CreateDecryptor()).TransformFinalBlock($EncryptedStringBytes, 0, $EncryptedStringBytes.Length)))" -AsPlainText -Force
        $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $ReEncryptedPassword
    }

    #Create the ldap connection
    $Ldap = Get-LdapConnection -LdapServer:$DomainName -Credential:$cred

    #Create search filter using the Local Computer's NetBIOS Name
    #https://social.msdn.microsoft.com/Forums/en-US/a5690438-d9bc-4f47-b1c6-bcb35cc2d074/how-to-get-changed-computer-name-without-restarting-the-computer?forum=netfxbcl
    $ControlSetNumber = (Get-ItemProperty -path HKLM:SYSTEM\Select).Current.ToString().PadLeft(3, "0")
    $ComputerName = (get-itemproperty -path HKLM:SYSTEM\ControlSet$ControlSetNumber\Control\ComputerName\ComputerName).ComputerName
    $SearchFilter = "(&(cn=$ComputerName)(objectClass=computer))"

    #Convert domain name to common name
    $OUSearchBase = 'dc=' + $DomainName.Replace('.',',dc=')

    #Run LDAP search
    $result = Find-LdapObject -LdapConnection:$Ldap -SearchFilter:$SearchFilter -SearchBase:$OUSearchBase -propertiesToLoad:@("distinguishedName") -ErrorAction SilentlyContinue
    if($result)
    {
        $resultOU = $result.distinguishedName.substring((($result.distinguishedName -replace '\,(.*)').length+1))
        if($resultOU -ne $TargetOU)
        {
            #if the computer object is found in AD, remove it
            Remove-LdapObject $result.distinguishedName -LdapConnection:$Ldap
        }
    }

    #Try to add the computer to the domain until AD catches up
    Retry-TestCommand -Test xAdd-Computer -Args @{DomainName=$DomainName; Credential=$cred; TargetOU=$TargetOU; args=@{Options="JoinWithNewName,AccountCreate"; Force=$true; Verbose=$true; Passthru=$true; ErrorAction="SilentlyContinue";}} -Tries $Tries -InitialDelay 10 -TestProperty "hasSucceeded"
    Write-Host "changed=yes comment=`"Joined system to the domain [$DomainName].`" domain=$DomainName";

}
elseif($DomainJoinStatus -eq $DomainName)
{
    Write-Host "changed=no comment=`"System is already joined to the correct domain [$DomainName].`" domain=$DomainName"
}
else
{
    Throw "System is joined to another domain [$DomainJoinStatus]. To join a different domain, first remove it from the current domain."
}
