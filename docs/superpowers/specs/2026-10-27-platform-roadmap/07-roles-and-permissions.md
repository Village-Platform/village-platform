# 07 — Roles and permissions

Status: draft
Part of: super-admin "control everything"
Depends on: 06

## Goal

Today `super_admin` can do everything. As soon as a second person helps (a reviewer who approves
payments, a moderator who handles reports), the only option is to hand them full control. This
spec splits admin power without rewriting authorization.

## Recommendation: staff permissions, not a generic RBAC engine

Keep the `role` enum (`user / firm_admin / super_admin`) — the Android client reads it. Add a
`staff` role and a fixed list of permissions:

```
staff_permissions
  user_id (fk), permission (string), granted_by_id, created_at
  unique (user_id, permission)

PERMISSIONS = %w[ firms.moderate subscriptions.review articles.moderate reports.handle
                  notifications.send categories.manage users.manage settings.manage export.run ]
```

`super_admin` implicitly holds all. Policies ask `user.can?("subscriptions.review")` instead of
`super_admin?`. `Admin::BaseController` admits `super_admin` or `staff`; each admin controller
authorizes its permission; the sidebar hides what the user cannot do.

Why not a full roles-of-permissions model: with one or two staff, a role table is configuration
nobody maintains. A fixed permission list is greppable and testable. Revisit when there are
several staff with identical sets.

## Rules

- Only `super_admin` grants permissions and changes roles (audited, spec 06).
- A user cannot grant themselves anything.
- `AdminSession` already re-checks the role every request; extend it to reload permissions, so
  revocation is immediate.
- Adding `staff` to the enum is **additive for the API**, but the Android app must treat an unknown
  role as `user`. **Verify the app's role parsing before shipping.**

## Interview question

You chose a fixed permission list over a configurable RBAC system. What signal would make you
switch, and how would you migrate without downtime?
