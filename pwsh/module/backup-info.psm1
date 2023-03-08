class BackupInfo {
    [int]$System
    [string]$Environment
    [datetime]$BackupTime
    [string]$Type
    [string]$FileName
    [string]$Path
    [Int64]$Timestamp

    BackupInfo([System.IO.FileInfo]$BackupFile) {
        $this.Path = $BackupFile.FullName
        $this.FileName = $BackupFile.Name

        $local:Name, $this.Type = ([regex]"^(.*)[.](\w+)[.]tar[.]zstd$").Match($this.FileName).Groups[1..2].Value
        $this.System, $this.Environment, $local:DateTime = ([regex]"^L(\d)-(\w+)-(\d{8}-\d{6})$").Match($Name).Groups[1..3].Value

        $this.BackupTime = [DateTime]::ParseExact("${DateTime}Z", "yyyyMMdd-HHmmssZ", $null)
        $this.Timestamp = Get-Content "$($BackupFile.Directory)/${Name}.ts"
    }
}

function New-BackupInfo {
    [CmdLetBinding(DefaultParameterSetName = "File")]

    param(
        [Parameter(Mandatory, ParameterSetName = "File", ValueFromPipeline, Position = 0)]
        [System.IO.FileInfo]$File
    )

    process {
        return [BackupInfo]::new($File)
    }
}
Export-ModuleMember -Function New-BackupInfo
