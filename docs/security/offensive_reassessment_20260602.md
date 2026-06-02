# Security Review: ai-cli-sentinel offensive reassessment

## Scope

- Repository: `C:\Dev\ai-cli-sentinel`
- Commit: `b68237f`
- Scan mode: repository-wide offensive reassessment of the prior zero-findings report.
- Constraint: repository code was not modified.
- Validation mode: static code tracing, prior report challenge, and current threat-context verification.
- Reviewed code evidence: `src/AI-CLI-Sentinel.ps1`, `src/agents.allowlist.json`, `.github/workflows/ci-lint.yml`, and `scripts/run-tests.ps1`.
- External context verified: Microsoft Mini Shai-Hulud @antv report, Microsoft Axios/Sapphire Sleet report, TanStack npm compromise postmortem, Sonar Mini Shai-Hulud AI-agent persistence analysis, and Cloud Security Alliance Mini Shai-Hulud npm/PyPI research.

### Scan Summary

| Field | Value |
| --- | --- |
| Reportable findings | 2 |
| Severity mix | 1 medium, 1 low |
| Confidence mix | 1 high, 1 medium |
| Coverage | Primary updater, allowlist trust root, CI workflow, test runner dependency bootstrap |
| Main conclusion | No direct shell injection found, but the prior zero-findings report underestimates supply-chain update integrity and secret-handling risks. |

## Threat Model

AI-CLI-Sentinel is a privileged Windows PowerShell updater for AI CLI agents. The important boundary is not only remote attacker input; it is the transition from user-writable or registry-controlled state into administrator-context global package updates.

Assets that matter:

- Global AI CLI binaries and shims updated by npm, winget, and uv.
- Local developer secrets in `.ssh`, `.npmrc`, `.config`, and AI-agent configuration files.
- The allowlist and candidate files that decide what can be updated.
- The integrity of version metadata, registry artifacts, provenance, and package-manager sources.
- CI workflows and test bootstrapping used to maintain the project.

Threats considered:

- Registry or maintainer compromise under legitimate package namespaces.
- Lower-privileged malware pre-positioning config or candidate files before an administrator run.
- Latest-tag drift between metadata check and installation.
- AI-agent persistence through `.claude/settings.json`, `.vscode/tasks.json`, and similar execution-bearing configuration files.
- Plaintext secret duplication into Desktop or synced profile locations.
- CI/CD cache, dependency bootstrap, and package-manager trust-boundary abuse.

Current threat context changes the risk model. Microsoft reported Mini Shai-Hulud attacks against `@antv` packages that stole CI/CD credentials, scraped runner memory, and forged SLSA provenance. TanStack documented cache poisoning and OIDC extraction leading to malicious publication across 42 packages. Microsoft attributed the Axios npm compromise to Sapphire Sleet, where malicious versions retrieved a second-stage RAT. Sonar documented AI-agent persistence through `.claude/settings.json` and `.vscode/tasks.json`. CSA reported npm and PyPI impact across AI-specific packages.

Sources:

- Microsoft Mini Shai-Hulud @antv: https://www.microsoft.com/en-us/security/blog/2026/05/20/mini-shai-hulud-compromised-antv-npm-packages-enable-ci-cd-credential-theft/
- Microsoft Axios/Sapphire Sleet: https://www.microsoft.com/en-us/security/blog/2026/04/01/mitigating-the-axios-npm-supply-chain-compromise/
- TanStack postmortem: https://tanstack.com/blog/npm-supply-chain-compromise-postmortem
- Sonar AI-agent persistence: https://www.sonarsource.com/blog/mini-shai-hulud-targets-ai-coding-agents
- Cloud Security Alliance npm/PyPI: https://labs.cloudsecurityalliance.org/research/csa-research-note-mini-shai-hulud-ai-supply-chain-20260513-c/

## Findings

| Severity | Finding | Confidence |
| --- | --- | --- |
| Medium | [Moving-target package updates create TOCTOU exposure after version assessment](#1-moving-target-package-updates-create-toctou-exposure-after-version-assessment) | High |
| Low | [Secret backup broadens AI-developer exfiltration surface](#2-secret-backup-broadens-ai-developer-exfiltration-surface) | Medium |

### Confidence Scale

| Label | Meaning |
| --- | --- |
| high | Direct source, configuration, or runtime evidence supports the finding, with no material unresolved reachability or exploitability blocker. |
| medium | Source evidence supports a plausible issue, but runtime behavior, deployment configuration, role reachability, type constraints, or exploit reliability still need proof. |
| low | Weak or incomplete evidence; include only when the user explicitly wants follow-up candidates in the final report. |

### [1] Moving-target package updates create TOCTOU exposure after version assessment

| Field | Value |
| --- | --- |
| Severity | medium |
| Confidence | high |
| Confidence rationale | Static code tracing directly shows metadata checks followed by unpinned moving-target install or upgrade commands. |
| Category | Supply-chain update integrity / TOCTOU |
| CWE | CWE-367 Time-of-check Time-of-use Race Condition; CWE-494 Download of Code Without Integrity Check |
| Affected lines | `src/AI-CLI-Sentinel.ps1:733-748`, `src/AI-CLI-Sentinel.ps1:800-818`, `src/AI-CLI-Sentinel.ps1:878-892` |

#### Summary

The script assesses package state, then installs or upgrades by a mutable target. npm queries `npm view <name> version`, but updates with `<name>@latest`. uv queries PyPI JSON, but upgrades with `uv tool upgrade <name>`. winget parses an available version, but upgrades by package ID without pinning an exact manifest, source, or hash.

#### Validation

Validation used static source tracing. The vulnerable pattern is visible in the code: version checks at `src/AI-CLI-Sentinel.ps1:733`, `800`, and `878` are separated from update sinks at `748`, `818`, and `892`. The post-install version checks detect mismatch only after installation has occurred.

#### Dataflow

Allowlist entry -> installed-version query -> latest-version or available-version query -> moving-target install or upgrade -> global binary/tool replacement -> post-install status check.

#### Reachability

A realistic attacker path is registry or maintainer compromise under a legitimate package namespace, not shell injection. Recent incidents show this is realistic: malicious versions under legitimate namespaces were published in npm and PyPI ecosystems. If a malicious latest version appears between check and install, or if the checked latest is itself malicious, AI-CLI-Sentinel can install the malicious artifact globally.

#### Severity

Medium. The script does not itself execute shell-injected code, and npm uses `--ignore-scripts`, which lowers immediate execution risk. The impact remains meaningful because the tool updates globally installed AI CLIs and can replace binaries or package contents with malicious artifacts. Exact artifact pinning and integrity verification would lower severity; proof of immediate admin-context execution during update would raise it.

#### Remediation

Resolve updates to immutable tuples before installation: ecosystem, package ID, exact version, registry/source, integrity hash, signature/provenance, publish time, and malicious-package/advisory status. Install exact versions, not `latest` or unconstrained upgrades. For npm, install `<package>@<exactVersion>` and verify dist integrity. For uv/PyPI, pin exact versions and verify metadata plus malicious-package feeds. For winget, pin source, version, manifest, and installer hash.

### [2] Secret backup broadens AI-developer exfiltration surface

| Field | Value |
| --- | --- |
| Severity | low |
| Confidence | medium |
| Confidence rationale | Source evidence confirms plaintext copies of sensitive paths to Desktop; concrete exposure depends on endpoint sync and DLP configuration. |
| Category | Sensitive material handling / defensive-control footgun |
| CWE | CWE-200 Exposure of Sensitive Information to an Unauthorized Actor; CWE-922 Insecure Storage of Sensitive Information |
| Affected lines | `src/AI-CLI-Sentinel.ps1:694-704` |

#### Summary

`-BackupSecrets` copies `$HOME\.config`, `$HOME\.ssh`, and `$HOME\.npmrc` to `$HOME\Desktop\AI_Backup_<date>`. This can duplicate high-value developer secrets into a location commonly indexed, synced, retained, or watched by enterprise tooling and malware.

#### Validation

Static code evidence confirms the backup paths at `src/AI-CLI-Sentinel.ps1:696-701`. `Copy-Item` uses `-ErrorAction SilentlyContinue`, so skipped or partial copies may not be visible to the operator.

#### Dataflow

Operator enables `-BackupSecrets` -> script creates Desktop backup directory -> script copies `.config`, `.ssh`, and `.npmrc` recursively -> secrets exist in original and backup locations.

#### Reachability

The attacker model is post-compromise exfiltration or enterprise cloud-sync exposure, not remote unauthenticated access. This matters because current AI-developer malware scans credential and AI-agent configuration paths. Duplicating secrets onto Desktop can increase the number of locations malware or sync services can access.

#### Severity

Low. The feature is opt-in and local, and no attacker-controlled destination is visible in the default path. The severity would rise if Desktop is OneDrive-synced by policy, if backup ACLs are weaker than source ACLs, or if the tool is used broadly on developer workstations with cloud credentials in `.config` or `.npmrc`.

#### Remediation

Use encrypted backups protected with DPAPI or enterprise KMS. Refuse Desktop or known cloud-synced destinations by default. Preserve ACLs, record copied file counts and failures, and produce a manifest. Add explicit support for scanning AI-agent persistence files before and after backup/update.

## Reviewed Surfaces

| Surface | Risk Area | Outcome | Notes |
| --- | --- | --- | --- |
| `src/AI-CLI-Sentinel.ps1` npm update flow | Supply-chain integrity | Reported | Version is checked, but install uses `@latest`; malicious latest drift can win after the check. |
| `src/AI-CLI-Sentinel.ps1` uv/PyPI update flow | Supply-chain integrity | Reported | PyPI version metadata is checked, but `uv tool upgrade` is not pinned to the exact artifact assessed. |
| `src/AI-CLI-Sentinel.ps1` winget update flow | Supply-chain integrity | Reported | `winget upgrade --id` pins identity but not an exact reviewed manifest/hash. |
| `src/AI-CLI-Sentinel.ps1` `-BackupSecrets` | Secret handling | Reported | Plaintext Desktop backup increases exfil/sync surface. |
| `src/AI-CLI-Sentinel.ps1` command invocation | Shell injection | Rejected | No dynamic shell string execution was found in the reviewed package-manager calls. |
| `src/agents.allowlist.json` | Trust root poisoning | Needs follow-up | Defaults are static, but policy files are repo-local and should be protected before elevated runs. |
| `.github/workflows/ci-lint.yml` | CI trust boundary | Rejected | Uses `pull_request`, not `pull_request_target`; no secrets referenced. |
| `scripts/run-tests.ps1` | CI dependency bootstrap | Needs follow-up | Installs Pester from PowerShell Gallery with `-SkipPublisherCheck`; low impact here, but misaligned with supply-chain defense goals. |

## Challenged Assumptions And Blind Spots

- The prior report’s “trusted operator” assumption ignores elevated handoff. `ConfigFile` and `CandidatesFile` default under `$PSScriptRoot`, are read at `src/AI-CLI-Sentinel.ps1:544` and `621`, and are written at `671-672`. If a lower-privileged process can poison repo-local policy before an admin run, the allowlist is not a protected trust root.
- `--ignore-scripts` is useful but incomplete. It blocks npm lifecycle scripts, but it does not verify package contents, global CLI shims, future execution of installed binaries, npm cache state, uv/PyPI packages, or winget manifests.
- AI-agent persistence is outside the current protection model. The tool does not inspect `.claude/settings.json`, `.vscode/tasks.json`, Cursor/Gemini/Codex state, MCP configs, or agent hook files.
- npm receives more validation than other ecosystems. npm candidate names are validated with `Test-NpmPackageName`; uv names are trimmed only, and winget IDs are not validated beyond PowerShell argument separation.
- VSS failure is not silent, but rollback is conditional. The script logs failure and prompts whether to continue. If the operator continues, global updates proceed without the rollback guarantee.

## Architecture Hardening Recommendations

1. Replace latest-based updates with artifact-pinned, policy-gated updates. Generate a signed update plan containing exact version, source, hash, provenance, publish time, and malicious-package/advisory status. Install only that exact artifact.

2. Move trust roots out of the repository and enforce config integrity. Store policy under an admin-only ACL such as `%ProgramData%\AI-CLI-Sentinel\policy`, sign allowlists and candidate approvals, verify owner/ACL/path canonicalization before elevated use, and record policy hashes in reports.

3. Add AI-agent compromise detection and secure backup semantics. Scan `.claude/`, `.vscode/tasks.json`, Cursor/Gemini/Codex/MCP configs, and suspicious `setup.mjs` or Bun bootstrap artifacts. Back up secrets only to encrypted DPAPI/KMS-protected archives, block Desktop/OneDrive-synced destinations by default, and monitor update windows for unexpected Node/npm/Bun/python execution and outbound connections.
