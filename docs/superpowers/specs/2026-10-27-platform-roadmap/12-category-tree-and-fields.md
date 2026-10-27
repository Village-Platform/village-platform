# 12 — Category tree and custom fields

Status: draft
Part of: super-admin "control everything"

Two independent features; either can ship alone.

## Sub-categories

`categories.parent_id` (nullable, self fk), one level deep only (enforced by validation: a parent
cannot have a parent). Firms keep `category_id`; a firm may belong to a leaf or a top-level
category.

API: `CategorySerializer` gains `parent_id` and `children_count` (additive). `/categories` keeps
returning **top-level categories only by default** so old apps see the same list;
`?parent_id=` returns children. `/categories/:id/firms` includes firms of child categories.

Why one level: a village directory does not need a taxonomy, and a recursive tree costs recursive
queries, recursive UI and recursive admin forms.

## Custom fields

Per-category extra fields (pharmacy: "open 24h"; doctor: "speciality", "clinic days").

```
category_fields
  id, category_id, key, label, kind (text|boolean|number|select), options (jsonb), position, required
firms.custom_fields  jsonb  default {}
```

Validation of `firms.custom_fields` against the category's fields in a model validator. Stored as
jsonb on the firm (not an EAV table) because values are only read with the firm and rarely queried.
At 10x, if filtering by a field is needed, add a GIN index on `custom_fields`.

API: firm serializer gains `custom_fields: [{ key, label, value }]` (labels resolved server-side so
old apps can show them as plain rows if they choose).

## Warning

Changing a category's fields after firms filled them leaves orphan keys. Removing a field hides its
value; it never deletes data.
