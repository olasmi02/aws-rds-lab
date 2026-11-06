<#
  Phase 3: OU structure, five test users and the RDS-Users group.
  Run on DC01 as LEYELAB\Administrator. The password is typed at a prompt,
  never stored in the script.
#>

$root = "DC=leyelab,DC=internal"
New-ADOrganizationalUnit -Name "LeyeLab" -Path $root
foreach ($ou in "Staff","Groups","Servers") {
    New-ADOrganizationalUnit -Name $ou -Path "OU=LeyeLab,$root"
}

$pw = Read-Host -AsSecureString "Password for the test users"
$users = @(
    @{First="Amaka"; Last="Obi"},
    @{First="Tunde"; Last="Bello"},
    @{First="Grace"; Last="Eze"},
    @{First="Musa";  Last="Ali"},
    @{First="Sade";  Last="Ade"}
)
foreach ($u in $users) {
    $sam = ($u.First + "." + $u.Last).ToLower()
    New-ADUser -Name "$($u.First) $($u.Last)" -GivenName $u.First -Surname $u.Last `
        -SamAccountName $sam -UserPrincipalName "$sam@leyelab.internal" `
        -Path "OU=Staff,OU=LeyeLab,$root" -AccountPassword $pw -Enabled $true
}

# Remote access is granted to a group, never to individual users.
# Musa and Sade are left out on purpose to test refusals.
New-ADGroup -Name "RDS-Users" -GroupScope Global -GroupCategory Security -Path "OU=Groups,OU=LeyeLab,$root"
Add-ADGroupMember -Identity "RDS-Users" -Members amaka.obi, tunde.bello, grace.eze
Get-ADGroupMember RDS-Users | Select-Object Name
