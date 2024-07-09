# Retrieving licenses for a group requires the Group.Read.All permission scope
# Retrieving licenses for a user requires the User.Read.All permission scope
# The Organization.Read.All permission scope is required to read the licenses available in the tenant
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All", "Directory.Read.All", "Organization.Read.All" -NoWelcome

$IntuneServicePlanIds = @("c1ec4a95-1f05-45b3-a911-aa3b0e1992c1", "a23b959c-7ce8-4e57-9140-b90eb88a9e97")

foreach ($License in Get-MgSubscribedSku) {

    foreach ($ServicePlan in $License.ServicePlans) {
            
        if ($IntuneServicePlanIds -contains $ServicePlan.ServicePlanId) {

            Write-Output "Service Plan Name: $($ServicePlan.ServicePlanName)"
            Write-Output "License: $($License.SkuPartNumber)"
            
            break
            
        }

    }

}
