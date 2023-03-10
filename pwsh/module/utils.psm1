function ConvertTo-HashTable {
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [System.Object]$Object
    )

    process {
        [hashtable]$Result = @{}
        $Object | Get-Member -MemberType Properties | ForEach-Object { $Result[$_.Name] = $Object."$($_.Name)" }
        return $Result
    }
}
Export-ModuleMember -Function ConvertTo-HashTable
