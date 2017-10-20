[CmdletBinding()]
param(
    [Parameter(Mandatory=$true,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [string[]] $DnsSearchSuffixes
    ,
    [Parameter(Mandatory=$false,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [ValidateSet($true,$false,"null")]
    $Ec2ConfigSetDnsSuffixList = "null"
)

if ($Ec2ConfigSetDnsSuffixList -ne "null")
{
    $EC2SettingsFile = "${env:ProgramFiles}\Amazon\Ec2ConfigService\Settings\Config.xml"
    if (Test-Path $EC2SettingsFile)
    {
        $xml = [xml](get-content $EC2SettingsFile)
        $xmlElement = $xml.get_DocumentElement()
        $xmlElement.GlobalSettings.SetDnsSuffixList = "$Ec2ConfigSetDnsSuffixList".ToLower()
        $xml.Save($EC2SettingsFile)
    }
}

if (Get-Command Set-DnsClientGlobalSetting -ErrorAction SilentlyContinue)
{
    Set-DnsClientGlobalSetting -SuffixSearchList $DnsSearchSuffixes
}
else
{
    Invoke-WmiMethod -Path Win32_NetworkAdapterConfiguration -Name SetDNSSuffixSearchOrder -ArgumentList $DnsSearchSuffixes
}
