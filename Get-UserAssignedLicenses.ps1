$UserId = 'user01@contoso.com'

Connect-Graph -Scopes User.Read.All, Directory.Read.All, Organization.Read.All -NoWelcome

$UserAssignedLicenses = Get-MgUserLicenseDetail -UserId $UserId -Property SkuId, SkuPartNumber, ServicePlans

Write-Host "User: $UserId"

foreach ($License in $UserAssignedLicenses) {

    Write-Host "`t License: $($License.SkuPartNumber)"
    
    $DisabledServicePlanNames = $License.ServicePlans | Where-Object ProvisioningStatus -eq "Disabled" | Sort-Object -Property ServicePlanName | ForEach-Object {$_.ServicePlanName}

    Write-Host "`t `t Disabled Service Plans: $($DisabledServicePlanNames -join ', ') `n"

}
