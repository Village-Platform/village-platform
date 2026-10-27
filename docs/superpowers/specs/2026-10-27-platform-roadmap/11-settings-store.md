# 11 — Settings store

Status: draft
Part of: super-admin "control everything"
Depends on: 06

## Goal

Let a super admin change operational values without a deploy: support phone, minimum supported
Android version (force-update), maintenance banner text, feature toggles.

## What stays in ENV

Secrets and payment destinations (`INSTAPAY_ADDRESS`, `VODAFONE_CASH_NUMBER`). Moving a payment
account into an editable table means a compromised admin session can redirect money. **Keep them
in ENV.**

## Data

```
settings
  key (string, primary key), value (jsonb), updated_by_id, updated_at
```

Keys are declared in code (`Setting::SCHEMA = { "support_phone" => :string, "min_android_version" =>
:integer, ... }`) with types and defaults; unknown keys are rejected. Reads are cached in-process
for 60 seconds (one pod today; at several pods the 60s window is the consistency cost).

## API

`GET /api/v1/app_config` — public, returns client-facing keys only (`min_android_version`,
`latest_android_version`, `support_phone`, `banner`). This is the **force-update** mechanism the
Android app needs anyway: an app below `min_android_version` blocks with an update screen.
