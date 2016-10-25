[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$false,Position=0,ValueFromRemainingArguments=$true)]
    $RemainingArgs
    ,
    [Parameter(Mandatory=$True, ValueFromPipeline=$False)]
    [String]
    $Path
    ,
    [Parameter(Mandatory=$True)]
    [String]
    $TaskName
)

# Convert RemainingArgs to a hashtable
$RemainingArgsHash = @{}
If ($RemainingArgs)
{
    # PS2.0 receives remainingargs in a different format than PS3.0
    If ($PSVersionTable.PSVersion -eq "2.0") {
        $RemainingArgsHash = $RemainingArgs | ForEach-Object -Begin `
        {
            $index = 0
            $hash = @{}
        } -Process {
            If ($index % 2 -eq 0) {
                $hash[$_] = $RemainingArgs[$index+1]
            }
            $index++
        } -End {
            Write-Output $hash
        }
    }
    Else
    {
        $RemainingArgsHash = $RemainingArgs | ForEach-Object -Begin `
        {
            $index = 0
            $hash = @{}
        } -Process {
            If ($_ -match "^-.*$") {
                $hash[($_.trim("-",":"))] = $RemainingArgs[$index+1]
            }
            $index++
        } -End {
            Write-Output $hash
        }
    }
}
Write-Debug "RemainingArgsHash = $((
    $RemainingArgsHash.GetEnumerator() | % { `"-{0}: {1}`" -f $_.Key, $_.Value }
) -join ' ')"

# Run the script
Write-Verbose "Running script ${Path}"
Invoke-Expression "& ${Path} @RemainingArgsHash"

# Delete the scheduled task
$SchTasks = "${Env:SystemRoot}\system32\schtasks.exe"
$SchArguments = @(
    "/delete"
    "/f"
    "/TN"
    "`"${TaskName}`""
)

Write-Verbose "Deleting scheduled task ${TaskName}"
$null = Start-Process `
    -FilePath ${SchTasks} `
    -ArgumentList ${SchArguments} `
    -NoNewWindow -PassThru -Wait
