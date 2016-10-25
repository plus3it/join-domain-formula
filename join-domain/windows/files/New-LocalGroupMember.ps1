[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$True, ValueFromPipeline=$True)]
    [String[]]
    $Members
    ,
    [Parameter(Mandatory=$True)]
    [String]
    $DomainNetBiosName
    ,
    [Parameter(Mandatory=$False)]
    [String]
    $Group = "Administrators"
    )
Begin
{
    $GroupObject = [ADSI]"WinNT://${Env:ComputerName}/${Group},group"
    $GroupMembers = @(
        @($GroupObject.Invoke("Members")) | ForEach {
            $_.GetType().InvokeMember("Name", "GetProperty", $null, $_, $null)
        }
    )
}
Process
{
    ForEach ($Member in $Members)
    {
        If (!($Member -in $GroupMembers))
        {
            Write-Verbose "Adding ${Member} to group ${Group}"
            $GroupObject.Add("WinNT://${DomainNetBiosName}/${Member},group")
        }
        Else
        {
            Write-Verbose "${Member} is already a member of group ${Group}"
        }
    }
}
