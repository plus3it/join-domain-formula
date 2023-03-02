[CmdletBinding()]
param(
    [Parameter(Mandatory=$true,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [string[]] $DnsSearchSuffixes
    ,
    [Parameter(Mandatory=$false,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [ValidateSet($true,$false,"null")]
    $Ec2ConfigSetDnsSuffixList = "null"
    ,
    [Parameter(Mandatory=$false,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [bool] $RegisterPrimaryConnectionAddress = $true
    ,
    [Parameter(Mandatory=$false,ValueFromPipeLine=$false,ValueFromPipeLineByPropertyName=$false)]
    [bool] $UseSuffixWhenRegistering = $false
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

$PrimaryIp = pathping -n -w 1 -h 1 -q 1 "192.0.0.8" | Where-Object { $_ -match "^.*0[\s]{2}((\d{1,3}[.]){3}\d{1,3})" } | % { $matches[1] }
$Adapter = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" | Where-Object { $_.IPAddress -eq $PrimaryIp }
$Adapter.SetDynamicDNSRegistration($RegisterPrimaryConnectionAddress, $UseSuffixWhenRegistering)
ipconfig /registerdns
