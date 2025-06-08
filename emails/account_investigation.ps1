# Remplace par le compte compromis
$User = "user@domaine.com"

# Connexion à Exchange Online
Connect-ExchangeOnline -UserPrincipalName ton.admin@domaine.com

# Connexion à MSGraph (si non déjà installé : Install-Module Microsoft.Graph)
Connect-MgGraph -Scopes "AuditLog.Read.All", "User.Read.All", "Mail.Read"

# Début du rapport
Write-Host "==== ANALYSE DE COMPTE COMPROMIS POUR: $User ====" -ForegroundColor Cyan

# 1. Permissions sur la boîte
Write-Host "`n--- [1] Full Access Permissions ---"
Get-MailboxPermission -Identity $User | Where-Object { $_.AccessRights -like "*FullAccess*" -and $_.IsInherited -eq $false } | Format-Table User,AccessRights

Write-Host "`n--- [2] Send As Permissions ---"
Get-RecipientPermission -Identity $User | Format-Table Trustee,AccessRights

Write-Host "`n--- [3] Send On Behalf ---"
(Get-Mailbox -Identity $User).GrantSendOnBehalfTo | Format-Table Name

# 2. Règles de boîte
Write-Host "`n--- [4] Règles de boîte aux lettres suspectes ---"
Get-InboxRule -Mailbox $User | Where-Object { $_.RedirectTo -or $_.ForwardTo -or $_.DeleteMessage } | 
Format-Table Name, Enabled, RedirectTo, ForwardTo, DeleteMessage, Description

# 3. Apps OAuth autorisées
Write-Host "`n--- [5] Applications OAuth autorisées ---"
$appConsent = Get-MgUserOauth2PermissionGrant -UserId $User
if ($appConsent) {
    $appConsent | Format-Table ClientId, Scope, ConsentType
} else {
    Write-Host "Aucune app OAuth trouvée pour cet utilisateur."
}

# 4. Délégations dans boîtes partagées
Write-Host "`n--- [6] Accès du compte à d'autres boîtes partagées ---"
Get-Mailbox -RecipientTypeDetails SharedMailbox | ForEach-Object {
    $mb = $_.PrimarySmtpAddress.ToString()
    Get-MailboxPermission -Identity $mb | Where-Object { $_.User -like $User -and $_.IsInherited -eq $false } |
    Select-Object @{Name="Boîte";Expression={$mb}}, User, AccessRights
} | Format-Table

# 5. Connexions récentes (7 derniers jours)
Write-Host "`n--- [7] Connexions récentes (7 derniers jours) ---"
$start = "2025-06-01T18:14:50Z"
$end = "2025-06-08T18:14:50Z"

Search-UnifiedAuditLog -StartDate $start -EndDate $end -UserIds $User -RecordType AzureActiveDirectoryAccountLogon |
Select-Object CreationDate, Operations, ClientIP, UserIds | Format-Table

# Déconnexion
Disconnect-ExchangeOnline -Confirm:$false
Disconnect-MgGraph
