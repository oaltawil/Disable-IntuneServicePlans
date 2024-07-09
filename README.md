# Disable-IntuneServicePlans.ps1
A sample PowerShell script that that uses Microsoft Graph to disable Microsoft Intune Service Plans from User and Group-Assigned Licenses in Microsoft Entra Id.

## DESCRIPTION
This sample script can be used in five ways: 
    1. Using the GroupDisplayNames parameter, the user can specify the Microsoft Entra Id groups from which to disable the Intune service plans.
    2. Using the UserPrincipalNames parameter, the user can specify the Microsoft Entra Id users from which to disable the Intune service plans.
    3. Using the AllGroups switch parameter, the user can instruct the script to disable the Intune service plans from all Microsoft Entra Id groups in the directory.
    4. Using the AllUsers switch parameter, the user can instruct the script to disable the Intune service plans from all Microsoft Entra Id users in the directory.
    5. Using
