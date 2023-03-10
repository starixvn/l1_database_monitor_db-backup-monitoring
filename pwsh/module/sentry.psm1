function Get-SentryModule {
    param(
        [Parameter(Mandatory, ParameterSetName = "PackageName", ValueFromPipeline, Position = 0)]
        [string]$PackageName,
        [Parameter(Mandatory, ParameterSetName = "Package", ValueFromPipeline, Position = 0)]
        [Microsoft.PackageManagement.Packaging.SoftwareIdentity]$Package,
        [Parameter(Mandatory, ParameterSetName = "Assembly", ValueFromPipeline, Position = 0)]
        [System.IO.FileInfo]$Assembly
    )

    process {
        switch -Wildcard ($PSCmdlet.ParameterSetName) {
            "PackageName" {
                $Package = Get-Package -Name $PackageName
             }
             "Package*" {
                $Assembly = Get-Item -Path "$(Split-Path $Package.Source -Parent)/lib/net6.0/Sentry.dll"
             }
            Default {}
        }

        return [System.Reflection.Assembly]::LoadFrom($Assembly.FullName)
    }
}
Export-ModuleMember -Function Get-SentryModule
