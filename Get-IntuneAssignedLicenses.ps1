<#PSScriptInfo

.GUID 8801e5c1-04a4-40c0-b45e-70397e87578f

.AUTHOR oaltawil@microsoft.com

.COMPANYNAME Microsoft Canada

.LICENSEURI https://www.gnu.org/licenses/gpl-3.0.en.html

#>

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.groups, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement

<#
.NOTES
This sample script is not supported under any Microsoft standard support program or service. The sample script is provided AS IS without warranty of any kind. Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample script remains with you. 
In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the script be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample script, even if Microsoft has been advised of the possibility of such damages.

.DESCRIPTION
This sample script can be used to retrieve all Microsoft Entra Id Groups and Users that have been assigned licenses that contain the Intune service plans in an enabled state.

The script generates two text files that contain the groups' Display Names and the users' User Princpal Names along with the SKU Part Number of the license.
 - GroupsWithIntuneEnabled.csv
 - UsersWithIntuneEnabled.csv

.PARAMETER OutputFolderPath
Optional. The full path to a folder where the script's output files will be generated. If the folder does not exist, the script will create it. If this parameter is not provided, the script will generate the output files in the script's parent folder.

.PARAMETER UsersOnly
Optional. If this switch is specified, the script will only generate the UsersWithIntuneEnabled.csv file.

.PARAMETER GroupsOnly
Optional. If this switch is specified, the script will only generate the GroupsWithIntuneEnabled.csv file.

.EXAMPLE 
Get-IntuneAssignedLicenses.ps1 -OutputFolderPath ~\Documents\Reports

    The above command generates the two text files in the user's Documents folder in a subdirectory called "Reports". The script will create the "Reports" folder if it does not exist.

.EXAMPLE 
Get-IntuneAssignedLicenses.ps1

    The above command generates the two text files in the same directory as the script.

.EXAMPLE
Get-IntuneAssignedLicenses.ps1 -OutputFolderPath ~\Documents -GroupsOnly

    The above command generates the "GroupsWithIntuneEnabled.csv" file in the user's Documents folder. The "UsersWithIntuneEnabled.csv" file will not be generated.

#>

[CmdletBinding()]
param (
    [Parameter(Position = 0, Mandatory = $false)]
    [String]
    $OutputFolderPath,
    [switch]
    $UsersOnly,
    [switch]
    $GroupsOnly
)

# Stop script execution upon encountering any errors
$ErrorActionPreference = "Stop"

# An array containing Intune Service Plan Ids.
# Service Plan Reference: https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference
$IntuneServicePlanIds = @(
    
    "c1ec4a95-1f05-45b3-a911-aa3fa01094f5"  # INTUNE_A      (Microsoft Intune Plan 1)
    "da24caf9-af8e-485c-b7c8-e73336da2693"  # INTUNE_EDU    (Microsoft Intune Plan 1 for Education)

)

# Set the default output folder path if the parameter is not provided
if (-not $OutputFolderPath) {

    $OutputFolderPath = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

}

# Create the output folder if it does not exist
if (-not (Test-Path $OutputFolderPath)) {

    Write-Host "The specified output folder path $OutputFolderPath does not exist. Creating the folder..."

    New-Item -Path $OutputFolderPath -ItemType Directory | Out-Null

}

# Retrieving licenses for a group requires the Group.Read.All permission scope
# Retrieving licenses for a user requires the User.Read.All permission scope
# The Organization.Read.All permission scope is required to read the licenses available in the tenant
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All", "Directory.Read.All", "Organization.Read.All" -NoWelcome

if (-not $UsersOnly) {

    ###########################
    #                         #
    # Group-Assigned Licenses #
    #                         #
    ###########################

    # Generate the group output file path
    $GroupOutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath "GroupsWithIntuneEnabled.csv"

    # Write the header to the output file (overwrite the file if it already exists)
    Set-Content -Path $GroupOutputFilePath -Value "Group Display Name,SKU Part Number"

    # Get all groups with assigned licenses
    $Groups = Get-MgGroup -All -Property Id, MailNickname, DisplayName, GroupTypes, Description, AssignedLicenses | Where-Object AssignedLicenses -ne $null

    foreach ($Group in $Groups) {

        $GroupAssignedLicenses = $Group.AssignedLicenses 

        foreach ($GroupAssignedLicense in $GroupAssignedLicenses) {

            # Retrieve the subscribed sku details
            $SubscribedSku = Get-MgSubscribedSku | Where-Object SkuId -eq $GroupAssignedLicense.SkuId

            # Verify that the subscribed sku contains an Intune service plan
            $SubscribedSkuIntuneServicePlans = $SubscribedSku.ServicePlans | Where-Object ServicePlanId -in $IntuneServicePlanIds

            # If the subscribed sku does not contain any Intune service plans, then skip this group assigned license
            if (-not $SubscribedSkuIntuneServicePlans) {

                continue
                
            }

            # Retrieve the disabled service plans
            $DisabledServicePlanIds = $GroupAssignedLicense.DisabledPlans

            # All Intune service plans should be disabled. If any Intune service plan is not disabled, then log this group and add it to the group output file
            if (-not (($DisabledServicePlanIds -contains $IntuneServicePlanIds[0]) -and ($DisabledServicePlanIds -contains $IntuneServicePlanIds[1]))) {

                # Write the group's display name and the sku part number to the output file
                Add-Content -Path $GroupOutputFilePath -Value "$($Group.DisplayName),$($SubscribedSku.SkuPartNumber)"
                
            }

        }

    }

}

if (-not $GroupsOnly) {

    ##########################
    #                        #
    # User-Assigned Licenses #
    #                        #
    ##########################

    # Generate the user output file path
    $UserOutputFilePath = Join-Path -Path $OutputFolderPath -ChildPath "UsersWithIntuneEnabled.csv"

    # Write the header to the user output file (overwrite the file if it already exists)
    Set-Content -Path $UserOutputFilePath -Value "User Principal Name,SKU Part Number"

    # Get all users with assigned licenses
    $Users = Get-MgUser -All -Property DisplayName, Id, Mail, UserPrincipalName, LicenseAssignmentStates | Where-Object LicenseAssignmentStates -ne $null

    foreach ($User in $Users) {

        # Retrieve the user's assigned licenses
        $UserAssignedLicenses = $User.LicenseAssignmentStates

        foreach ($UserAssignedLicense in $UserAssignedLicenses) {

            # If the user assigned license is inherited; i.e. it is assigned by a group, then skip this user assigned license
            if ($UserAssignedLicense.AssignedByGroup) {

                continue

            }

            # Retrieve the subscribed sku details
            $SubscribedSku = Get-MgSubscribedSku | Where-Object SkuId -eq $UserAssignedLicense.SkuId

            # Verify that the subscribed sku contains *any* Intune service plans
            $SubscribedSkuIntuneServicePlans = $SubscribedSku.ServicePlans | Where-Object ServicePlanId -in $IntuneServicePlanIds

            # If the subscribed sku does not contain any Intune service plans, then skip this user assigned license
            if (-not $SubscribedSkuIntuneServicePlans) {

                continue

            }

            # Retrieve the disabled service plans
            $DisabledServicePlanIds = $UserAssignedLicense.DisabledPlans

            # All Intune service plans should be disabled. If any Intune service plan is not disabled, then log this user and add it to the user output file
            if (-not (($DisabledServicePlanIds -contains $IntuneServicePlanIds[0]) -and ($DisabledServicePlanIds -contains $IntuneServicePlanIds[1]))) {

                # Write the user's display name and the sku part number to the output file
                Add-Content -Path $UserOutputFilePath -Value "$($User.UserPrincipalName),$($SubscribedSku.SkuPartNumber)"

            }
        
        }

    }

}