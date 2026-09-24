#!/usr/bin/env python3
"""
Octopus Deploy RBAC Usage Report
=================================

Generates a JSON and/or HTML report describing an Octopus Deploy account's
access-control configuration:

  * Users and the teams they belong to (and HOW that membership happened --
    direct assignment vs. an external identity-provider group)
  * Roles (User Roles) granted to each team, and the scope of that grant
    (which spaces / projects / project groups / environments / tenants
    it applies to, or "unrestricted")
  * The full permission set each role grants, with a plain-English
    description of each permission code

The script uses only the Python standard library -- no pip installs
required. See README.md for setup and usage.

Author: generated for Dustin (Octopus Deploy Principal SE)
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Set, Tuple

SCRIPT_VERSION = "1.0.0"
DEFAULT_TIMEOUT = 30
DEFAULT_MAX_RETRIES = 3
RETRY_BACKOFF_SECONDS = 2
PAGE_SIZE = 1000


# ---------------------------------------------------------------------------
# Permission descriptions
# ---------------------------------------------------------------------------
# Octopus's REST API returns permission *codes* (e.g. "ProjectView") on each
# UserRole, not human-friendly descriptions. This is a best-effort curated
# lookup for the well-known, stable permission codes. Anything not in this
# dictionary is NOT guessed at length -- it's auto-humanized from the code
# itself (see humanize_permission_code) and flagged as such in the report so
# nobody mistakes an auto-generated label for authoritative Octopus text.
PERMISSION_DESCRIPTIONS: Dict[str, str] = {
    "AccountCreate": "Create infrastructure accounts (cloud/credential accounts)",
    "AccountDelete": "Delete infrastructure accounts",
    "AccountEdit": "Edit infrastructure accounts",
    "AccountView": "View infrastructure accounts",
    "AdministerSystem": "Full system administration (superuser)",
    "ArtifactCreate": "Attach artifacts to deployments/runbook runs",
    "ArtifactDelete": "Delete artifacts",
    "ArtifactView": "View/download artifacts",
    "BuiltInFeedAdminister": "Administer the built-in package feed",
    "BuiltInFeedDownload": "Download packages from the built-in feed",
    "BuiltInFeedPush": "Push packages to the built-in feed",
    "CertificateCreate": "Add certificates to the certificate store",
    "CertificateDelete": "Delete certificates",
    "CertificateEdit": "Edit certificate metadata",
    "CertificateExportPrivateKey": "Export a certificate's private key",
    "CertificateView": "View certificates",
    "DefectReport": "Report a release as defective",
    "DefectResolve": "Resolve a reported defect",
    "DeploymentCreate": "Deploy a release (create a deployment)",
    "DeploymentDelete": "Delete deployment history",
    "DeploymentView": "View deployments",
    "EnvironmentCreate": "Create environments",
    "EnvironmentDelete": "Delete environments",
    "EnvironmentEdit": "Edit environments",
    "EnvironmentView": "View environments",
    "EventView": "View the audit/event log",
    "FeedEdit": "Edit external package feeds",
    "FeedView": "View external package feeds",
    "InterruptionSubmit": "Respond to a manual intervention prompt",
    "InterruptionView": "View manual intervention prompts",
    "InterruptionViewSubmitResponsible": "Be assigned as responsible for manual interventions",
    "LibraryVariableSetCreate": "Create library variable sets",
    "LibraryVariableSetDelete": "Delete library variable sets",
    "LibraryVariableSetEdit": "Edit library variable sets",
    "LibraryVariableSetView": "View library variable sets",
    "MachineCreate": "Add deployment targets/workers",
    "MachineDelete": "Delete deployment targets/workers",
    "MachineEdit": "Edit deployment targets/workers",
    "MachinePolicyCreate": "Create machine policies",
    "MachinePolicyDelete": "Delete machine policies",
    "MachinePolicyEdit": "Edit machine policies",
    "MachinePolicyView": "View machine policies",
    "MachineView": "View deployment targets/workers",
    "ProcessEdit": "Edit a deployment/runbook process",
    "ProcessView": "View a deployment/runbook process",
    "ProjectCreate": "Create projects",
    "ProjectDelete": "Delete projects",
    "ProjectEdit": "Edit project settings",
    "ProjectGroupCreate": "Create project groups",
    "ProjectGroupDelete": "Delete project groups",
    "ProjectGroupEdit": "Edit project groups",
    "ProjectGroupView": "View project groups",
    "ProjectView": "View project settings",
    "ReleaseCreate": "Create releases",
    "ReleaseDelete": "Delete releases",
    "ReleaseView": "View releases",
    "RunbookEdit": "Edit runbooks",
    "RunbookRunCreate": "Run a runbook",
    "RunbookRunView": "View runbook runs",
    "RunbookSnapshotCreate": "Publish a runbook snapshot",
    "RunbookSnapshotDelete": "Delete a runbook snapshot",
    "RunbookSnapshotView": "View runbook snapshots",
    "RunbookView": "View runbooks",
    "SpaceCreate": "Create spaces",
    "SpaceDelete": "Delete spaces",
    "SpaceEdit": "Edit space settings (incl. space-level user/team management)",
    "SpaceView": "View space settings",
    "SubscriptionCreate": "Create event subscriptions",
    "SubscriptionDelete": "Delete event subscriptions",
    "SubscriptionEdit": "Edit event subscriptions",
    "SubscriptionView": "View event subscriptions",
    "TagSetCreate": "Create tag sets (environment/tenant tags)",
    "TagSetDelete": "Delete tag sets",
    "TagSetEdit": "Edit tag sets",
    "TagSetView": "View tag sets",
    "TaskCancel": "Cancel a running server task",
    "TaskCreate": "Create/queue a server task",
    "TaskView": "View server tasks",
    "TeamEdit": "Edit teams (membership and role grants)",
    "TeamView": "View teams",
    "TenantCreate": "Create tenants",
    "TenantDelete": "Delete tenants",
    "TenantEdit": "Edit tenants",
    "TenantView": "View tenants",
    "TriggerEdit": "Edit project/deployment triggers",
    "TriggerView": "View project/deployment triggers",
    "UserEdit": "Edit user accounts",
    "UserInvite": "Invite/create new users",
    "UserRoleEdit": "Edit user roles (permission sets)",
    "UserRoleView": "View user roles",
    "UserView": "View user accounts",
    "VariableEdit": "Edit scoped variables",
    "VariableEditUnscoped": "Edit variables regardless of scope (incl. sensitive)",
    "VariableView": "View scoped variables",
    "VariableViewUnscoped": "View variables regardless of scope (incl. sensitive)",
    "WorkerCreate": "Add workers",
    "WorkerDelete": "Delete workers",
    "WorkerEdit": "Edit workers",
    "WorkerView": "View workers",
}

_CAMEL_SPLIT_RE = re.compile(r"(?<!^)(?=[A-Z])")


def humanize_permission_code(code: str) -> str:
    """Best-effort fallback label for a permission code not in our curated
    dictionary. This is DERIVED, not authoritative Octopus documentation --
    callers should treat it as a readability aid only."""
    spaced = _CAMEL_SPLIT_RE.sub(" ", code)
    return spaced


def describe_permission(code: str) -> Tuple[str, bool]:
    """Returns (description, is_curated)."""
    if code in PERMISSION_DESCRIPTIONS:
        return PERMISSION_DESCRIPTIONS[code], True
    return humanize_permission_code(code), False


# ---------------------------------------------------------------------------
# HTTP client
# ---------------------------------------------------------------------------

class OctopusApiError(RuntimeError):
    def __init__(self, message: str, status: Optional[int] = None, url: str = ""):
        super().__init__(message)
        self.status = status
        self.url = url


class OctopusClient:
    """Minimal REST client for the Octopus Deploy API using only urllib."""

    def __init__(
        self,
        base_url: str,
        api_key: str,
        timeout: int = DEFAULT_TIMEOUT,
        max_retries: int = DEFAULT_MAX_RETRIES,
        verbose: bool = False,
    ):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.timeout = timeout
        self.max_retries = max_retries
        self.verbose = verbose
        self._get_count = 0

    def _log(self, msg: str) -> None:
        if self.verbose:
            print(f"[octopus-rbac-report] {msg}", file=sys.stderr)

    def _request(self, path: str) -> Any:
        url = path if path.startswith("http") else f"{self.base_url}{path}"
        req = urllib.request.Request(
            url,
            headers={
                "X-Octopus-ApiKey": self.api_key,
                "Accept": "application/json",
                "User-Agent": f"octopus-rbac-report/{SCRIPT_VERSION}",
            },
            method="GET",
        )

        last_error: Optional[Exception] = None
        for attempt in range(1, self.max_retries + 1):
            try:
                self._get_count += 1
                self._log(f"GET {url} (attempt {attempt})")
                with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                    body = resp.read()
                    if not body:
                        return None
                    return json.loads(body.decode("utf-8"))
            except urllib.error.HTTPError as exc:
                if exc.code == 401:
                    raise OctopusApiError(
                        "Authentication failed (401). Check the API key.",
                        status=401,
                        url=url,
                    ) from exc
                if exc.code == 403:
                    raise OctopusApiError(
                        "Forbidden (403). The API key's user needs read access "
                        "(Space Manager / System Manager or equivalent) to enumerate "
                        "users, teams, and roles across the account.",
                        status=403,
                        url=url,
                    ) from exc
                if exc.code == 404:
                    # Some endpoints (e.g. scoped user roles on an empty team)
                    # can 404 rather than return an empty list on older versions.
                    return None
                if exc.code == 429 or exc.code >= 500:
                    last_error = exc
                    sleep_for = RETRY_BACKOFF_SECONDS * attempt
                    self._log(f"HTTP {exc.code} from {url}, retrying in {sleep_for}s")
                    time.sleep(sleep_for)
                    continue
                raise OctopusApiError(f"HTTP {exc.code} from {url}", status=exc.code, url=url) from exc
            except urllib.error.URLError as exc:
                last_error = exc
                sleep_for = RETRY_BACKOFF_SECONDS * attempt
                self._log(f"Connection error to {url} ({exc}), retrying in {sleep_for}s")
                time.sleep(sleep_for)
                continue

        raise OctopusApiError(f"Failed to reach {url} after {self.max_retries} attempts: {last_error}", url=url)

    def get(self, path: str) -> Any:
        return self._request(path)

    def get_all(self, path: str) -> List[dict]:
        """Fetches every page of a collection endpoint. Handles both the
        {"Items": [...], "TotalResults": N} envelope and bare-array
        responses (some endpoints, e.g. scoped user roles, return a plain
        array with no paging envelope)."""
        items: List[dict] = []
        skip = 0
        sep = "&" if "?" in path else "?"
        while True:
            page_path = f"{path}{sep}skip={skip}&take={PAGE_SIZE}"
            result = self.get(page_path)
            if result is None:
                break
            if isinstance(result, list):
                items.extend(result)
                # Bare-array endpoints aren't paginated; one call is everything.
                break
            page_items = result.get("Items", [])
            items.extend(page_items)
            total = result.get("TotalResults")
            if total is None or len(page_items) < PAGE_SIZE or len(items) >= total:
                break
            skip += PAGE_SIZE
        return items

    @property
    def request_count(self) -> int:
        return self._get_count


# ---------------------------------------------------------------------------
# Data collection
# ---------------------------------------------------------------------------
# Reference: Octopus REST API resources used here --
#   /api/users                              (system-wide, all users)
#   /api/userroles                          (system-wide, role definitions + permissions)
#   /api/spaces                             (system-wide, all spaces)
#   /api/teams                              (system-wide; each Team has an optional
#                                             SpaceId -- null means "system team",
#                                             usable across every space)
#   /api/teams/{id}/scopeduserroles         (the actual grant: Team -> UserRole,
#                                             restricted to a SpaceId and optionally
#                                             specific ProjectIds/ProjectGroupIds/
#                                             EnvironmentIds/TenantIds)
#   /api/users/{id}/teams?spaces={id}&includeSystem=True
#                                            (Octopus-resolved list of teams a user
#                                             is effectively a member of for a given
#                                             space, including externally-mapped
#                                             group membership)
#   /api/{spaceId}/projects, /environments, /tenants, /projectgroups
#                                            (used only to resolve scope IDs to
#                                             human-readable names)


def fetch_reference_data(client: OctopusClient) -> Dict[str, Any]:
    """Pulls the account-wide, space-independent collections once."""
    return {
        "users": client.get_all("/api/users"),
        "user_roles": client.get_all("/api/userroles"),
        "spaces": client.get_all("/api/spaces"),
        "teams": client.get_all("/api/teams"),
    }


def fetch_scoped_user_roles_for_teams(client: OctopusClient, teams: List[dict]) -> Dict[str, List[dict]]:
    """Returns {team_id: [scoped_user_role, ...]}."""
    result: Dict[str, List[dict]] = {}
    for team in teams:
        team_id = team["Id"]
        result[team_id] = client.get_all(f"/api/teams/{team_id}/scopeduserroles")
    return result


def fetch_scope_name_lookups(client: OctopusClient, spaces: List[dict]) -> Dict[str, Dict[str, Dict[str, str]]]:
    """For each space, builds id->name maps for projects, project groups,
    environments, and tenants so scope restrictions can be printed as names
    instead of opaque ids. Returns:
        {space_id: {"projects": {id: name}, "project_groups": {...},
                    "environments": {...}, "tenants": {...}}}
    """
    lookups: Dict[str, Dict[str, Dict[str, str]]] = {}
    for space in spaces:
        space_id = space["Id"]
        try:
            projects = client.get_all(f"/api/{space_id}/projects")
            project_groups = client.get_all(f"/api/{space_id}/projectgroups")
            environments = client.get_all(f"/api/{space_id}/environments")
            tenants = client.get_all(f"/api/{space_id}/tenants")
        except OctopusApiError:
            # A space the API key can't see into -- skip name resolution for it.
            projects, project_groups, environments, tenants = [], [], [], []
        lookups[space_id] = {
            "projects": {p["Id"]: p["Name"] for p in projects},
            "project_groups": {g["Id"]: g["Name"] for g in project_groups},
            "environments": {e["Id"]: e["Name"] for e in environments},
            "tenants": {t["Id"]: t["Name"] for t in tenants},
        }
    return lookups


def fetch_user_team_memberships(
    client: OctopusClient,
    users: List[dict],
    spaces: List[dict],
    max_workers: int = 8,
) -> Dict[Tuple[str, str], List[dict]]:
    """For every (user, space) pair, asks Octopus which teams the user
    effectively belongs to in that space (includeSystem=True also folds in
    system-team membership). Returns {(user_id, space_id): [team, ...]}.

    This is the one call that lets external-identity-provider group
    membership be reflected accurately, since Octopus itself resolves
    group -> team mapping server-side; we don't have to reimplement it.
    """
    memberships: Dict[Tuple[str, str], List[dict]] = {}

    def _fetch(user_id: str, space_id: str) -> Tuple[Tuple[str, str], List[dict]]:
        path = f"/api/users/{user_id}/teams?spaces={space_id}&includeSystem=True"
        try:
            result = client.get(path)
        except OctopusApiError:
            result = None
        teams = result if isinstance(result, list) else (result or {}).get("Items", []) if result else []
        return (user_id, space_id), teams

    jobs = [(u["Id"], s["Id"]) for u in users for s in spaces]
    if not jobs:
        return memberships

    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [pool.submit(_fetch, uid, sid) for uid, sid in jobs]
        for fut in concurrent.futures.as_completed(futures):
            key, teams = fut.result()
            memberships[key] = teams

    return memberships


# ---------------------------------------------------------------------------
# Model building
# ---------------------------------------------------------------------------
# Everything below turns the raw API responses into the three top-level
# collections the report is built from: users, teams, roles. Users reference
# teams/roles by id+name only -- the full team/role definitions live once,
# at the top level, so nothing is duplicated per-user.

SYSTEM_SCOPE_LABEL = "System-wide"


def _scope_ids(scoped_role: dict, key: str) -> List[str]:
    return scoped_role.get(key) or []


def summarize_scope(scoped_role: dict, scope_lookup: Dict[str, Dict[str, str]]) -> Dict[str, Any]:
    """Turns a ScopedUserRole's restriction lists into a human-readable
    summary using the id->name lookups for that space (if available)."""
    project_ids = _scope_ids(scoped_role, "ProjectIds")
    project_group_ids = _scope_ids(scoped_role, "ProjectGroupIds")
    environment_ids = _scope_ids(scoped_role, "EnvironmentIds")
    tenant_ids = _scope_ids(scoped_role, "TenantIds")

    def _names(ids: List[str], table: str) -> List[str]:
        table_map = scope_lookup.get(table, {}) if scope_lookup else {}
        return [table_map.get(i, i) for i in ids]

    restrictions = {
        "projects": _names(project_ids, "projects"),
        "project_groups": _names(project_group_ids, "project_groups"),
        "environments": _names(environment_ids, "environments"),
        "tenants": _names(tenant_ids, "tenants"),
    }
    is_unrestricted = not any(restrictions.values())
    return {
        "unrestricted": is_unrestricted,
        "restrictions": restrictions if not is_unrestricted else {},
    }


def scope_display_string(scope_summary: Dict[str, Any], space_name: str) -> str:
    if scope_summary.get("is_system"):
        return SYSTEM_SCOPE_LABEL
    if scope_summary["unrestricted"]:
        return f"Unrestricted within space: {space_name}"
    parts = []
    for label, values in scope_summary["restrictions"].items():
        if values:
            parts.append(f"{label.replace('_', ' ').title()}: {', '.join(values)}")
    return f"{space_name} ({'; '.join(parts)})" if parts else space_name


def classify_membership(user_id: str, team: dict) -> Tuple[str, List[str]]:
    """Returns (membership_type, external_group_names).
    membership_type is one of: 'direct', 'external_group', 'implicit'."""
    member_ids = team.get("MemberUserIds") or []
    external_groups = team.get("ExternalSecurityGroups") or []
    if user_id in member_ids:
        return "direct", []
    if external_groups:
        names = [g.get("DisplayName") or g.get("Id", "unknown group") for g in external_groups]
        return "external_group", names
    # No explicit member record and no external groups configured -- this is
    # the built-in "Everyone" style team (implicit membership for all users).
    return "implicit", []


def build_roles_index(user_roles_raw: List[dict]) -> Dict[str, dict]:
    roles: Dict[str, dict] = {}
    for role in user_roles_raw:
        space_perms = role.get("GrantedSpacePermissions") or []
        system_perms = role.get("GrantedSystemPermissions") or []
        roles[role["Id"]] = {
            "id": role["Id"],
            "name": role["Name"],
            "description": role.get("Description") or "",
            "granted_space_permissions": [
                {"code": code, "description": describe_permission(code)[0], "curated": describe_permission(code)[1]}
                for code in sorted(space_perms)
            ],
            "granted_system_permissions": [
                {"code": code, "description": describe_permission(code)[0], "curated": describe_permission(code)[1]}
                for code in sorted(system_perms)
            ],
        }
    return roles


def build_model(
    reference: Dict[str, Any],
    scoped_roles_by_team: Dict[str, List[dict]],
    scope_lookups: Dict[str, Dict[str, Dict[str, str]]],
    user_team_memberships: Dict[Tuple[str, str], List[dict]],
    include_service_accounts: bool,
) -> Dict[str, Any]:
    users_raw = reference["users"]
    teams_raw = reference["teams"]
    spaces_raw = reference["spaces"]
    space_name_by_id = {s["Id"]: s["Name"] for s in spaces_raw}
    roles_index = build_roles_index(reference["user_roles"])
    teams_by_id = {t["Id"]: t for t in teams_raw}

    if not include_service_accounts:
        users_raw = [u for u in users_raw if not u.get("IsService")]

    # ---- Teams (top level) -------------------------------------------------
    teams_out: List[dict] = []
    for team in teams_raw:
        team_id = team["Id"]
        team_space_id = team.get("SpaceId")
        scoped_roles = scoped_roles_by_team.get(team_id, [])
        granted_roles = []
        for sr in scoped_roles:
            role = roles_index.get(sr.get("UserRoleId"))
            if role is None:
                continue
            sr_space_id = sr.get("SpaceId")
            is_system_grant = sr_space_id is None
            lookup = scope_lookups.get(sr_space_id, {}) if sr_space_id else {}
            scope_summary = {"is_system": True} if is_system_grant else summarize_scope(sr, lookup)
            space_name = SYSTEM_SCOPE_LABEL if is_system_grant else space_name_by_id.get(sr_space_id, sr_space_id)
            granted_roles.append({
                "role_id": role["id"],
                "role_name": role["name"],
                "space_id": sr_space_id,
                "space_name": space_name,
                "scope": scope_summary,
                "scope_display": scope_display_string(scope_summary, space_name),
            })

        external_groups = team.get("ExternalSecurityGroups") or []
        teams_out.append({
            "id": team_id,
            "name": team["Name"],
            "description": team.get("Description") or "",
            "type": "system" if team_space_id is None else "space",
            "space_id": team_space_id,
            "space_name": space_name_by_id.get(team_space_id) if team_space_id else SYSTEM_SCOPE_LABEL,
            "member_user_ids": team.get("MemberUserIds") or [],
            "external_security_groups": [g.get("DisplayName") or g.get("Id") for g in external_groups],
            "granted_roles": granted_roles,
        })

    # ---- Users (top level) --------------------------------------------------
    users_out: List[dict] = []
    for user in users_raw:
        user_id = user["Id"]

        # Collect the set of teams Octopus resolves this user into, across
        # every space (de-duplicated -- system teams show up once per space
        # call but represent a single membership).
        seen_team_ids: Set[str] = set()
        team_memberships: List[dict] = []
        for space in spaces_raw:
            resolved_teams = user_team_memberships.get((user_id, space["Id"]), [])
            for team in resolved_teams:
                team_id = team["Id"]
                if team_id in seen_team_ids:
                    continue
                seen_team_ids.add(team_id)
                full_team = teams_by_id.get(team_id, team)
                membership_type, external_group_names = classify_membership(user_id, full_team)
                team_space_id = full_team.get("SpaceId")
                team_memberships.append({
                    "team_id": team_id,
                    "team_name": full_team.get("Name", team.get("Name")),
                    "team_type": "system" if team_space_id is None else "space",
                    "space_name": space_name_by_id.get(team_space_id) if team_space_id else SYSTEM_SCOPE_LABEL,
                    "via": membership_type,
                    "external_groups": external_group_names,
                })

        # Role grants: every granted_role on every team this user belongs to.
        role_grants: List[dict] = []
        effective_space_permissions: Set[str] = set()
        effective_system_permissions: Set[str] = set()
        for membership in team_memberships:
            team_out = next((t for t in teams_out if t["id"] == membership["team_id"]), None)
            if not team_out:
                continue
            for granted in team_out["granted_roles"]:
                role_grants.append({
                    "role_id": granted["role_id"],
                    "role_name": granted["role_name"],
                    "via_team_id": membership["team_id"],
                    "via_team_name": membership["team_name"],
                    "space_name": granted["space_name"],
                    "scope_display": granted["scope_display"],
                })
                role = roles_index.get(granted["role_id"])
                if role:
                    codes = [p["code"] for p in role["granted_space_permissions"]]
                    if granted["scope"].get("is_system"):
                        effective_system_permissions.update(p["code"] for p in role["granted_system_permissions"])
                    else:
                        effective_space_permissions.update(codes)

        associated_spaces = sorted({m["space_name"] for m in team_memberships} | {g["space_name"] for g in role_grants})

        users_out.append({
            "id": user_id,
            "username": user.get("Username"),
            "display_name": user.get("DisplayName"),
            "email": user.get("EmailAddress"),
            "is_active": user.get("IsActive", True),
            "is_service_account": user.get("IsService", False),
            "team_memberships": team_memberships,
            "role_grants": role_grants,
            "effective_space_permissions": sorted(effective_space_permissions),
            "effective_system_permissions": sorted(effective_system_permissions),
            "associated_spaces": associated_spaces,
        })

    roles_out = list(roles_index.values())
    roles_out.sort(key=lambda r: r["name"].lower())
    teams_out.sort(key=lambda t: t["name"].lower())
    users_out.sort(key=lambda u: (u["display_name"] or u["username"] or "").lower())

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "script_version": SCRIPT_VERSION,
        "spaces": [{"id": s["Id"], "name": s["Name"]} for s in spaces_raw],
        "users": users_out,
        "teams": teams_out,
        "roles": roles_out,
        "summary": {
            "user_count": len(users_out),
            "active_user_count": sum(1 for u in users_out if u["is_active"]),
            "team_count": len(teams_out),
            "role_count": len(roles_out),
            "space_count": len(spaces_raw),
        },
    }


# ---------------------------------------------------------------------------
# Demo mode -- synthetic data so the report can be generated/tested without
# a live Octopus server. Useful for previewing report layout or for a
# presales demo where you don't want to hit a customer's instance.
# ---------------------------------------------------------------------------

def _demo_raw_data() -> Dict[str, Any]:
    users = [
        {"Id": "users-1", "Username": "jane.doe", "DisplayName": "Jane Doe",
         "EmailAddress": "jane.doe@example.com", "IsActive": True, "IsService": False},
        {"Id": "users-2", "Username": "bob.smith", "DisplayName": "Bob Smith",
         "EmailAddress": "bob.smith@example.com", "IsActive": True, "IsService": False},
        {"Id": "users-3", "Username": "svc-github-actions", "DisplayName": "GitHub Actions (service)",
         "EmailAddress": None, "IsActive": True, "IsService": True},
        {"Id": "users-4", "Username": "amir.khan", "DisplayName": "Amir Khan",
         "EmailAddress": "amir.khan@example.com", "IsActive": False, "IsService": False},
    ]

    spaces = [
        {"Id": "Spaces-1", "Name": "Default"},
        {"Id": "Spaces-2", "Name": "Retail"},
    ]

    user_roles = [
        {"Id": "userroles-1", "Name": "Project Deployer", "Description": "Can deploy releases",
         "GrantedSpacePermissions": ["ProjectView", "ReleaseView", "ReleaseCreate", "DeploymentCreate", "DeploymentView"],
         "GrantedSystemPermissions": []},
        {"Id": "userroles-2", "Name": "Environment Manager", "Description": "Manage environments and targets",
         "GrantedSpacePermissions": ["EnvironmentView", "EnvironmentCreate", "EnvironmentEdit", "MachineView", "MachineCreate", "MachineEdit"],
         "GrantedSystemPermissions": []},
        {"Id": "userroles-3", "Name": "Space Manager", "Description": "Full control within a space",
         "GrantedSpacePermissions": ["ProjectView", "ProjectCreate", "ProjectEdit", "ProjectDelete", "TeamView", "TeamEdit",
                                      "VariableView", "VariableEdit", "UserRoleView"],
         "GrantedSystemPermissions": []},
        {"Id": "userroles-4", "Name": "System Administrator", "Description": "Full system-wide control",
         "GrantedSpacePermissions": [],
         "GrantedSystemPermissions": ["AdministerSystem", "UserEdit", "UserInvite", "SpaceCreate", "SpaceDelete"]},
    ]

    teams = [
        {"Id": "teams-1", "Name": "Everyone", "Description": "Built-in: all users", "SpaceId": None,
         "MemberUserIds": [], "ExternalSecurityGroups": []},
        {"Id": "teams-2", "Name": "Octopus Administrators", "Description": "Built-in system administrators",
         "SpaceId": None, "MemberUserIds": ["users-3"], "ExternalSecurityGroups": []},
        {"Id": "teams-3", "Name": "DevOps", "Description": "Retail space deployment team", "SpaceId": "Spaces-2",
         "MemberUserIds": ["users-2"], "ExternalSecurityGroups": [{"DisplayName": "AAD-DevOps-Team"}]},
        {"Id": "teams-4", "Name": "Release Managers", "Description": "Approve and manage releases", "SpaceId": "Spaces-1",
         "MemberUserIds": ["users-1", "users-2"], "ExternalSecurityGroups": []},
    ]

    scoped_roles_by_team = {
        "teams-1": [],
        "teams-2": [
            {"Id": "sur-1", "TeamId": "teams-2", "UserRoleId": "userroles-4", "SpaceId": None,
             "ProjectIds": [], "ProjectGroupIds": [], "EnvironmentIds": [], "TenantIds": []},
        ],
        "teams-3": [
            {"Id": "sur-2", "TeamId": "teams-3", "UserRoleId": "userroles-1", "SpaceId": "Spaces-2",
             "ProjectIds": [], "ProjectGroupIds": [], "EnvironmentIds": ["Environments-1"], "TenantIds": []},
            {"Id": "sur-3", "TeamId": "teams-3", "UserRoleId": "userroles-2", "SpaceId": "Spaces-2",
             "ProjectIds": [], "ProjectGroupIds": [], "EnvironmentIds": [], "TenantIds": []},
        ],
        "teams-4": [
            {"Id": "sur-4", "TeamId": "teams-4", "UserRoleId": "userroles-3", "SpaceId": "Spaces-1",
             "ProjectIds": [], "ProjectGroupIds": [], "EnvironmentIds": [], "TenantIds": []},
        ],
    }

    scope_lookups = {
        "Spaces-1": {"projects": {}, "project_groups": {}, "environments": {}, "tenants": {}},
        "Spaces-2": {"projects": {"Projects-1": "POS Web"}, "project_groups": {},
                     "environments": {"Environments-1": "Production"}, "tenants": {}},
    }

    # Simulate what /api/users/{id}/teams?spaces=X&includeSystem=True would resolve.
    user_team_memberships = {
        ("users-1", "Spaces-1"): [teams[0], teams[3]],
        ("users-1", "Spaces-2"): [teams[0]],
        ("users-2", "Spaces-1"): [teams[0], teams[3]],
        ("users-2", "Spaces-2"): [teams[0], teams[2]],
        ("users-3", "Spaces-1"): [teams[0], teams[1]],
        ("users-3", "Spaces-2"): [teams[0], teams[1]],
        ("users-4", "Spaces-1"): [teams[0]],
        ("users-4", "Spaces-2"): [teams[0]],
    }

    reference = {"users": users, "user_roles": user_roles, "spaces": spaces, "teams": teams}
    return {
        "reference": reference,
        "scoped_roles_by_team": scoped_roles_by_team,
        "scope_lookups": scope_lookups,
        "user_team_memberships": user_team_memberships,
    }


def build_demo_model(include_service_accounts: bool) -> Dict[str, Any]:
    demo = _demo_raw_data()
    return build_model(
        demo["reference"],
        demo["scoped_roles_by_team"],
        demo["scope_lookups"],
        demo["user_team_memberships"],
        include_service_accounts,
    )


# ---------------------------------------------------------------------------
# JSON report
# ---------------------------------------------------------------------------

def write_json_report(model: Dict[str, Any], output_path: str) -> None:
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(model, f, indent=2, sort_keys=False)


# ---------------------------------------------------------------------------
# HTML report
# ---------------------------------------------------------------------------

import html as _html


def _esc(value: Any) -> str:
    if value is None:
        return ""
    return _html.escape(str(value))


HTML_STYLE = """
:root {
  --bg: #0f1216; --panel: #171b21; --panel-2: #1d222a; --border: #2a3038;
  --text: #e7ebf0; --muted: #9aa4b2; --accent: #5db3ff; --accent-2: #7ee0b8;
  --warn: #f2b84b; --danger: #f2686b; --radius: 10px;
}
* { box-sizing: border-box; }
body {
  margin: 0; padding: 0 0 4rem 0; background: var(--bg); color: var(--text);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  font-size: 15px; line-height: 1.5;
}
header.report-header {
  padding: 2rem 2rem 1.25rem 2rem; border-bottom: 1px solid var(--border);
  position: sticky; top: 0; background: var(--bg); z-index: 5;
}
header.report-header h1 { margin: 0 0 0.25rem 0; font-size: 1.5rem; }
header.report-header .meta { color: var(--muted); font-size: 0.85rem; }
.container { max-width: 1100px; margin: 0 auto; padding: 0 2rem; }
.summary-cards { display: flex; gap: 0.75rem; flex-wrap: wrap; margin: 1.25rem 0; }
.summary-card {
  background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius);
  padding: 0.75rem 1.1rem; min-width: 110px;
}
.summary-card .num { font-size: 1.6rem; font-weight: 600; }
.summary-card .label { color: var(--muted); font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.04em; }
.search-box {
  width: 100%; padding: 0.6rem 0.9rem; border-radius: var(--radius); border: 1px solid var(--border);
  background: var(--panel); color: var(--text); font-size: 0.95rem; margin: 0.5rem 0 1.5rem 0;
}
nav.section-tabs { display: flex; gap: 0.5rem; margin: 1rem 0 1.5rem 0; border-bottom: 1px solid var(--border); }
nav.section-tabs button {
  background: none; border: none; color: var(--muted); padding: 0.6rem 1rem; cursor: pointer;
  font-size: 0.95rem; border-bottom: 2px solid transparent;
}
nav.section-tabs button.active { color: var(--text); border-bottom-color: var(--accent); }
section.tab-panel { display: none; }
section.tab-panel.active { display: block; }
details.card {
  background: var(--panel); border: 1px solid var(--border); border-radius: var(--radius);
  margin-bottom: 0.6rem; padding: 0;
}
details.card > summary {
  list-style: none; cursor: pointer; padding: 0.85rem 1.1rem; display: flex;
  align-items: center; gap: 0.6rem; flex-wrap: wrap;
}
details.card > summary::-webkit-details-marker { display: none; }
details.card > summary .name { font-weight: 600; }
details.card > summary .sub { color: var(--muted); font-size: 0.85rem; }
details.card .card-body { padding: 0 1.1rem 1rem 1.1rem; border-top: 1px solid var(--border); }
.badge {
  display: inline-block; font-size: 0.72rem; padding: 0.12rem 0.55rem; border-radius: 999px;
  border: 1px solid var(--border); color: var(--muted); background: var(--panel-2);
}
.badge.direct { color: var(--accent-2); border-color: var(--accent-2); }
.badge.external_group { color: var(--accent); border-color: var(--accent); }
.badge.implicit { color: var(--muted); }
.badge.inactive { color: var(--danger); border-color: var(--danger); }
.badge.service { color: var(--warn); border-color: var(--warn); }
.badge.system { color: var(--warn); border-color: var(--warn); }
.chip-row { display: flex; flex-wrap: wrap; gap: 0.4rem; margin: 0.4rem 0; }
h3.group-title { font-size: 0.8rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--muted); margin: 1rem 0 0.4rem 0; }
table.perm-table { width: 100%; border-collapse: collapse; margin-top: 0.4rem; }
table.perm-table td, table.perm-table th { text-align: left; padding: 0.3rem 0.5rem; border-bottom: 1px solid var(--border); font-size: 0.85rem; }
table.perm-table th { color: var(--muted); font-weight: 500; }
.derived-note { color: var(--muted); font-size: 0.75rem; }
.role-grant { padding: 0.35rem 0; border-bottom: 1px dashed var(--border); font-size: 0.9rem; }
.role-grant:last-child { border-bottom: none; }
details.role-grant-detail {
  padding: 0.4rem 0; border-bottom: 1px dashed var(--border); font-size: 0.9rem;
}
details.role-grant-detail:last-child { border-bottom: none; }
details.role-grant-detail > summary {
  list-style: none; cursor: pointer; display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;
}
details.role-grant-detail > summary::-webkit-details-marker { display: none; }
details.role-grant-detail > summary::before { content: "\\25B8"; color: var(--muted); font-size: 0.75rem; }
details.role-grant-detail[open] > summary::before { content: "\\25BE"; }
details.role-grant-detail table.perm-table { margin-left: 1.1rem; width: calc(100% - 1.1rem); }
.space-filter {
  padding: 0.55rem 0.8rem; border-radius: var(--radius); border: 1px solid var(--border);
  background: var(--panel); color: var(--text); font-size: 0.9rem;
}
.filter-row { display: flex; gap: 0.6rem; margin: 0.5rem 0 1.5rem 0; }
.filter-row .search-box { margin: 0; flex: 1; }
.empty-state { color: var(--muted); padding: 2rem 0; text-align: center; }
footer.report-footer { text-align: center; color: var(--muted); font-size: 0.8rem; margin-top: 2rem; }
"""

HTML_SCRIPT = """
function switchTab(tabId) {
  document.querySelectorAll('section.tab-panel').forEach(function(el) {
    el.classList.toggle('active', el.id === tabId);
  });
  document.querySelectorAll('nav.section-tabs button').forEach(function(btn) {
    btn.classList.toggle('active', btn.getAttribute('data-tab') === tabId);
  });
}

function applyFilter() {
  var q = document.getElementById('globalSearch').value.trim().toLowerCase();
  var spaceFilterEl = document.getElementById('spaceFilter');
  var spaceQ = spaceFilterEl ? spaceFilterEl.value.trim().toLowerCase() : '';

  document.querySelectorAll('[data-search]').forEach(function(el) {
    var haystack = el.getAttribute('data-search');
    var textMatch = (!q || haystack.indexOf(q) !== -1);

    var spacesAttr = el.getAttribute('data-spaces');
    var spaceMatch = true;
    if (spaceQ && spacesAttr !== null) {
      var spaceList = spacesAttr.split('|');
      spaceMatch = spaceList.indexOf(spaceQ) !== -1;
    }

    el.style.display = (textMatch && spaceMatch) ? '' : 'none';
  });
}
"""


def _badge(text: str, cls: str = "") -> str:
    return f'<span class="badge {_esc(cls)}">{_esc(text)}</span>'


def _permission_rows(permissions: List[dict]) -> str:
    if not permissions:
        return '<tr><td colspan="3" class="derived-note">None</td></tr>'
    rows = []
    for p in permissions:
        note = "" if p["curated"] else '<span class="derived-note"> (derived from code)</span>'
        rows.append(
            f'<tr><td><code>{_esc(p["code"])}</code></td>'
            f'<td>{_esc(p["description"])}{note}</td></tr>'
        )
    return "\n".join(rows)


def _render_user_card(user: dict) -> str:
    status_badges = ""
    if not user["is_active"]:
        status_badges += _badge("inactive", "inactive")
    if user["is_service_account"]:
        status_badges += _badge("service account", "service")

    team_chips = "".join(
        _badge(f'{m["team_name"]} ({m["via"].replace("_", " ")})', m["via"])
        for m in user["team_memberships"]
    ) or '<span class="derived-note">No team memberships</span>'

    role_rows = "".join(
        f'<div class="role-grant"><strong>{_esc(g["role_name"])}</strong> '
        f'via team <em>{_esc(g["via_team_name"])}</em> &mdash; {_esc(g["scope_display"])}</div>'
        for g in user["role_grants"]
    ) or '<div class="derived-note">No roles granted</div>'

    perms = sorted(set(user["effective_space_permissions"]) | set(user["effective_system_permissions"]))
    perm_chips = "".join(f'<span class="badge">{_esc(p)}</span>' for p in perms) or \
        '<span class="derived-note">No effective permissions</span>'

    search_blob = " ".join([
        user["display_name"] or "", user["username"] or "", user["email"] or "",
        *[m["team_name"] for m in user["team_memberships"]],
        *[g["role_name"] for g in user["role_grants"]],
    ]).lower()
    spaces_attr = "|".join(s.lower() for s in user.get("associated_spaces", []))

    return f"""
<details class="card" data-search="{_esc(search_blob)}" data-spaces="{_esc(spaces_attr)}">
  <summary>
    <span class="name">{_esc(user["display_name"] or user["username"])}</span>
    <span class="sub">{_esc(user["username"])}</span>
    {status_badges}
  </summary>
  <div class="card-body">
    <h3 class="group-title">Teams</h3>
    <div class="chip-row">{team_chips}</div>
    <h3 class="group-title">Roles granted (and how)</h3>
    {role_rows}
    <h3 class="group-title">Effective permissions ({len(perms)})</h3>
    <div class="chip-row">{perm_chips}</div>
  </div>
</details>"""


def _render_team_role_grant(granted: dict, roles_by_id: Dict[str, dict]) -> str:
    """Renders one role grant on a team card as its own nested, expandable
    <details> so the role's full permission list can be checked inline
    without leaving the Teams tab."""
    role = roles_by_id.get(granted["role_id"])
    is_system = granted.get("scope", {}).get("is_system")
    permissions = []
    if role:
        permissions = role["granted_system_permissions"] if is_system else role["granted_space_permissions"]
    perm_count = len(permissions)
    perm_table = _permission_rows(permissions)

    return f"""
<details class="role-grant-detail">
  <summary>
    <strong>{_esc(granted["role_name"])}</strong> &mdash; {_esc(granted["scope_display"])}
    <span class="badge">{perm_count} permission{'s' if perm_count != 1 else ''}</span>
  </summary>
  <table class="perm-table"><tbody>{perm_table}</tbody></table>
</details>"""


def _render_team_card(team: dict, users_by_id: Dict[str, dict], roles_by_id: Dict[str, dict]) -> str:
    member_names = [
        users_by_id[uid]["display_name"] or users_by_id[uid]["username"]
        for uid in team["member_user_ids"] if uid in users_by_id
    ]
    member_chips = "".join(_badge(n, "direct") for n in member_names) or \
        '<span class="derived-note">No direct members</span>'
    group_chips = "".join(_badge(g, "external_group") for g in team["external_security_groups"]) or \
        '<span class="derived-note">None configured</span>'

    role_rows = "".join(
        _render_team_role_grant(g, roles_by_id) for g in team["granted_roles"]
    ) or '<div class="derived-note">No roles granted to this team</div>'

    type_badge = _badge(team["type"], "system" if team["type"] == "system" else "")
    space_label = team["space_name"]

    search_blob = " ".join([
        team["name"], space_label, *member_names, *team["external_security_groups"],
        *[g["role_name"] for g in team["granted_roles"]],
    ]).lower()
    spaces_attr = space_label.lower()

    return f"""
<details class="card" data-search="{_esc(search_blob)}" data-spaces="{_esc(spaces_attr)}">
  <summary>
    <span class="name">{_esc(team["name"])}</span>
    <span class="sub">{_esc(space_label)}</span>
    {type_badge}
  </summary>
  <div class="card-body">
    <h3 class="group-title">Direct members</h3>
    <div class="chip-row">{member_chips}</div>
    <h3 class="group-title">External identity-provider groups</h3>
    <div class="chip-row">{group_chips}</div>
    <h3 class="group-title">Roles granted (expand for permissions)</h3>
    {role_rows}
  </div>
</details>"""


def _render_role_card(role: dict) -> str:
    search_blob = " ".join([
        role["name"], role["description"],
        *[p["code"] for p in role["granted_space_permissions"]],
        *[p["code"] for p in role["granted_system_permissions"]],
    ]).lower()

    return f"""
<details class="card" data-search="{_esc(search_blob)}">
  <summary>
    <span class="name">{_esc(role["name"])}</span>
    <span class="sub">{_esc(role["description"])}</span>
  </summary>
  <div class="card-body">
    <h3 class="group-title">Space permissions ({len(role["granted_space_permissions"])})</h3>
    <table class="perm-table"><tbody>{_permission_rows(role["granted_space_permissions"])}</tbody></table>
    <h3 class="group-title">System permissions ({len(role["granted_system_permissions"])})</h3>
    <table class="perm-table"><tbody>{_permission_rows(role["granted_system_permissions"])}</tbody></table>
  </div>
</details>"""


def render_html_report(model: Dict[str, Any], source_label: str) -> str:
    users_by_id = {u["id"]: u for u in model["users"]}
    roles_by_id = {r["id"]: r for r in model["roles"]}
    summary = model["summary"]

    user_cards = "\n".join(_render_user_card(u) for u in model["users"]) or \
        '<div class="empty-state">No users found.</div>'
    team_cards = "\n".join(_render_team_card(t, users_by_id, roles_by_id) for t in model["teams"]) or \
        '<div class="empty-state">No teams found.</div>'
    role_cards = "\n".join(_render_role_card(r) for r in model["roles"]) or \
        '<div class="empty-state">No roles found.</div>'

    summary_cards = "".join(
        f'<div class="summary-card"><div class="num">{v}</div><div class="label">{_esc(k.replace("_", " "))}</div></div>'
        for k, v in summary.items()
    )

    space_options = "".join(
        f'<option value="{_esc(s["name"].lower())}">{_esc(s["name"])}</option>' for s in model["spaces"]
    )
    space_options += f'<option value="{_esc(SYSTEM_SCOPE_LABEL.lower())}">{_esc(SYSTEM_SCOPE_LABEL)}</option>'

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Octopus Deploy RBAC Report</title>
<style>{HTML_STYLE}</style>
</head>
<body>
<header class="report-header">
  <div class="container">
    <h1>Octopus Deploy &mdash; RBAC Usage Report</h1>
    <div class="meta">
      Source: {_esc(source_label)} &middot; Generated {_esc(model["generated_at"])} &middot;
      Script v{_esc(model["script_version"])}
    </div>
  </div>
</header>
<div class="container">
  <div class="summary-cards">{summary_cards}</div>
  <div class="filter-row">
    <input id="globalSearch" class="search-box" type="text" placeholder="Filter users, teams, or roles by name..." oninput="applyFilter()">
    <select id="spaceFilter" class="space-filter" onchange="applyFilter()">
      <option value="">All spaces</option>
      {space_options}
    </select>
  </div>
  <nav class="section-tabs">
    <button data-tab="tab-users" class="active" onclick="switchTab('tab-users')">Users</button>
    <button data-tab="tab-teams" onclick="switchTab('tab-teams')">Teams</button>
    <button data-tab="tab-roles" onclick="switchTab('tab-roles')">Roles</button>
  </nav>
  <section id="tab-users" class="tab-panel active">{user_cards}</section>
  <section id="tab-teams" class="tab-panel">{team_cards}</section>
  <section id="tab-roles" class="tab-panel">{role_cards}</section>
  <footer class="report-footer">
    Generated by octopus_rbac_report.py &middot; permission descriptions marked "(derived from code)"
    are auto-humanized from the Octopus permission code, not official Octopus documentation.
  </footer>
</div>
<script>{HTML_SCRIPT}</script>
</body>
</html>"""


def write_html_report(model: Dict[str, Any], output_path: str, source_label: str) -> None:
    html_content = render_html_report(model, source_label)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(html_content)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="octopus_rbac_report.py",
        description="Generate an Octopus Deploy RBAC usage report (users, teams, roles, permissions).",
    )
    parser.add_argument("--url", help="Octopus Server base URL, e.g. https://myinstance.octopus.app")
    parser.add_argument("--api-key", help="Octopus API key. Falls back to OCTOPUS_API_KEY env var.")
    parser.add_argument("--output", choices=["json", "html", "both"], default="json",
                         help="Report format to generate. Default: json")
    parser.add_argument("--output-dir", default="./octopus-rbac-report-output",
                         help="Directory to write report file(s) into.")
    parser.add_argument("--spaces", help="Comma-separated space names or IDs to include. Default: all spaces.")
    parser.add_argument("--include-service-accounts", action="store_true",
                         help="Include service (API-only) accounts in the report. Default: excluded.")
    parser.add_argument("--no-resolve-scope-names", action="store_true",
                         help="Skip resolving project/environment/tenant IDs to names in scope summaries "
                              "(faster on very large instances; scopes will show raw IDs).")
    parser.add_argument("--max-workers", type=int, default=8,
                         help="Thread pool size for per-user/per-space team lookups. Default: 8")
    parser.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT, help="HTTP timeout in seconds.")
    parser.add_argument("--demo", action="store_true",
                         help="Generate the report from built-in synthetic sample data instead of "
                              "calling a live Octopus server. Useful for previewing report layout.")
    parser.add_argument("--verbose", action="store_true", help="Print progress/debug info to stderr.")
    return parser


def _filter_spaces(spaces: List[dict], spaces_filter: Optional[str]) -> List[dict]:
    if not spaces_filter:
        return spaces
    wanted = {s.strip().lower() for s in spaces_filter.split(",") if s.strip()}
    return [s for s in spaces if s["Id"].lower() in wanted or s["Name"].lower() in wanted]


def run(args: argparse.Namespace) -> int:
    os.makedirs(args.output_dir, exist_ok=True)

    if args.demo:
        print("[octopus_rbac_report] Running in --demo mode (no live server contacted).", file=sys.stderr)
        model = build_demo_model(args.include_service_accounts)
        source_label = "Demo / synthetic sample data"
    else:
        if not args.url:
            print("error: --url is required (or use --demo)", file=sys.stderr)
            return 2
        api_key = args.api_key or os.environ.get("OCTOPUS_API_KEY")
        if not api_key:
            print("error: an API key is required via --api-key or the OCTOPUS_API_KEY env var", file=sys.stderr)
            return 2

        client = OctopusClient(args.url, api_key, timeout=args.timeout, verbose=args.verbose)

        try:
            print("Fetching users, roles, spaces, and teams...", file=sys.stderr)
            reference = fetch_reference_data(client)
            reference["spaces"] = _filter_spaces(reference["spaces"], args.spaces)

            print(f"Fetching scoped role grants for {len(reference['teams'])} teams...", file=sys.stderr)
            scoped_roles_by_team = fetch_scoped_user_roles_for_teams(client, reference["teams"])

            scope_lookups: Dict[str, Dict[str, Dict[str, str]]] = {}
            if not args.no_resolve_scope_names:
                print(f"Resolving project/environment/tenant names for {len(reference['spaces'])} spaces...",
                      file=sys.stderr)
                scope_lookups = fetch_scope_name_lookups(client, reference["spaces"])

            users_for_lookup = reference["users"]
            if not args.include_service_accounts:
                users_for_lookup = [u for u in users_for_lookup if not u.get("IsService")]
            print(f"Resolving team membership for {len(users_for_lookup)} users across "
                  f"{len(reference['spaces'])} spaces...", file=sys.stderr)
            user_team_memberships = fetch_user_team_memberships(
                client, users_for_lookup, reference["spaces"], max_workers=args.max_workers
            )
        except OctopusApiError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1

        model = build_model(
            reference, scoped_roles_by_team, scope_lookups, user_team_memberships,
            args.include_service_accounts,
        )
        source_label = args.url
        print(f"Done. {client.request_count} API requests made.", file=sys.stderr)

    if args.output in ("json", "both"):
        json_path = os.path.join(args.output_dir, "octopus-rbac-report.json")
        write_json_report(model, json_path)
        print(f"Wrote {json_path}")

    if args.output in ("html", "both"):
        html_path = os.path.join(args.output_dir, "octopus-rbac-report.html")
        write_html_report(model, html_path, source_label)
        print(f"Wrote {html_path}")

    return 0


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
