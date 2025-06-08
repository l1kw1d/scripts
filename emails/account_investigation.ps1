# Script PowerShell d'audit complet pour un compte compromis M365

# ===============================
# CONFIGURATION DE BASE
# ===============================
$CompteAdmin = "admin@domaine.com"
$Victime = "victime@domaine.com"
$StartDate = (Get-Date).AddDays(-7).ToString("o")
$ReportPath = "$PWD\rapport_audit_$($Victime.Replace('@','_'))_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"

# Initialiser le fichier de sortie
"Audit de compte : $Victime" | Out-File -FilePath $ReportPath -Encoding UTF8
"Date d'exécution : $(Get-Date)" | Out-File -FilePath $ReportPath -Append
"------------------------------------------------------------`n" | Out-File -FilePath $ReportPath -Append

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
Add-Content $ReportPath "=== [1] Permissions de la boîte aux lettres ==="

Write-Host "-- FullAccess:"
Add-Content $ReportPath "-- FullAccess:"
Get-MailboxPermission -Identity $Victime | Where-Object { $_.AccessRights -like "*FullAccess*" -and $_.IsInherited -eq $false } | Tee-Object -Variable fullAccess | Format-Table User,AccessRights | Out-String | Tee-Object -Variable output | Add-Content $ReportPath
$output

Write-Host "-- SendAs:"
Add-Content $ReportPath "-- SendAs:"
Get-RecipientPermission -Identity $Victime | Tee-Object -Variable sendAs | Format-Table Trustee,AccessRights | Out-String | Tee-Object -Variable output | Add-Content $ReportPath
$output

Write-Host "-- SendOnBehalf:"
Add-Content $ReportPath "-- SendOnBehalf:"
(Get-Mailbox -Identity $Victime).GrantSendOnBehalfTo | Tee-Object -Variable sob | Format-Table Name | Out-String | Tee-Object -Variable output | Add-Content $ReportPath
$output

# ===============================
# 2. RÈGLES DE LA BOÎTE AUX LETTRES
# ===============================
Write-Host "`n=== [2] Règles de messagerie ===" -ForegroundColor Green
Add-Content $ReportPath "`n=== [2] Règles de messagerie ==="
$rules = Get-InboxRule -Mailbox $Victime
if ($rules.Count -eq 0) {
    Write-Host "Aucune règle trouvée."
    Add-Content $ReportPath "Aucune règle trouvée."
} else {
    $rules | Sort-Object Priority | Select-Object Name, Enabled, RedirectTo, ForwardTo, DeleteMessage, MoveToFolder | Tee-Object -Variable ruleList | Format-Table -AutoSize | Out-String | Tee-Object -Variable output | Add-Content $ReportPath
    $output
}

Write-Host "-- Redirections d'autres boîtes:"
Add-Content $ReportPath "-- Redirections d'autres boîtes:"
$redirs = Get-Mailbox -ResultSize Unlimited | ForEach-Object {
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
} 
$redirs | Format-Table -AutoSize | Tee-Object -Variable output | Out-String | Add-Content $ReportPath
$output

# ===============================
# 3. APPS OAUTH AUTORISÉES
# ===============================
Write-Host "`n=== [3] Applications OAuth autorisées ===" -ForegroundColor Green
Add-Content $ReportPath "`n=== [3] Applications OAuth autorisées ==="
$user = Get-MgUser -UserId $Victime
$appConsent = Get-MgUserOauth2PermissionGrant -UserId $user.Id
if ($appConsent) {
    $appConsent | Format-Table ClientId, Scope, ConsentType | Tee-Object -Variable output | Out-String | Add-Content $ReportPath
    $output
} else {
    Write-Host "Aucune app OAuth trouvée."
    Add-Content $ReportPath "Aucune app OAuth trouvée."
}

# ===============================
# 4. DÉLÉGATIONS VERS D'AUTRES BOÎTES
# ===============================
Write-Host "`n=== [4] Accès vers d'autres boîtes partagées ===" -ForegroundColor Green
Add-Content $ReportPath "`n=== [4] Accès vers d'autres boîtes partagées ==="
Get-Mailbox -RecipientTypeDetails SharedMailbox | ForEach-Object {
    $shared = $_.PrimarySmtpAddress
    Get-MailboxPermission -Identity $shared | Where-Object { $_.User -like $Victime -and $_.IsInherited -eq $false } |
    Select-Object @{Name="BoitePartagee";Expression={$shared}}, User, AccessRights
} | Format-Table -AutoSize | Tee-Object -Variable output | Out-String | Add-Content $ReportPath
$output

# ===============================
# 5. SIGN-IN LOGS (AZURE AD)
# ===============================
Write-Host "`n=== [5] Sign-in logs Azure AD ===" -ForegroundColor Green
Add-Content $ReportPath "`n=== [5] Sign-in logs Azure AD ==="
$userId = $user.Id
Get-MgAuditLogSignIn -Filter "userId eq '$userId' and createdDateTime ge $StartDate" -All |
Select-Object createdDateTime, ipAddress, appDisplayName, clientAppUsed, conditionalAccessStatus |
Sort-Object createdDateTime -Descending |
Format-Table -AutoSize | Tee-Object -Variable output | Out-String | Add-Content $ReportPath
$output

# ===============================
# 6. AUDIT UNIFIÉ (PURVIEW)
# ===============================
Write-Host "`n=== [6] Audit unifié Microsoft 365 ===" -ForegroundColor Green
Add-Content $ReportPath "`n=== [6] Audit unifié Microsoft 365 ==="
Search-UnifiedAuditLog -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date) -UserIds $Victime -ResultSize 1000 |
Where-Object { $_.ClientIP -ne $null } |
Select-Object CreationDate, Operation, ClientIP, Workload, RecordType |
Sort-Object CreationDate -Descending |
Format-Table -AutoSize | Tee-Object -Variable output | Out-String | Add-Content $ReportPath
$output

# ===============================
# NETTOYAGE
# ===============================
Write-Host "`n[+] Suppression de l'application Microsoft Graph enregistrée dans la session." -ForegroundColor Yellow
$app = Get-MgContext
if ($app -and $app.ClientId -ne $null) {
    try {
        Remove-MgApplication -ApplicationId $app.ClientId -ErrorAction Stop
        Write-Host "Application supprimée avec succès."
    } catch {
        Write-Host "Impossible de supprimer l'application automatiquement. Vérifiez manuellement si nécessaire." -ForegroundColor Red
    }
}

Disconnect-ExchangeOnline -Confirm:$false
Disconnect-MgGraph

Write-Host "`n[+] Rapport généré : $ReportPath" -ForegroundColor Cyan
Write-Host "[+] Analyse terminée et session déconnectée." -ForegroundColor Cyan
