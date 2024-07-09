<#PSScriptInfo

.GUID cb5f3368-02b7-431c-b75b-03c2dbd46e50

.AUTHOR oaltawil@microsoft.com

.COMPANYNAME Microsoft Canada

.LICENSEURI https://www.gnu.org/licenses/gpl-3.0.en.html

#>

#Requires -PSEdition Core

#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.groups, Microsoft.Graph.Users, Microsoft.Graph.Identity.DirectoryManagement

<#
.NOTES
This sample script is not supported under any Microsoft standard support program or service. The sample script is provided AS IS without warranty of any kind. Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample script remains with you. 
In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the script be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample script, even if Microsoft has been advised of the possibility of such damages.

.SYNOPSIS
This sample script can be used to retrieve details of the licenses that have been assigned to Microsoft Entra Id groups or Users

.DESCRIPTION
This sample script can be used in five ways: 
    1. Using the GroupDisplayNames parameter, the user can specify the Microsoft Entra Id groups
    2. Using the UserPrincipalNames parameter, the user can specify the Microsoft Entra Id users
    3. Using the AllGroups switch parameter, the user can retrieve the license details for all Microsoft Entra Id groups in the directory.
    4. Using the AllUsers switch parameter, the user can retrieve the license deteails from all Microsoft Entra Id users in the directory.
    5. Using the InputFilePath parameter, the user can specify the file path to a CSV (comma-separated value) file that contains group display names and user principal names

.PARAMETER GroupDisplayNames
The display names of one or more Microsoft Entra Id groups for which you want to retrieve the license details.

.PARAMETER UserPrincipalNames
The user principal names of one or more Microsoft Entra Id Users for which you want to retrieve the license details.

.PARAMETER AllGroups
The AllGroups switch parameter instructs the script to retrieve the license details for all Microsoft Entra Id groups in the directory.

.PARAMETER AllUsers
The AllUsers switch parameter instructs the script to retrieve the license details for all Microsoft Entra Id Users in the directory.

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
Get-AssignedLicenses.ps1 -GroupDisplayNames "User Group 01", "User Group 02"

    The above command retrieves license details for the groups with the specified display names.

.EXAMPLE
Get-AssignedLicenses.ps1 -UserPrincipalNames "user01@contoso.com", "user02@consoto.com"

    The above command retrieves license details for the users with the specified user principal names.

.EXAMPLE
Get-AssignedLicenses.ps1 -AllGroups

    The above command retrieves license details for all groups in the directory

.EXAMPLE
Get-AssignedLicenses.ps1 -AllUsers

    The above command retrieves license details for all users in the directory.
    
.EXAMPLE

Get-AssignedLicenses.ps1 -InputFilePath .\GroupUserList.csv

    The above command retrieves license details for the groups and users specified in the CSV file "GroupUserList.csv".

    The CSV (Comma-Separated Value) file must have two column headers: Name and Type.
        
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

    ServicePlanName                             ServicePlanId  
    INTUNE_A (Microsoft Intune)                 c1ec4a95-1f05-45b3-a911-aa3fa01094f5
    INTUNE_EDU (Microsoft Intune for Education) da24caf9-af8e-485c-b7c8-e73336da2693  
#>
$IntuneServicePlanNames = @(
    "Intune_A",
    "Intune_EDU"
)

#####################
#                   #
# MAIN: Script Body #
#                   #
#####################

# Retrieving licenses for a group requires the Group.Read.All permission scope
# Retrieving licenses for a user requires the User.Read.All permission scope
# The Organization.Read.All permission scope is required to read the licenses available in the tenant
Connect-MgGraph -Scopes "Group.Read.All", "User.Read.All", "Directory.Read.All", "Organization.Read.All" -NoWelcome

# If the user specified the GroupDisplayNames parameter set
if ($GroupDisplayNames) {

    # Get the groups with the specified display names and assigned licenses
    # !! Groups without any assigned licenses will be skipped !!
    $Groups = $GroupDisplayNames | Foreach-Object {Get-MgGroup -Filter "DisplayName eq '$_'" -Property Id, MailNickname, DisplayName, GroupTypes, Description, AssignedLicenses} | Where-Object AssignedLicenses -ne $null

    # Disable the Intune service plans from the groups
    Get-GroupAssignedLicenses -Groups $Groups

}
# If the user specified the UserPrincipalNames parameter set
elseif ($UserPrincipalNames) {

    # Get the users with the specified user principal names and assigned licenses
    # !! Users without any assigned licenses will be skipped !!
    $Users = $UserPrincipalNames | Foreach-Object {Get-MgUser -Filter "UserPrincipalName eq '$_'" -Property DisplayName, Id, Mail, UserPrincipalName, LicenseAssignmentStates} | Where-Object LicenseAssignmentStates -ne $null

    # Disable the Intune service plans from the users
    Get-UserAssignedLicenses -Users $Users

}
# If the user specified the AllGroups parameter set
elseif ($AllGroups) {

    # Get all groups with assigned licenses
    $Groups = Get-MgGroup -All -Property Id, MailNickname, DisplayName, GroupTypes, Description, AssignedLicenses | Where-Object AssignedLicenses -ne $null

    # Disable the Intune service plans from the groups
    Get-GroupAssignedLicenses -Groups $Groups

}
# If the user specified the AllUsers parameter set
elseif ($AllUsers) {

    # Get all users with assigned licenses
    $Users = Get-MgUser -All -Property DisplayName, Id, Mail, userPrincipalName, LicenseAssignmentStates | Where-Object LicenseAssignmentStates -ne $null

    # Disable the Intune service plans from all users
    Get-UserAssignedLicenses -Users $Users

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
    $Users = $DirectoryObjects | Where-Object Type -eq "User" | ForEach-Object {Get-MgUser -Filter "UserPrincipalName eq '$($_.Name)'" -Property DisplayName, Id, Mail, UserPrincipalName, LicenseAssignmentStates} | Where-Object LicenseAssignmentStates -ne $null

    # Disable the Intune service plans from the users
    Get-UserAssignedLicenses -Users $Users

    # Get the groups with the display names specified in the input file path and that have assigned licenses
    # !! Groups without any assigned licenses will be skipped !!
    $Groups = $DirectoryObjects | Where-Object Type -eq "Group" | ForEach-Object {Get-MgGroup -Filter "DisplayName eq '$($_.Name)'" -Property Id, MailNickname, DisplayName, GroupTypes, Description, AssignedLicenses} | Where-Object AssignedLicenses -ne $null

    # Disable the Intune service plans from the groups
    Get-GroupAssignedLicenses -Groups $Groups

}
else {

    # If the user did not specify any of the valid parameter sets, then display an error message
    Write-Error "You must specify one of the following parameters: GroupDisplayNames, UserPrincipalNames, AllGroups, AllUsers, or InputFilePath."

}

function Get-GroupAssignedLicenses {
    param (
        [Parameter(Mandatory=$true)]
        [Microsoft.Graph.Groups.Group[]]
        $Groups
    )

    foreach ($Group in $Groups) {

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

    }

}

function Get-UserAssignedLicenses {
    param (
        [Parameter(Mandatory=$true)]
        [Microsoft.Graph.Users.User[]]
        $Users
    )

    foreach ($User in $Users) {

        Write-Host "User: $($User.DisplayName)"

        $UserAssignedLicenses = $User.LicenseAssignmentStates

        foreach ($License in $UserAssignedLicenses) {

            # Retrieve the license details
            $SubscribedSku = Get-MgSubscribedSku | Where-Object SkuId -eq $License.SkuId

            $DisabledServicePlanIds = $License.DisabledPlans

            $DisabledServicePlanNames = $SubscribedSku.ServicePlans | Where-Object ServicePlanId -in $DisabledServicePlanIds | Select-Object -ExpandProperty ServicePlanName

            Write-Host "`t License: $($SubscribedSku.SkuPartNumber)"

            Write-Host "`t `t Disabled Service Plans: $($DisabledServicePlanNames -join ', ') `n"

        }

    }

}