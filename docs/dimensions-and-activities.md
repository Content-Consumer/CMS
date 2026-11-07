# Dimensions and Activities

## What are Dimensions?

A **dimension** is a named context that a block can belong to. Think of it as a lens or frame through which content is organised and acted upon. A block about climate policy might belong to a "Policy Research" dimension and also to a "Public Deliberation" dimension simultaneously — the block is the same, but the purpose and activities around it differ per dimension.

Dimensions are created by extensions at install time. They are not ad-hoc user-created containers; they represent structured, purpose-driven spaces defined in code by whoever builds the extension.

A block can belong to many dimensions, and a dimension can contain many blocks. This is a many-to-many relationship tracked through the `block_dimensions` join table.

---

## What are Activities?

An **activity** is something that happens inside a dimension. It represents a mode of engagement — how users interact with the content in that dimension.

There are two kinds of activity:

### User Activity
A single user managing or working with blocks on their own. One user activity record exists per user per dimension — it represents that user's presence and ownership within that dimension. There is a unique constraint on `(dimension_id, user_id)`.

### Group Activity
A collaborative activity involving multiple people. Examples include discussions, forums, votes, and chats. Each group activity has an **activity type**, which categorises what kind of collaboration it is. Activity types are dimension-specific — the valid types for a dimension are declared by the extension that owns it.

---

## Data Model

### Dimensions

```
dimensions
├── id          (UXID, prefix: "dim")
├── title       (string, required)
└── description (string, optional)

block_dimensions           ← join table: block ↔ dimension
├── id           (UXID, prefix: "bdim")
├── block_id     (FK → text_blocks)
└── dimension_id (FK → dimensions)
```

A unique index on `(block_id, dimension_id)` prevents a block from being added to the same dimension twice.

Relevant source:
- Schema: [`apps/wiki/lib/wiki/dimension/dimension.ex`](../apps/wiki/lib/wiki/dimension/dimension.ex)
- Join schema: [`apps/wiki/lib/wiki/dimension/block_dimension.ex`](../apps/wiki/lib/wiki/dimension/block_dimension.ex)
- Context: [`apps/wiki/lib/wiki/dimension.ex`](../apps/wiki/lib/wiki/dimension.ex)

### Activity Types

```
dimension_activity_types
├── id           (UXID, prefix: "dimat")
├── dimension_id (FK → dimensions)
├── name         (string) — human-readable label, e.g. "Open Discussion"
└── type         (string) — extension-scoped identifier, e.g. "deliberation"
```

`name` is what gets displayed. `type` is the machine identifier used by the owning extension to distinguish its activity types. A unique index on `(dimension_id, type, name)` prevents duplicate registrations.

Schema: [`apps/wiki/lib/wiki/activity/dimension_activity_type.ex`](../apps/wiki/lib/wiki/activity/dimension_activity_type.ex)

### Group Activities

```
group_activities
├── id               (UXID, prefix: "gact")
├── dimension_id     (FK → dimensions)
└── activity_type_id (FK → dimension_activity_types)
```

Schema: [`apps/wiki/lib/wiki/activity/group_activity.ex`](../apps/wiki/lib/wiki/activity/group_activity.ex)

### User Activities

```
user_activities
├── id           (UXID, prefix: "uact")
├── dimension_id (FK → dimensions)
└── user_id      (FK → users)
```

A unique index on `(dimension_id, user_id)` enforces one record per user per dimension.

Schema: [`apps/wiki/lib/wiki/activity/user_activity.ex`](../apps/wiki/lib/wiki/activity/user_activity.ex)

### Relationship Overview

```
extensions
    └── creates on install ──→ dimensions
                                    ├── has many → dimension_activity_types
                                    ├── has many → block_dimensions ←── blocks
                                    ├── has many → group_activities
                                    │                   └── belongs to → dimension_activity_types
                                    └── has many → user_activities
                                                        └── belongs to → users
```

---

## Querying Activities

All queries live in [`apps/wiki/lib/wiki/activity.ex`](../apps/wiki/lib/wiki/activity.ex).

| Goal | Function |
|---|---|
| All group activities in a dimension | `Wiki.Activity.list_group_activities_in_dimension/1` |
| All group activities of a specific type in a dimension | `Wiki.Activity.list_group_activities_by_type_in_dimension/2` |
| All user activities in a dimension | `Wiki.Activity.list_user_activities_in_dimension/1` |
| A specific user's activity in a dimension | `Wiki.Activity.get_user_activity_in_dimension/2` |
| All activity types registered to a dimension | `Wiki.Activity.list_activity_types_for_dimension/1` |

`list_group_activities_by_type_in_dimension/2` takes the `type` string (the extension-scoped identifier, not the display name) and joins through `dimension_activity_types` to filter:

```elixir
Wiki.Activity.list_group_activities_by_type_in_dimension("deliberation", dimension_id)
```

---

## How Extensions Declare Dimensions and Activities

Extensions are the only way dimensions and activity types enter the system. They are never created by hand at runtime — they are declared in code and materialised into the database when the extension is first enabled.

### The `Wiki.Extension` Behaviour

Any module that wants to register dimensions and activity types must implement the [`Wiki.Extension`](../apps/wiki/lib/wiki/extension.ex) behaviour:

```elixir
@callback name() :: String.t()
@callback dimensions() :: [dimension_blueprint()]
@callback activity_types() :: [activity_type_blueprint()]
```

Where the blueprint types are:

```elixir
# A dimension to create
%{title: String.t(), description: String.t() | nil}

# An activity type to register, linked to a dimension by its title
%{dimension_title: String.t(), name: String.t(), type: String.t()}
```

`dimension_title` in `activity_type_blueprint` is how activity types are linked to dimensions at declaration time — before any DB IDs exist. During installation, the wiki core matches them up.

### Example: The Deliberation Extension

[`apps/deliberation/lib/deliberation.ex`](../apps/deliberation/lib/deliberation.ex) implements both `Wiki.Extension` and `Wiki.Block.Extension`. A module can implement both; `name/0` satisfies the callback in each.

```elixir
defmodule Deliberation do
  @behaviour Wiki.Block.Extension
  @behaviour Wiki.Extension

  def name, do: "Deliberation"

  def dimensions do
    [%{title: "Deliberation", description: "A space for structured group deliberation"}]
  end

  def activity_types do
    [
      %{dimension_title: "Deliberation", name: "Open Discussion", type: "deliberation"},
      %{dimension_title: "Deliberation", name: "Voting",          type: "deliberation_voting"}
    ]
  end
end
```

### Registration

Extensions are registered in [`config/config.exs`](../config/config.exs):

```elixir
config :wiki, extensions: [Deliberation]
```

### Installation at Boot

[`Wiki.Application.start/2`](../apps/wiki/lib/wiki/application.ex) calls `Wiki.Extensions.enable_all/0` after the supervision tree (and therefore the database) is up. `enable_all/0` reads the `:extensions` config list, filters to modules that implement `Wiki.Extension` (checked via `function_exported?/3`), and calls `enable/1` for each.

`enable/1` in [`apps/wiki/lib/wiki/extensions.ex`](../apps/wiki/lib/wiki/extensions.ex) is idempotent: it checks the `enabled_extensions` table for a record matching the extension's `name/0`. If found, it logs and returns `:ok`. If not, it runs `install/1` inside a database transaction that:

1. Creates each dimension returned by `dimensions/0`
2. Builds a `title → dimension` map to resolve `dimension_title` references
3. Creates each activity type returned by `activity_types/0`, resolving the dimension FK from the map
4. Inserts a row into `enabled_extensions` to mark the extension as installed

The whole operation is wrapped in `Repo.transaction/1`. Any failure rolls back all three steps atomically, so there is no partial installation state.

### Adding a New Extension

1. Create a module implementing `Wiki.Extension` (and optionally `Wiki.Block.Extension`)
2. Implement `name/0`, `dimensions/0`, and `activity_types/0`
3. Add the module to the `extensions` list in `config/config.exs`
4. On next boot, the wiki core will install it automatically

No migrations, no seed scripts. The extension is self-describing.
