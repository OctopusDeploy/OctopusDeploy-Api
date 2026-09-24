# Octopus Deploy RBAC Usage Report

A single Python script that generates a report of an Octopus Deploy account's
access-control configuration:

- **Users** and the teams they belong to
- **How** each team membership happened — direct assignment, an external
  identity-provider (SSO/AD) group, or implicit (e.g. the built-in "Everyone"
  team)
- **Roles** granted to each team, and the **scope** of that grant (which
  spaces / projects / project groups / environments / tenants it applies to,
  or "unrestricted")
- The full **permission set** each role grants, with a plain-English
  description of each permission code

Output is JSON, HTML, or both. Users, Teams, and Roles are all included as
independent top-level collections in both formats (not just nested under each
user), so the data is reusable for other tooling.

Uses **only the Python standard library** — no `pip install` required.

## Requirements

- Python 3.8+
- An Octopus Deploy API key. The key's user needs at least read access to
  Users, Teams, User Roles, and Spaces across the account — a **System
  Manager**-level (or higher) key is the simplest way to guarantee that. A
  key scoped to a single space will only see that space's teams/roles.
  See [Octopus's guide on creating an API key](https://octopus.com/docs/octopus-rest-api/how-to-create-an-api-key)
  if you need one.

## Quick start

### Bash / shell (macOS, Linux, WSL)

```bash
# Preview the report layout with built-in synthetic data — no server needed
python3 octopus_rbac_report.py --demo --output both

# Against a real instance (JSON only, the default)
export OCTOPUS_API_KEY="API-XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
python3 octopus_rbac_report.py --url https://myinstance.octopus.app

# Both JSON and HTML, written to a custom folder
python3 octopus_rbac_report.py \
  --url https://myinstance.octopus.app \
  --api-key API-XXXXXXXXXXXXXXXXXXXXXXXXXXXX \
  --output both \
  --output-dir ./reports
```

### PowerShell (Windows, or pwsh on macOS/Linux)

```powershell
# Preview the report layout with built-in synthetic data — no server needed
python octopus_rbac_report.py --demo --output both

# Against a real instance (JSON only, the default)
$env:OCTOPUS_API_KEY = "API-XXXXXXXXXXXXXXXXXXXXXXXXXXXX"
python octopus_rbac_report.py --url https://myinstance.octopus.app

# Both JSON and HTML, written to a custom folder
python octopus_rbac_report.py `
  --url https://myinstance.octopus.app `
  --api-key API-XXXXXXXXXXXXXXXXXXXXXXXXXXXX `
  --output both `
  --output-dir ./reports
```

> On Windows, use `python`, not `python3` (the `python3` alias generally
> isn't on PATH). If you have both Python 2 and 3 installed and `python`
> resolves to the wrong one, use the `py -3` launcher instead:
> `py -3 octopus_rbac_report.py --demo --output both`.

Reports are written as `octopus-rbac-report.json` and/or
`octopus-rbac-report.html` inside `--output-dir` (default:
`./octopus-rbac-report-output`).

### A few more examples

Scoping to specific spaces and skipping name resolution for speed:

```bash
# Bash
python3 octopus_rbac_report.py \
  --url https://myinstance.octopus.app \
  --spaces "Retail,Finance" \
  --no-resolve-scope-names \
  --output json
```

```powershell
# PowerShell
python octopus_rbac_report.py `
  --url https://myinstance.octopus.app `
  --spaces "Retail,Finance" `
  --no-resolve-scope-names `
  --output json
```

Verbose demo run, HTML only:

```bash
# Bash
python3 octopus_rbac_report.py --demo --output html --verbose
```

```powershell
# PowerShell
python octopus_rbac_report.py --demo --output html --verbose
```

## Why there's no `--space` requirement

Octopus's RBAC model has two layers, and the script handles both automatically
so you never have to pick a space up front:

- **Team membership** (who's in a team, directly or via an external
  SSO/AD group) is account-wide — it doesn't vary by space.
- **Role grants** (which permissions a team actually has, and where) can be
  either **system-wide** (via a system team, e.g. "Octopus Administrators")
  or **space-specific** (via a space team's scoped role grant — Octopus's own
  recommended practice). Two users in the same team can end up with different
  effective permissions if that team holds different role grants in different
  spaces.

So the script enumerates every space automatically (`/api/spaces`), pulls
system-level teams/roles once, and merges everything into one account-wide
picture per user — each role grant is labeled either `System-wide` or with the
specific space it applies to. Use `--spaces` if you only want a subset (see
below).

## CLI options

| Option | Description | Default |
|---|---|---|
| `--url` | Octopus Server base URL, e.g. `https://myinstance.octopus.app` | *(required unless `--demo`)* |
| `--api-key` | Octopus API key | falls back to `OCTOPUS_API_KEY` env var |
| `--output` | `json`, `html`, or `both` | `json` |
| `--output-dir` | Directory to write report file(s) into | `./octopus-rbac-report-output` |
| `--spaces` | Comma-separated space names or IDs to include | all spaces |
| `--include-service-accounts` | Include service (API-only) accounts | excluded |
| `--no-resolve-scope-names` | Skip resolving project/environment/tenant IDs to names (faster on very large instances; scopes show raw IDs) | resolved by default |
| `--max-workers` | Thread pool size for per-user/per-space team lookups | `8` |
| `--timeout` | HTTP timeout in seconds | `30` |
| `--demo` | Use built-in synthetic sample data instead of a live server | off |
| `--verbose` | Print progress/debug info to stderr | off |

Never pass the API key as a bare CLI flag on a shared/logged machine if you
can avoid it — prefer the `OCTOPUS_API_KEY` environment variable.

## What gets called (and how much load it puts on your server)

The script uses read-only `GET` requests against these endpoints:

- `/api/users`, `/api/userroles`, `/api/spaces`, `/api/teams` — one paginated
  fetch each, account-wide
- `/api/teams/{id}/scopeduserroles` — one call per team
- `/api/{spaceId}/projects`, `/environments`, `/tenants`, `/projectgroups` —
  one call each per space, only if scope-name resolution is enabled (default)
- `/api/users/{id}/teams?spaces={spaceId}&includeSystem=True` — one call per
  **(user, space)** pair, run concurrently (`--max-workers`, default 8)

That last one is the dominant cost: for `U` users and `S` spaces it's `U × S`
requests. For a typical customer instance (tens of users, a handful of
spaces) this finishes in a few seconds. For very large accounts (hundreds of
users, dozens of spaces), consider `--spaces` to scope down, or run during a
quiet period. The script retries `429`/`5xx` responses with backoff so it
won't hammer a struggling server.

## Report contents

### JSON

```json
{
  "generated_at": "2026-08-20T16:16:06Z",
  "script_version": "1.0.0",
  "spaces": [{"id": "Spaces-1", "name": "Default"}],
  "summary": {"user_count": 12, "active_user_count": 10, "team_count": 6, "role_count": 5, "space_count": 2},
  "users": [
    {
      "id": "users-2",
      "username": "bob.smith",
      "display_name": "Bob Smith",
      "is_active": true,
      "is_service_account": false,
      "team_memberships": [
        {"team_id": "teams-3", "team_name": "DevOps", "team_type": "space",
         "via": "direct", "external_groups": []}
      ],
      "role_grants": [
        {"role_id": "userroles-1", "role_name": "Project Deployer",
         "via_team_id": "teams-3", "via_team_name": "DevOps",
         "space_name": "Retail", "scope_display": "Retail (Environments: Production)"}
      ],
      "effective_space_permissions": ["DeploymentCreate", "ProjectView", "..."],
      "effective_system_permissions": [],
      "associated_spaces": ["Retail", "System-wide"]
    }
  ],
  "teams": [
    {
      "id": "teams-3", "name": "DevOps", "type": "space", "space_name": "Retail",
      "member_user_ids": ["users-2"],
      "external_security_groups": ["AAD-DevOps-Team"],
      "granted_roles": [{"role_name": "Project Deployer", "scope_display": "..."}]
    }
  ],
  "roles": [
    {
      "id": "userroles-1", "name": "Project Deployer", "description": "Can deploy releases",
      "granted_space_permissions": [
        {"code": "ProjectView", "description": "View project settings", "curated": true}
      ],
      "granted_system_permissions": []
    }
  ]
}
```

Users reference teams/roles by id and name only — the full team and role
definitions live once, at the top level, so nothing is duplicated per-user.
`"via"` on a team membership is one of `direct`, `external_group`, or
`implicit` (built-in teams like "Everyone" that include all users
automatically with no explicit member list).

### HTML

A single self-contained file (inline CSS/JS, no CDN dependencies — safe to
open in air-gapped or locked-down environments). It has three tabs:

- **Users** — one collapsible card per user, showing team chips (tagged with
  how membership happened), the roles granted and via which team/scope, and
  the user's full effective permission set
- **Teams** — direct members, configured external identity-provider groups,
  and the roles granted to the team with scope. Each granted role is its own
  expandable row — click it to see that role's full permission list inline,
  without switching to the Roles tab
- **Roles** — full permission list per role, with descriptions

A search box filters all three tabs by name/permission/team/role text. A
**space filter dropdown** next to it narrows Users and Teams down to a single
space (or `System-wide` for system teams/grants); it has no effect on the
Roles tab since role *definitions* aren't space-bound (only their grants are).

## A note on permission descriptions

Octopus's API returns permission **codes** (e.g. `ProjectView`), not
descriptions. This script ships a curated dictionary of plain-English
descriptions for the well-known, stable permission codes. Any code *not* in
that dictionary gets an auto-generated label (the code split into words —
e.g. `SomeNewPermission` → "Some New Permission") and is marked
`"curated": false` in the JSON / "(derived from code)" in the HTML, so it's
never confused with official Octopus documentation. If you spot a gap, add
the code and description to `PERMISSION_DESCRIPTIONS` near the top of the
script.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Authentication failed (401)` | API key is wrong, expired, or revoked |
| `Forbidden (403)` | The API key's user doesn't have read access to Users/Teams/Roles at the system level — use a System Manager-level key, or narrow with `--spaces` if you only need specific spaces you do have access to |
| Report shows very few teams/roles | The key's user may only see teams they're a member of on some server configurations — try a higher-privileged key |
| Slow run on a large instance | Reduce with `--spaces`, raise `--max-workers`, or pass `--no-resolve-scope-names` |
| Scope shows raw GUIDs instead of names | `--no-resolve-scope-names` was passed, or the API key can't read into that space |

## Extending

The script is one file (`octopus_rbac_report.py`), organized top to bottom as:
permission descriptions → HTTP client → data collection → model building →
demo data → JSON writer → HTML writer → CLI. The `build_model()` function is
the single place that turns raw API responses into the report's data
structure — that's the function to touch if you want to add new fields (e.g.
last-login timestamps, or breaking permissions out by category).
