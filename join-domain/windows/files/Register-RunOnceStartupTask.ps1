[CmdLetBinding()]
Param(
    [Parameter(Mandatory=$false,Position=0,ValueFromRemainingArguments=$true)]
    $RemainingArgs
    ,
    [Parameter(Mandatory=$True, ValueFromPipeline=$False)]
    [String]
    $InvokeScript
    ,
    [Parameter(Mandatory=$True)]
    [String]
    $RunOnceScript
)

$TaskName = "RunOnceStartupTask-$([guid]::NewGuid())"

$TaskPath = "${Env:SystemRoot}\System32\WindowsPowerShell\v1.0\powershell.exe"
$PowerShellArgs = @(
    "-NoProfile"
    "-NonInteractive"
    "-ExecutionPolicy"
    "Bypass"
    "-Command"
)

$WrapperArgs = @(
    "`"${InvokeScript}`""
    "-Path"
    "`"${RunOnceScript}`""
    "-TaskName"
    "`"${TaskName}`""
)

$TaskArgs = ${PowerShellArgs} + ${WrapperArgs} + ${RemainingArgs}

# Credit for the bulk of this structure:
# https://ryanschlagel.wordpress.com/2012/07/09/managing-scheduled-tasks-with-powershell/
Try
{
    [Object] $objScheduledTask = New-Object -ComObject("Schedule.Service")

    If (!($objScheduledTask.Connected))
    {
        Try
        {
            $objScheduledTask.Connect()
            $objScheduledTask_Folder = $objScheduledTask.GetFolder('\')
            $objScheduledTask_TaskDefinition = $objScheduledTask.NewTask(0)

            # Registration / Definitions
            $objScheduledTask_RegistrationInfo = $objScheduledTask_TaskDefinition.RegistrationInfo

            # Principal
            $objScheduledTask_Principal = $objScheduledTask_TaskDefinition.Principal
            $objScheduledTask_Principal.RunLevel = 1

            # Define Settings
            $objScheduledTask_Settings = $objScheduledTask_TaskDefinition.Settings
            $objScheduledTask_Settings.Enabled = $True
            $objScheduledTask_Settings.StartWhenAvailable = $True
            $objScheduledTask_Settings.Hidden = $False

            # Triggers
            $objScheduledTask_Triggers = $objScheduledTask_TaskDefinition.Triggers
            $objScheduledTask_Trigger = $objScheduledTask_Triggers.Create(8)
            $objScheduledTask_Trigger.Enabled = $True

            # Action
            $objScheduledTask_Action = $objScheduledTask_TaskDefinition.Actions.Create(0)
            $objScheduledTask_Action.Path = "${TaskPath}"
            $objScheduledTask_Action.Arguments = "${TaskArgs}"

            # Create Task
            $objScheduledTask_Folder.RegisterTaskDefinition(
                "${TaskName}",
                $objScheduledTask_TaskDefinition,
                6,
                "SYSTEM",
                $null,
                5
            ) | out-null
            Write-Host "Scheduled Task Created Successfully" -ForegroundColor Green
        }
        Catch [System.Exception]
        {
            Write-Host "Scheduled Task Creation Failed" -ForegroundColor Red
        }
    }
}
Catch [System.Exception]
{
    Write-Host "Scheduled Task Creation Failed" -ForegroundColor Red
    Write-Host "  EXCEPTION:" $_ -ForegroundColor Red
}
