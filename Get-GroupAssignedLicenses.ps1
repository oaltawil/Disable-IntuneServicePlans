$GroupDisplayName = "All Users"

$Group = Get-MgGroup -Filter "DisplayName eq '$GroupDisplayName'"  -Property Id, MailNickname, DisplayName, GroupTypes, Description, AssignedLicenses | Where-Object AssignedLicenses -ne $null
   
Write-Host "Group: $($Group.DisplayName)"

$GroupAssignedLicenses = $Group.AssignedLicenses 

foreach ($License in $GroupAssignedLicenses) {
    
    # Retrieve the license details
    $SubscribedSku = Get-MgSubscribedSku | Where-Object SkuId -eq $License.SkuId
    
    $DisabledServicePlanIds = $License.DisabledPlans

    $DisabledServicePlanNames = $SubscribedSku.ServicePlans | Where-Object ServicePlanId -in $DisabledServicePlanIds | Select-Object -ExpandProperty ServicePlanName

    Write-Host "`t License: $($SubscribedSku.SkuPartNumber)"

    Write-Host "`t `t Disabled Service Plans: $($DisabledServicePlanNames -join ', ') `n"

}
