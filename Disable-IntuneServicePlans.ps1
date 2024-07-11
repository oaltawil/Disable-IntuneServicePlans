<#PSScriptInfo

.GUID cb5f3368-02b7-431c-b75b-03c2dbd46e50

.AUTHOR oaltawil@microsoft.com

.COMPANYNAME Microsoft Canada

.LICENSEURI https://www.gnu.org/licenses/gpl-3.0.en.html

#>

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Groups, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement

<#
.NOTES
This sample script is not supported under any Microsoft standard support program or service. The sample script is provided AS IS without warranty of any kind. Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample script remains with you. 
In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the script be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample script, even if Microsoft has been advised of the possibility of such damages.

.SYNOPSIS
This sample script can be used to disable the Intune service plans for specific Microsoft Entra Id Groups, specific Microsoft Entra Id Users, all Microsoft Entra Id Groups in the Tenant or all Microsoft Entra Id Users in the Tenant.

.DESCRIPTION
This sample script can be used in five ways: 
    1. Using the GroupDisplayNames parameter, the user can specify the Microsoft Entra Id groups from which to disable the Intune service plans.
    2. Using the UserPrincipalNames parameter, the user can specify the Microsoft Entra Id users from which to disable the Intune service plans.
    3. Using the AllGroups switch parameter, the user can instruct the script to disable the Intune service plans from all Microsoft Entra Id groups in the directory.
    4. Using the AllUsers switch parameter, the user can instruct the script to disable the Intune service plans from all Microsoft Entra Id users in the directory.
    5. Using the InputFilePath parameter, the user can specify the file path to a CSV (comma-separated value) file that contains group display names and user principal names

.PARAMETER GroupDisplayNames
The display names of one or more Microsoft Entra Id Groups from which you want to disable the Intune service plans.

.PARAMETER UserPrincipalNames
The user principal names of one or more Microsoft Entra Id Users from which you want to disable the Intune service plans.

.PARAMETER AllGroups
The AllGroups switch parameter indicates that you want to disable the Intune service plans from all Microsoft Entra Id Groups in the directory.

.PARAMETER AllUsers
The AllUsers switch parameter indicates that you want to disable the Intune service plans from all Microsoft Entra Id Users in the directory.

.PARAMETER InputFilePath
The full path to a CSV (Comma-Separated Value) file with two column headers: Name and Type.
        
    Schema:
        Name: Group Display Name or User Principal Name
        Type: Group or User
        
    Sample:
        Name,Type
        User Group 01,Group
        User Group 02,Group
        user01@contoso.com,User
        user02@contoso.com,User

.EXAMPLE 
Disable-IntuneServicePlans.ps1 -GroupDisplayNames "User Group 01", "User Group 02"

    The above command disables the Intune Service Plans from the groups with the specified display names.

.EXAMPLE
Disable-IntuneServicePlans.ps1 -UserPrincipalNames "user01@contoso.com", "user02@consoto.com"

    The above command disables the Intune Service Plans from the users with the specified user principal names.

.EXAMPLE
Disable-IntuneServicePlans.ps1 -AllGroups

    The above command disables the Intune Service Plans from all groups in the directory

.EXAMPLE
Disable-IntuneServicePlans.ps1 -AllUsers

    The above command disables the Intune Service Plans from all users in the directory.
    
.EXAMPLE

Disable-IntuneServicePlans.ps1 -InputFilePath .\GroupUserList.csv

    CSV (Comma-Separated Value) file with two column headers: Name and Type.
        
    Schema:
        Name: Group Display Name or User Principal Name
        Type: Group or User
        
    Sample:
        Name,Type
        User Group 01,Group
        User Group 02,Group
        user01@consoto.com,User
        user02@consoto.com,User
#>

[CmdletBinding(DefaultParameterSetName = 'GroupDisplayNames')]
param (
    [Parameter(Position = 0, ParameterSetName='GroupDisplayNames', Mandatory=$true)]
    [String[]]
    $GroupDisplayNames,
    [Parameter(Position = 0, ParameterSetName='UserPrincipalNames', Mandatory=$true)]
    [String[]]
    $UserPrincipalNames,
    [Parameter(Position = 0, ParameterSetName='AllGroups', Mandatory=$true)]
    [switch]
    $AllGroups,
    [Parameter(Position = 0, ParameterSetName='AllUsers', Mandatory=$true)]
    [switch]
    $AllUsers,
    [Parameter(Position = 0, ParameterSetName='InputFilePath', Mandatory=$true)]
    [String]
    $InputFilePath
)

# Stop script execution upon encountering any errors
$ErrorActionPreference = "Stop"

<#
Service Plan Reference: https://learn.microsoft.com/en-us/entra/identity/users/licensing-service-plan-reference

    ServicePlanName                                     ServicePlanId
    INTUNE_A (Microsoft Intune Plan 1)                  c1ec4a95-1f05-45b3-a911-aa3fa01094f5
    INTUNE_EDU (Microsoft Intune Plan 1 for Education)  da24caf9-af8e-485c-b7c8-e73336da2693
#>
$IntuneServicePlanNames = @(
    "Intune_A",
    "Intune_EDU"
)

#####################################
#                                   #
# FUNCTION: Group-Assigned Licenses #
#                                   #
#####################################

# Disable the Intune service plans for Groups
function Disable-IntuneServicePlansForGroups {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphGroup[]]
        $Groups
    )

    <#
        
        This function makes use of the following resources:
        
        1. AssignedLicenses property of Group objects: https://learn.microsoft.com/en-us/graph/api/resources/assignedlicense?view=graph-rest-1.0
        2. Set-MgGroupLicense cmdlet: https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.groups/set-mggrouplicense?view=graph-powershell-1.0

    #>

    # Iterate through each group
    foreach ($Group in $Groups) {

        # Iterate through each license assigned to the group and remove the Intune service plans if the license contains them
        foreach ($GroupAssignedLicense in $Group.AssignedLicenses) {
            
            # Retrieve the Sku Id of the group assigned license
            $SkuId = $GroupAssignedLicense.SkuId

            # Retrieve the license details
            $SubscribedSku = Get-MgSubscribedSku | Where-Object SkuId -eq $SkuId
            
            # Retrieve the new (Intune) service plans that are to be disabled for the new license
            $IntuneServicePlanIds = @($SubscribedSku.ServicePlans | Where-Object ServicePlanName -in $IntuneServicePlanNames | Select-Object -ExpandProperty ServicePlanId)
            
            # If the license does not contain any Intune service plans, then skip this license
            if (-not $IntuneServicePlanIds) {
            
                continue
            
            }
            
            # Retrieve the service plans that are currently disabled for the group
            $GroupDisabledServicePlanIds = @($Group.AssignedLicenses | Where-Object SkuId -eq $SkuId | Select-Object -ExpandProperty DisabledPlans)

            # Merge the Intune service plans that are to be disabled with the group's current state of disabled plans
            $DisabledServicePlanIds = ($GroupDisabledServicePlanIds + $IntuneServicePlanIds) | Select-Object -Unique

            # If the group's current disabled plans are the same as the new disabled plans, then skip this license
            if ($DisabledServicePlanIds -eq $GroupDisabledServicePlanIds) {
            
                continue
            
            }

            # Create the object that will be used to update the group's license
            $params = @{

                AddLicenses = @(
                    @{
                        DisabledPlans = $DisabledServicePlanIds
                        SkuId = $SkuId
                    }
                )
                
                RemoveLicenses = @(
                )

            }

            # Update the group's license
            Set-MgGroupLicense -GroupId $Group.Id -BodyParameter $params

            # Retrieve the names of the disabled plans
            $DisabledServicePlanNames = $SubscribedSku.ServicePlans | Where-Object ServicePlanId -in $DisabledServicePlanIds | Select-Object -ExpandProperty ServicePlanName

            Write-Host "-----------------------------"
            Write-Host "Group: $($Group.DisplayName)"
            Write-Host "License: $($SubscribedSku.SkuPartNumber)"
            Write-Host "Disabled Service Plans: $($DisabledServicePlanNames -join ', ')"
            Write-Host "-----------------------------"

        }

    }

}

####################################
#                                  #
# FUNCTION: User-Assigned Licenses #
#                                  #
####################################

# Disable the Intune service plans for Users
function Disable-IntuneServicePlansForUsers {

    <#
    
        This function makes use of the following resources:

        1. The "LicenseAssignmentStates" property of User objects: https://learn.microsoft.com/en-us/graph/api/resources/licenseassignmentstate?view=graph-rest-1.0
        2. The Set-MgUserLicense cmdlet: https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.users.actions/set-mguserlicense?view=graph-powershell-1.0

    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Microsoft.Graph.PowerShell.Models.MicrosoftGraphUser[]]
        $Users
    )

    foreach ($User in $Users) {

        # Iterate through each license assigned to the user and remove the Intune service plans if the license contains them
        foreach ($UserAssignedLicense in $User.LicenseAssignmentStates) {
    
            # Retrieve the Sku Id of the user assigned license
            $SkuId = $UserAssignedLicense.SkuId

            # If the license is assigned through a group, then skip this license
            if ($UserAssignedLicense.AssignedByGroup)
            {
    
                continue
            }

            # If the license is disabled or in an error state, then skip this license
            if (($UserAssignedLicense.State -eq "Disabled") -or ($UserAssignedLicense.State -eq "Error"))
            {
    
                continue
            }
    
            # Retrieve the license details
            $SubscribedSku = Get-MgSubscribedSku | Where-Object SkuId -eq $SkuId
    
            # Retrieve the new (Intune) service plans that are to be disabled for the new license
            $IntuneServicePlanIds = $SubscribedSku.ServicePlans | Where-Object ServicePlanName -in $IntuneServicePlanNames | Select-Object -ExpandProperty ServicePlanId
            
            # If the license does not contain any Intune service plans, then skip this license
            if (-not $IntuneServicePlanIds) {
    
                continue
            
            }
    
            # Retrieve the service plans that are currently disabled for the user
            $UserDisabledServicePlanIds = $UserAssignedLicense.DisabledPlans
    
            # Merge the new (Intune) service plans that are to be disabled with the user's current state of disabled plans
            $DisabledServicePlanIds = ($UserDisabledServicePlanIds + $IntuneServicePlanIds) | Select-Object -Unique
    
            # If the user's currently disabled plans are the same as the new disabled plans, then skip this license
            if ($DisabledServicePlanIds -eq $UserDisabledServicePlanIds) {
            
                continue
            
            }
    
            $AddLicenses = @(
                @{
                    SkuId = $SkuId
                    DisabledPlans = $DisabledServicePlanIds
                }
            )
    
            # Update user's license
            Set-MgUserLicense -UserId $User.Id -AddLicenses $AddLicenses -RemoveLicenses @()

            # Retrieve the names of the disabled plans
            $DisabledServicePlanNames = $SubscribedSku.ServicePlans | Where-Object ServicePlanId -in $DisabledServicePlanIds | Select-Object -ExpandProperty ServicePlanName

            Write-Host "-----------------------------"
            Write-Host "User: $($User.DisplayName)"
            Write-Host "User Principal Name: $($User.UserPrincipalName)"
            Write-Host "License: $($SubscribedSku.SkuPartNumber)"
            Write-Host "Disabled Service Plans: $($DisabledServicePlanNames -join ', ')"
            Write-Host "-----------------------------"
    
        }
   
    }

}

#####################
#                   #
# MAIN: Script Body #
#                   #
#####################

# Assigning and removing licenses for a group requires the Group.ReadWrite.All permission scope
# Assigning and removing licenses for a user requires the User.ReadWrite.All permission scope
# The Organization.Read.All permission scope is required to read the licenses available in the tenant
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.ReadWrite.All", "Directory.Read.All", "Organization.Read.All" -NoWelcome

# If the user specified the GroupDisplayNames parameter set
if ($GroupDisplayNames) {

    # Get the groups with the specified display names and assigned licenses
    # !! Groups without any assigned licenses will be skipped !!
    $Groups = $GroupDisplayNames | Foreach-Object {Get-MgGroup -Filter "DisplayName eq '$_'" -Property Id, MailNickname, DisplayName, GroupTypes, Description, AssignedLicenses} #| Where-Object AssignedLicenses -ne $null

    if (-not $Groups) {

        Write-Error "Unable to find any groups with assigned licenses and the specified display names: $($GroupDisplayNames -join ', ')"

    }
    else {

        Write-Host "Disabling the Intune service plans for the following groups: $($Groups.DisplayName -join ', ')"

        # Disable the Intune service plans from the groups
        Disable-IntuneServicePlansForGroups -Groups $Groups

    }

}
# If the user specified the UserPrincipalNames parameter set
elseif ($UserPrincipalNames) {

    # Get the users with the specified user principal names and assigned licenses
    # !! Users without any assigned licenses will be skipped !!
    $Users = $UserPrincipalNames | Foreach-Object {Get-MgUser -Filter "UserPrincipalName eq '$_'" -Property DisplayName, Id, Mail, UserPrincipalName, LicenseAssignmentStates}# | Where-Object LicenseAssignmentStates -ne $null

    if (-not $Users) {

        Write-Error "Unable to find any users with assigned licenses and the specified user principal names: $($UserPrincipalNames -join ', ')"

    }
    else {

        Write-Host "Disabling the Intune service plans for the following users: $($Users.DisplayName -join ', ')"

        # Disable the Intune service plans from the users
        Disable-IntuneServicePlansForUsers -Users $Users
        
    }

}
# If the user specified the AllGroups parameter set
elseif ($AllGroups) {

    # Get all groups with assigned licenses
    $Groups = Get-MgGroup -All -Property Id, MailNickname, DisplayName, GroupTypes, Description, AssignedLicenses# | Where-Object AssignedLicenses -ne $null

    Write-Host "Disabling the Intune service plans for the following groups: $($Groups.DisplayName -join ', ')"

    # Disable the Intune service plans from the groups
    Disable-IntuneServicePlansForGroups -Groups $Groups

}
# If the user specified the AllUsers parameter set
elseif ($AllUsers) {

    # Get all users with assigned licenses
    $Users = Get-MgUser -All -Property DisplayName, Id, Mail, userPrincipalName, LicenseAssignmentStates# | Where-Object LicenseAssignmentStates -ne $null
    
    Write-Host "Disabling the Intune service plans for the following users: $($Users.DisplayName -join ', ')"

    # Disable the Intune service plans from all users
    Disable-IntuneServicePlansForUsers -Users $Users

}
elseif ($InputFilePath) {

    # Verify that the CSV file exists
    if (-not (Test-Path -Path $InputFilePath)) {

        Write-Error "The specified file path does not exist: $InputFilePath"

    }

    # Import the CSV file creating custom objects with two properties: Name and Type
    $DirectoryObjects = Import-CSV -Path $InputFilePath

    # Verify the schema of the CSV file by retrieveing the Note (Static) properties of the PSCustomObject objects
    $ColumnHeaders =  $DirectoryObjects | Get-Member -MemberType NoteProperty | Sort-Object -Property Name

    # Verify that the PSCustomObject objects have two Note (Static) properties named "Name" and "Type"
    if (($ColumnHeaders[0].Name -ne "Name") -or ($ColumnHeaders[1].Name -ne "Type")) {

        Write-Error "The script requires a CSV file with 2 column headers: Name (Group Display Name or User Principal Name) and Type (Group or User)."

    }

    # Get the users with the user principal names specified in the input file path and that have assigned licenses 
    # !! Users without any assigned licenses will be skipped !!
    $Users = $DirectoryObjects | Where-Object Type -eq "User" | ForEach-Object {Get-MgUser -Filter "UserPrincipalName eq '$($_.Name)'" -Property DisplayName, Id, Mail, UserPrincipalName, LicenseAssignmentStates}# | Where-Object LicenseAssignmentStates -ne $null

    if (-not $Users) {

        Write-Error "Unable to find any users with the specified user principal names: $($UserPrincipalNames -join ', ')"

    }
    else {

        Write-Host "Disabling the Intune service plans for the following users: $($Users.DisplayName -join ', ')"

        # Disable the Intune service plans from the users
        Disable-IntuneServicePlansForUsers -Users $Users

    }

    # Get the groups with the display names specified in the input file path and that have assigned licenses
    # !! Groups without any assigned licenses will be skipped !!
    $Groups = $DirectoryObjects | Where-Object Type -eq "Group" | ForEach-Object {Get-MgGroup -Filter "DisplayName eq '$($_.Name)'" -Property Id, MailNickname, DisplayName, GroupTypes, Description, AssignedLicenses}# | Where-Object AssignedLicenses -ne $null

    if (-not $Groups) {

        Write-Error "Unable to find any groups with the specified display names: $($GroupDisplayNames -join ', ')"

    }
    else {
        
        Write-Host "Disabling the Intune service plans for the following groups: $($Groups.DisplayName -join ', ')"

        # Disable the Intune service plans from the groups
        Disable-IntuneServicePlansForGroups -Groups $Groups

    }

}
else {

    # If the user did not specify any of the valid parameter sets, then display an error message
    Write-Error "You must specify one of the following parameters: GroupDisplayNames, UserPrincipalNames, AllGroups, AllUsers, or InputFilePath."

}
