#requires -PSEdition Core

$DEFAULT_SCP = "pscp"
$scpExecutor = $DEFAULT_SCP

function IsApplication {
    param (
        [Parameter()]
        [string]$Path
    )
    return (-not ($Path -eq $null)) -and (Get-Command $Path -ErrorAction SilentlyContinue)
}

function Set-ScpExecutor {
    param (
        [Parameter(Position = 0)]
        [string]$Path
    )

    if (($Path -eq "") -or ($Path -eq $null)) {
        if (IsApplication -Path $script:DEFAULT_SCP) {
            $script:scpExecutor = $script:DEFAULT_SCP
            Write-Warning 'empty $Path provided, reset $scpExecutor = "scp"'
        } else {
            Write-Warning 'empty $Path provided, do nothing'
        }
        return
    }

    if (IsApplication -Path $Path) {
        $script:scpExecutor = $Path
        Write-Verbose "scp command is set to ""$script:scpExecutor"""
    } else {
        Write-Error "$Path is not an application"
    }
}
Export-ModuleMember -Function Set-ScpExecutor

function Copy-ScpFile {
    [CmdLetBinding(DefaultParameterSetName = "Push")]

    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]] $FromPath,
        [Parameter(Mandatory)]
        [string] $ToPath,
        [Parameter(Mandatory)]
        [string] $Server,
        [Parameter()]
        [string] $Port = 22,
        [Parameter()]
        [string] $HostKey,
        [Parameter()]
        [string] $User = "root",
        [Parameter()]
        [string] $KeyFile,
        [Parameter(ParameterSetName = "Pull")]
        [switch] $Pull,
        [Parameter(ParameterSetName = "Push")]
        [switch] $Push,
        [Parameter()]
        [switch] $Recursive
    )

    begin {
        if (-not (IsApplication -Path $scpExecutor)) {
            throw "scp application is not initialized. Abort..."
        }

        switch ($PSCmdlet.ParameterSetName) {
            "Pull" {
                $Push = -not $Pull
            }
            "Push" {
                $Pull = -not $Push
            }
        }

        $Destination = ($Push ? "${User}@${Server}:" : "") + "${ToPath}"

        if ($HostKey) {
            $HostKeyParam = @("-hostkey", $HostKey)
        }

        if ($KeyFile) {
            $KeyFileParam = @("-i", $KeyFile)
        }

        if ($Recursive) {
            $RecursiveParam = @("-r")
        }

        $Verbose = $PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters.Get_Item('Verbose')
        Write-Verbose "Verbose = $Verbose"
        Write-Debug "Verbose = $Verbose"
        $Debug = $PSBoundParameters.ContainsKey('Debug') -and $PSBoundParameters.Get_Item('Debug')
        Write-Debug "Debug = $Debug"
        $QuietParam = ($Verbose -or $Debug) ? @() : @("-q")

    }

    process {
        $Source = ($Pull ? "${User}@${Server}:" : "") + "${FromPath}"
        $Destination = ($Push ? "${User}@${Server}:" : "") + "${ToPath}"
        Write-Verbose "& $script:scpExecutor $HostKeyParam $KeyFileParam $RecursiveParam -P $Port $Source $Destination"
        & $script:scpExecutor $QuietParam $HostKeyParam $KeyFileParam $RecursiveParam -P $Port "$Source" "$Destination"
    }
}
Export-ModuleMember -Function Copy-ScpFile
