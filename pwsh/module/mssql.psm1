function Read-SqlPasswordFromFile {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $File,
    
        [Parameter()]
        [switch] $ReadOnly
    )

    process {
        $SecureString = Get-Content $File | ConvertTo-SecureString -Key (1..16)
        if ($ReadOnly) {
            $SecureString.MakeReadOnly()
        }

        return $SecureString
    }
}
Export-ModuleMember -Function Read-SqlPasswordFromFile

function ConvertTo-RawString {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [securestring] $SecureString
    )

    process {
        return (New-Object System.Net.NetworkCredential("", $SecureString)).Password
    }
}

function New-SqlClientConnectionString {
    param (
        [Parameter(Mandatory)]
        [string] $Server,
        [Parameter(Mandatory, ParameterSetName = "RawPassword")]
        [Parameter(Mandatory, ParameterSetName = "Password")]
        [Parameter(Mandatory, ParameterSetName = "FilePassword")]
        [string] $User,
        [Parameter(Mandatory, ParameterSetName = "RawPassword")]
        [string] $RawPass,
        [Parameter(Mandatory, ParameterSetName = "Password")]
        [securestring] $Password,
        [Parameter(Mandatory, ParameterSetName = "FilePassword")]
        [string] $FilePass,
        [Parameter(Mandatory, ParameterSetName = "IntegratedSecurity")]
        [string] $IntegratedSecurity,
        [Parameter(ParameterSetName = "NoCredential")]
        [switch] $NoCredential,
        [Parameter()]
        [string] $InitialCatalog = "master",
        [Parameter()]
        [switch] $TrustServerCertificate
    )

    begin {
        if ((-not $NoCredential) -and (-not $IntegratedSecurity)) {
            if ($RawPass) {
                $Password = ConvertTo-SecureString $RawPass -AsPlainText -Force
            } elseif ($FilePass) {
                $Password = Read-SqlPasswordFromFile -File $FilePass
            }
            $DecryptedPassword = ConvertTo-RawString $Password
        }

    }

    process {
        $ConnectionString = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
        $ConnectionString["Data Source"] = $Server
        $ConnectionString["Initial Catalog"] = $InitialCatalog
        $ConnectionString["TrustServerCertificate"] = $TrustServerCertificate.ToBool()

        if ($DecryptedPassword) {
            $ConnectionString["User ID"] = $User
            $ConnectionString["Password"] = $DecryptedPassword
        } elseif ($IntegratedSecurity) {
            $ConnectionString["Integrated Security"] = $IntegratedSecurity
        }

        Write-Verbose "`$ConnectionString = `"$ConnectionString`""
        return $ConnectionString
    }
}
Export-ModuleMember -Function New-SqlClientConnectionString

function New-SqlCredential {
    param (
        [Parameter(Mandatory)]
        [string] $Username,
        [Parameter(Mandatory, ParameterSetName = "RawPassword")]
        [string] $RawPass,
        [Parameter(Mandatory, ParameterSetName = "Password")]
        [securestring] $Password,
        [Parameter(Mandatory, ParameterSetName = "FilePassword")]
        [string] $FilePass
    )

    begin {
        if ($RawPass) {
            $Password = ConvertTo-SecureString $RawPass -AsPlainText -Force
        } elseif ($FilePass) {
            $Password = Read-SqlPasswordFromFile -File $FilePass
        }
    }

    process {
        $Password.MakeReadOnly()
        return New-Object System.Data.SqlClient.SqlCredential($Username, $Password)
    }
}
Export-ModuleMember -Function New-SqlCredential

function New-SqlClient {
    param (
        [Parameter(Mandatory, ParameterSetName = "ConnectionStringBuilder")]
        [System.Data.SqlClient.SqlConnectionStringBuilder] $ConnectionStringBuilder,

        [Parameter(Mandatory, ParameterSetName = "ConnectionString")]
        [string] $ConnectionString,

        [Parameter()]
        [System.Data.SqlClient.SqlCredential] $Credential
    )

    begin {
        if ($ConnectionStringBuilder) {
            $ConnectionString = $ConnectionStringBuilder.ConnectionString
        }
    }

    process {
        $SqlClient = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)

        if ($Credential) {
            $SqlClient.Credential = $Credential
        }

        $SqlClient.Open()
        Write-Verbose "Connected to SQL Server @($($SqlClient.DataSource))"
        return $SqlClient
    }
}
Export-ModuleMember -Function New-SqlClient

function New-SqlParameters {
    param (
        [Parameter(Mandatory, ParameterSetName = "Hashtable")]
        [hashtable] $HashTable
    )

    if ($HashTable) {
        $SqlParameters = $HashTable.GetEnumerator() | ForEach-Object {
            New-Object System.Data.SqlClient.SqlParameter($_.Key, $_.Value)
        }
    }
    return $SqlParameters
}
Export-ModuleMember -Function New-SqlParameters

function Invoke-SqlQuery {
    [CmdLetBinding(DefaultParameterSetName = "Reader")]

    param (
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection] $SqlClient,

        [Parameter(Mandatory)]
        [string] $Query,

        [Parameter(ParameterSetName = "NonQuery")]
        [switch] $NonQuery,

        [Parameter(ParameterSetName = "Reader")]
        [switch] $Reader,

        [Parameter(ParameterSetName = "Scalar")]
        [switch] $Scalar,

        [Parameter(ParameterSetName = "XmlReader")]
        [switch] $XmlReader,

        [Parameter()]
        [switch] $Procedure,

        [Parameter()]
        [hashtable] $Parameters

    )

    begin {
        if ($SqlClient.State -ne "Open") {
            $SqlClient.Open()
        }

        # Default mode is Reader
        $Mode = $PSCmdlet.ParameterSetName
        Write-Debug "SqlQuery Mode = `"$Mode`""
    }

    process {
        $SqlCommand = $SqlClient.CreateCommand()
        $SqlCommand.CommandText = $Query

        if ($Procedure) {
            $SqlCommand.CommandType = "StoredProcedure"
            Write-Debug "SqlCommand Type = `"$($SqlCommand.CommandType)`""
        }

        if ($Parameters) {
            $SqlParameters = New-SqlParameters -HashTable $Parameters
            $SqlCommand.Parameters.AddRange($SqlParameters)
        }

        Write-Debug "$Mode"
        switch ($Mode) {
            "NonQuery" {
                [int] $Result = $SqlCommand.ExecuteNonQuery()

                $SqlCommand.Dispose()
                return $Result
            }
            "Reader" {
                $DataSet = New-Object System.Data.DataSet
                $SqlDataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $SqlCommand
                $SqlDataAdapter.Fill($DataSet)

                $SqlDataAdapter.Dispose()
                $SqlCommand.Dispose()
                return $DataSet
            }
            "Scalar" {
                $Result = $SqlCommand.ExecuteScalar()

                $SqlCommand.Dispose()
                return $Result
            }
            "XmlReader" {
                throw "Mode `"$Mode`" hasn't been implemented yet"
            }
            Default {
                $SqlCommand.Dispose()
                throw "Invalid mode `"$Mode`""
            }
        }
    }
}
Export-ModuleMember -Function Invoke-SqlQuery
