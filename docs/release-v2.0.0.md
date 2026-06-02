# v2.0.0 - Security Hardening & Trust Root Migration

This major release introduces critical security enhancements designed to protect AI development environments against sophisticated supply chain attacks (e.g., Mini Shai-Hulud, Sapphire Sleet operations) observed in May/June 2026.

⚠️ **BREAKING CHANGES**

This release changes how backups and trust policies are handled to prevent credential exfiltration and unauthorized policy poisoning.

1. **Strict Backup Paths:** The `-BackupSecrets` flag no longer defaults to the Desktop. You MUST provide an explicit, non-cloud-synced destination using `-BackupPath`.
2. **Admin-Controlled Trust Root:** The `agents.allowlist.json` file is no longer read securely from the local repository directory. It must reside in a protected system directory.

## 🚀 Migration Guide for Existing Users

To ensure your existing allowlist continues to work without triggering security warnings, run the following PowerShell command as Administrator to migrate your policy to the new secure location:

```powershell
# Create the secure policy directory and migrate the existing allowlist
$PolicyDir = "$env:ProgramData\AI-CLI-Sentinel\policy"
New-Item -Path $PolicyDir -ItemType Directory -Force
Copy-Item ".\src\agents.allowlist.json" -Destination "$PolicyDir\agents.allowlist.json" -Force
Write-Host "Migration complete. Trust root secured at: $PolicyDir" -ForegroundColor Green
```
