# Script PowerShell d'audit complet pour un compte compromis M365

# ===============================
# CONFIGURATION DE BASE
# ===============================
$CompteAdmin = "admin@domaine.com"
$Victime = "victime@domaine.com"
$StartDate = (Get-Date).AddDays(-7).ToString("o")

# ===============================
# CONNEXIONS
# ===============================
Write-Host "[+] Connexion au module Graph API..." -ForegroundColor Cyan
Connect-MgGraph -Scopes "AuditLog.Read.All", "Directory.Read.All", "User.Read.All"

Write-Host "[+] Connexion au module Exchange Online..." -ForegroundColor Cyan
Connect-ExchangeOnline -UserPrincipalName $CompteAdmin

# ===============================
# 1. PERMISSIONS DE BOÎTE AUX LETTRES
# ===============================
Write-Host "`n=== [1] Permissions de la boîte aux lettres ===" -ForegroundColor Green

Write-Host "- FullAccess:" -ForegroundColor Yellow
Get-MailboxPermission -Identity $Victime | Where-Object { $_.AccessRights -like "*FullAccess*" -and $_.IsInherited -eq $false } | Format-Table User,AccessRights

Write-Host "- SendAs:" -ForegroundColor Yellow
Get-RecipientPermission -Identity $Victime | Format-Table Trustee,AccessRights

Write-Host "- SendOnBehalf:" -ForegroundColor Yellow
(Get-Mailbox -Identity $Victime).GrantSendOnBehalfTo | Format-Table Name

# ===============================
# 2. RÈGLES DE LA BOÎTE AUX LETTRES
# ===============================
Write-Host "`n=== [2] Règles de messagerie ===" -ForegroundColor Green
$rules = Get-InboxRule -Mailbox $Victime
if ($rules.Count -eq 0) {
    Write-Host "Aucune règle trouvée."
} else {
    $rules | Sort-Object Priority | Select-Object Name, Enabled, RedirectTo, ForwardTo, DeleteMessage, MoveToFolder | Format-Table -AutoSize
}

Write-Host "- Recherche de redirections provenant d'autres boîtes..." -ForegroundColor Yellow
Get-Mailbox -ResultSize Unlimited | ForEach-Object {
    $src = $_.PrimarySmtpAddress
    $rules = Get-InboxRule -Mailbox $src -ErrorAction SilentlyContinue
    foreach ($r in $rules) {
        if ($r.RedirectTo -contains $Victime -or $r.ForwardTo -contains $Victime) {
            [PSCustomObject]@{
                SourceMailbox = $src
                RuleName = $r.Name
                ForwardTo = $r.ForwardTo
                RedirectTo = $r.RedirectTo
            }
        }
    }
} | Format-Table -AutoSize

# ===============================
# 3. APPS OAUTH AUTORISÉES
# ===============================
Write-Host "`n=== [3] Applications OAuth autorisées ===" -ForegroundColor Green
$user = Get-MgUser -UserId $Victime
$appConsent = Get-MgUserOauth2PermissionGrant -UserId $user.Id
if ($appConsent) {
    $appConsent | Format-Table ClientId, Scope, ConsentType
} else {
    Write-Host "Aucune app OAuth trouvée."
}

# ===============================
# 4. DÉLÉGATIONS VERS D'AUTRES BOÎTES
# ===============================
Write-Host "`n=== [4] Accès du compte vers d'autres boîtes partagées ===" -ForegroundColor Green
Get-Mailbox -RecipientTypeDetails SharedMailbox | ForEach-Object {
    $shared = $_.PrimarySmtpAddress
    Get-MailboxPermission -Identity $shared | Where-Object { $_.User -like $Victime -and $_.IsInherited -eq $false } |
    Select-Object @{Name="BoitePartagee";Expression={$shared}}, User, AccessRights
} | Format-Table -AutoSize

# ===============================
# 5. SIGN-IN LOGS (AZURE AD)
# ===============================
Write-Host "`n=== [5] Sign-in logs Azure AD (IP, app, résultat) ===" -ForegroundColor Green
$userId = $user.Id
Get-MgAuditLogSignIn -Filter "userId eq '$userId' and createdDateTime ge $StartDate" -All |
Select-Object createdDateTime, ipAddress, appDisplayName, clientAppUsed, conditionalAccessStatus |
Sort-Object createdDateTime -Descending |
Format-Table -AutoSize

# ===============================
# 6. AUDIT UNIFIÉ (PURVIEW)
# ===============================
Write-Host "`n=== [6] Audit unifié Microsoft 365 (Exchange, SharePoint, etc.) ===" -ForegroundColor Green
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) -UserIds $Victime -ResultSize 1000 |
Where-Object { $_.ClientIP -ne $null } |
Select-Object CreationDate, Operation, ClientIP, Workload, RecordType |
Sort-Object CreationDate -Descending |
Format-Table -AutoSize

# ===============================
# NETTOYAGE
# ===============================
Disconnect-ExchangeOnline -Confirm:$false
Disconnect-MgGraph

Write-Host "`n[+] Analyse terminée." -ForegroundColor Cyan
