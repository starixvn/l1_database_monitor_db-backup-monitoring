#requires -version 7

Get-ChildItem -Path "$PSScriptRoot\module\*.psm1" -File | Import-Module -Force

$Source = @{ Server = "10.99.99.187"; HostKey = "9e:83:3a:6c:f0:9a:16:67:a8:38:b6:46:cd:14:b9:07" }
$Credential = @{ User = "backupcopier"; KeyFile = "G:\SCDBBackup\backupcopier.ppk" }

$DBInfo = @{
    ConnectionString = New-SqlClientConnectionString -Server "DBBACKUP2" -NoCredential -TrustServerCertificate
    Credential = New-SqlCredential -Username "vnTask" -Password $(Read-SqlPasswordFromFile "G:\SCDBBackup\sqlpasswd")
}
$DBBACKUP2 = New-SqlClient -ConnectionStringBuilder $DBInfo.ConnectionString -Credential $DBInfo.Credential

function Copy-BackupFile {
    param(
        [Parameter(Mandatory)]
        [datetime]$Date,
        [Parameter(Mandatory)]
        [int]$System,
        [Parameter(Mandatory)]
        [string]$Type
    )

    begin {
        if (-not @("fullbackup", "diffdaily", "diffbackup").Contains($Type)) {
            throw "Invalid backup type: [${Type}]"
        }
    }

    process {
        $Pattern = "*-$($Date.ToString("yyyyMMdd"))-*"
        $Remote = "PROD/L${System}/${Type}/${Pattern}"
        $Local = "G:\SCDBBackup\Backup2\L${System}\${Type}"

        New-Item -ItemType Directory -Force -Path ${Local} | Out-Null

        Copy-ScpFile -FromPath $Remote -ToPath $Local -Server $Source.Server -HostKey $Source.HostKey -User $Credential.User -KeyFile $Credential.KeyFile -Pull -Recursive

        Get-Item "${Local}\${Pattern}.tar.zstd" | New-BackupInfo | Send-BackupInfo -SqlClient $DBBACKUP2 -Procedure "SabaBK2DB.dbo.InsertBackupInfo"
    }
}

try {
    Set-ScpExecutor "G:\SCDBBackup\pscp.exe"

    $UTC = (Get-Date).ToUniversalTime()
    $Yesterday = $UTC.AddDays(-1)

    for ($L = 1; $L -le 3; $L++) {
        Write-Output "Copying backup for L${L}..."
        Copy-BackupFile -Date $UTC -System $L -Type "fullbackup"
        Copy-BackupFile -Date $UTC -System $L -Type "diffdaily"
        Copy-BackupFile -Date $Yesterday -System $L -Type "diffbackup"
    }
} catch {
    Write-Error $_
} finally {}
