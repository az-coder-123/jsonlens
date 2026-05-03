# JSONLens Search Guide

A complete guide to all search and filter capabilities in the JSONLens Tree View.

---

## Table of Contents

1. [Overview](#overview)
2. [Text Search](#text-search)
   - [Opening Search](#opening-search)
   - [Search Scope](#search-scope)
   - [Navigating Results](#navigating-results)
   - [Value Type Filter](#value-type-filter)
   - [Subtree Search](#subtree-search)
   - [Case Sensitivity](#case-sensitivity)
   - [Search History](#search-history)
   - [Copy Results](#copy-results)
   - [Keyboard Shortcuts](#keyboard-shortcuts)
3. [Object Filter](#object-filter)
   - [Opening the Filter](#opening-the-filter)
   - [Adding a Condition](#adding-a-condition)
   - [Value Types](#value-types)
   - [Operators](#operators)
   - [DateTime Filtering](#datetime-filtering)
   - [Dotted Path Keys](#dotted-path-keys)
   - [Filtering Nested Arrays](#filtering-nested-arrays)
     - [The Mental Model](#the-mental-model)
     - [Case 1 — Direct Field on Array Item](#case-1--direct-field-on-array-item)
     - [Case 2 — Through a Nested Array](#case-2--through-a-nested-array)
     - [Case 3 — Primitive Array Values](#case-3--primitive-array-values)
     - [Case 4 — Deep Nesting (3+ Levels)](#case-4--deep-nesting-3-levels)
     - [Cross-Level AND Conditions](#cross-level-and-conditions)
     - [Common Patterns](#common-patterns)
     - [Troubleshooting](#troubleshooting)
   - [AND Chaining](#and-chaining)
   - [Editing a Condition](#editing-a-condition)
   - [Enabling / Disabling Conditions](#enabling--disabling-conditions)
   - [Switching Views](#switching-views)
4. [Quick Reference](#quick-reference)

---

## Overview

JSONLens provides two independent search mechanisms in the Tree View:

| Feature | Best For |
|---------|----------|
| **Text Search** | Quick keyword lookup across keys and values |
| **Object Filter** | Structured queries that find objects matching multiple typed conditions |

Both features are accessible from the Tree View toolbar and can be used on any valid JSON document.

---

## Text Search

### Opening Search

Click the **magnifying glass icon** ( 🔍 ) in the Tree View toolbar, or press **Cmd+F** (macOS) / **Ctrl+F** (Windows / Linux) from anywhere inside the Tree View.

The search bar appears below the toolbar. Start typing to see results immediately — a debounce delay prevents excessive computation on large documents.

To close search, click the icon again or press **Esc**.

---

### Search Scope

Three scope chips control which parts of each JSON node are matched:

| Chip | Matches |
|------|---------|
| **Keys** | Only node key names |
| **Both** *(default)* | Both keys and leaf values |
| **Values** | Only leaf primitive values (strings, numbers, booleans, null) |

Click a chip to switch scope. Results and highlighting update instantly.

---

### Navigating Results

The search bar displays a **"X of Y"** counter showing your current position in the result set.

| Control | Action |
|---------|--------|
| **↑ arrow button** | Jump to previous result |
| **↓ arrow button** | Jump to next result |
| **Enter** (keyboard) | Next result |
| **Shift + Enter** | Previous result |

When a result is selected, the Tree View automatically:
- Expands all ancestor nodes so the target is reachable.
- Scrolls the target node into view.
- Highlights the node row with a subtle tint.

**Path-list mode** — click the list icon ( ☰ ) on the right of the search bar to switch from the filtered tree to a flat list of all matching paths. Each row shows the full JSON path and a value preview. Click any row to jump directly to that node in the tree.

> **Match count badges** — collapsed container nodes display a small yellow number badge indicating how many matches are hidden inside. This lets you decide which branches to expand without opening everything.

---

### Value Type Filter

While a search query is active, a **Type** filter row appears below the scope chips:

```
Type: [Str] [Num] [Bool] [Null] [Obj] [Arr]
```

Select one or more type chips to restrict matches to nodes whose *value* is of that runtime type. Multiple chips can be active simultaneously (OR semantics within the type filter, AND with the text query).

| Chip | Matches |
|------|---------|
| **Str** | String values |
| **Num** | Number values (integer or float) |
| **Bool** | Boolean values (`true` / `false`) |
| **Null** | Null values |
| **Obj** | Object (Map) nodes |
| **Arr** | Array (List) nodes |

Leave all chips inactive to search across all types (default behaviour).

---

### Subtree Search

When a node is selected (shown in the breadcrumb bar), the **Subtree** chip appears in the scope row:

```
[Keys] [Both] [Values]        [Subtree]
```

Enabling **Subtree** restricts path-list results to nodes that are descendants of the currently selected node. Use this to search within a specific branch of a large document without being flooded by results from other sections.

> Subtree filtering only affects path-list mode results. The tree view still shows the full document.

---

### Case Sensitivity

By default text search is **case-insensitive** — `"api"` matches `"API"`, `"Api"`, etc.

Click the **Aa** toggle (visible on the right side of the search bar) to enable case-sensitive matching. The toggle turns blue when active.

---

### Search History

The last **10 queries** are saved automatically. When the search field is focused and empty, a **Recent:** row appears with clickable chips for past queries. Click any chip to re-apply that query instantly.

---

### Copy Results

When there are search results, a **copy icon** ( ⧉ ) appears in the search bar. Clicking it copies all matching paths and their values to the clipboard in the format:

```
$.products[0].name = "Essence Mascara Lash Princess"
$.products[1].name = "Eyeshadow Palette with Mirror"
```

A snackbar confirms how many results were copied.

---

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Cmd/Ctrl + F** | Open search / focus search field |
| **Enter** | Next result |
| **Shift + Enter** | Previous result |
| **Esc** | Close search |

---

## Object Filter

Object Filter lets you build **typed, structured queries** that find JSON objects satisfying multiple key-value conditions simultaneously. Unlike text search (which finds individual nodes), Object Filter finds objects that meet *all* your conditions at once — ideal for filtering arrays of records.

### Opening the Filter

Click the **structured-search icon** ( ⊞ ) in the Tree View toolbar. A badge on the icon shows the **number of matching results** when conditions are active.

> Text Search and Object Filter are mutually exclusive. Activating one automatically closes the other.

---

### Adding a Condition

Click **+ Add condition** to open the condition form:

```
Key      [ products.rating            ]
Type     [ Any ] [ Str ] [ Num ] [ Bool ] [ Null ] [ Date ]
Operator [ contains ] [ = ] [ ≠ ] [ starts ] [ ends ]
Value    [ 4.5                        ]        [Aa]
                                      [ Cancel ] [ Add ]
```

**Step 1 — Key:**  
Type a key name or select from the autocomplete dropdown. The dropdown shows all unique keys found in the document, ranked by frequency, along with their occurrence count:

```
name      ×30
rating    ×30
category  ×30
...
```

You can also enter a **dotted path** to reference nested keys (see [Dotted Path Keys](#dotted-path-keys)).

**Step 2 — Type:**  
Choose the expected data type of the value you want to match. This makes comparison strict — only nodes whose *runtime type* matches will be considered.

**Step 3 — Operator:**  
The available operators adapt automatically based on the selected type.

**Step 4 — Value:**  
Enter the value to compare against. For types that have sample values (strings, numbers), clickable **sample chips** appear below the input — tap any chip to fill the field instantly.

Click **Add** to create the condition chip. Click **Cancel** to discard.

---

### Value Types

| Type | Description | Example values |
|------|-------------|----------------|
| **Any** | Type-agnostic string comparison (default) | Matches any primitive |
| **Str** | String fields only | `"beauty"`, `"In Stock"` |
| **Num** | Numeric fields; supports `>`, `<`, `≥`, `≤` | `9.99`, `4.5` |
| **Bool** | Boolean fields; shows `true`/`false` toggle | `true`, `false` |
| **Null** | Fields whose value is `null` | *(no value needed)* |
| **Date** | Date/time fields; parses by format | `2024-01-15`, `1705276800` |

---

### Operators

Available operators depend on the selected Value Type:

| Operator | Symbol | Applicable Types |
|----------|--------|-----------------|
| contains | `contains` | Any, Str |
| equals | `=` | All types |
| not equals | `≠` | All types |
| starts with | `starts` | Any, Str |
| ends with | `ends` | Any, Str |
| greater than | `>` | Num, Date |
| less than | `<` | Num, Date |
| greater or equal | `≥` | Num, Date |
| less or equal | `≤` | Num, Date |

---

### DateTime Filtering

When **Date** type is selected, a **Format** selector appears:

| Format | Description | Example Input |
|--------|-------------|---------------|
| **ISO 8601** | Standard date/time strings | `2024-01-15` or `2024-01-15T10:30:00Z` |
| **Unix (s)** | Unix timestamp in seconds | `1705276800` |
| **Unix (ms)** | Unix timestamp in milliseconds | `1705276800000` |
| **Custom** | User-defined `intl` DateFormat pattern | `dd/MM/yyyy` |

When **Custom** is selected, a pattern input field appears with a quick-reference guide:

```
Pattern: [ dd/MM/yyyy HH:mm                  ]

yyyy=year  MM=month  dd=day  HH=hour 24h  mm=minute  ss=second  a=AM/PM
```

All comparisons are normalized to **UTC** so timezone differences do not affect results. If a custom pattern is left empty or fails to parse, the filter falls back to ISO 8601 automatically.

**Example — find products with reviews after April 30, 2025:**
```
Key:      products.reviews.date
Type:     Date
Format:   ISO 8601
Operator: >
Value:    2025-04-30
```

---

### Dotted Path Keys

Use **dot-separated notation** to target a key at any depth in the JSON hierarchy:

```
products.price            → price field on each product object
products.reviews.rating   → rating inside each product's reviews array
products.dimensions.width → width inside a nested object
products.tags             → entire tags array on each product
```

The filter engine automatically determines which node level to evaluate the
condition against, then resolves the remaining key(s) from that node — including
traversal through nested arrays.

See [Filtering Nested Arrays](#filtering-nested-arrays) for a full explanation
with worked examples.

---

### Filtering Nested Arrays

This section explains in detail how to write dotted-path conditions that look
inside arrays, and how multiple conditions combine across different depths.

---

#### The Mental Model

Consider this simplified product structure from a typical REST API:

```json
{
  "products": [
    {
      "id": 1,
      "title": "Mascara",
      "price": 9.99,
      "rating": 4.5,
      "category": "beauty",
      "tags": ["beauty", "mascara"],
      "dimensions": { "width": 15.14, "height": 13.08 },
      "reviews": [
        { "rating": 5, "comment": "Great!", "date": "2025-01-10T08:00:00Z" },
        { "rating": 3, "comment": "OK",     "date": "2025-03-22T14:30:00Z" }
      ]
    },
    {
      "id": 2,
      "title": "Foundation",
      "price": 29.99,
      "rating": 3.8,
      "category": "beauty",
      "tags": ["beauty", "foundation", "makeup"],
      "dimensions": { "width": 9.26, "height": 22.47 },
      "reviews": [
        { "rating": 4, "comment": "Nice",  "date": "2025-04-01T10:00:00Z" },
        { "rating": 3, "comment": "Fine",  "date": "2025-05-15T09:00:00Z" }
      ]
    }
  ]
}
```

When you write a filter condition, the engine:

1. **Identifies the context** — which portion of the dotted key is already
   encoded in the node's own JSON path (e.g., `$.products[0]` already
   contains the segment `products`).
2. **Resolves the remainder** — navigates the remaining key segments from the
   node itself, automatically flattening through any arrays it encounters.
3. **Applies the condition** — tests the collected value(s) against your
   operator and value. For arrays, **any matching element** is sufficient.

The node that passes all conditions is the one that appears in the result list.

---

#### Case 1 — Direct Field on Array Item

**Goal:** Find products whose `price` is less than `15`.

**Key:** `products.price`

The engine evaluates each product object at `$.products[N]`. That path already
contains `products`, so the remainder is just `price` — a direct field.

```
Condition:  products.price  <  15  (Num)

$.products[0]  →  price = 9.99   →  9.99 < 15  ✅  returned
$.products[1]  →  price = 29.99  →  29.99 < 15 ✗   skipped
```

**Result:** Only the Mascara product (`$.products[0]`) is returned.

---

#### Case 2 — Through a Nested Array

**Goal:** Find products that have at least one review with a `rating` of 5.

**Key:** `products.reviews.rating`

The path `$.products[N]` consumes `products`. The remaining key is
`reviews.rating`. The engine navigates into the product's `reviews` array and
collects the `rating` value from **every** review. If *any* review's rating
satisfies the condition, the whole product matches.

```
Condition:  products.reviews.rating  =  5  (Num)

$.products[0]  →  reviews[*].rating = [5, 3]  →  any == 5?  ✅ yes
$.products[1]  →  reviews[*].rating = [4, 3]  →  any == 5?  ✗  no
```

**Result:** Only the Mascara product is returned because one of its reviews has
a rating of 5.

> **Key insight:** You do not need to target a specific review index. The engine
> always checks the condition against *all* items in the array and returns the
> parent object if any item matches.

---

#### Case 3 — Primitive Array Values

**Goal:** Find products tagged with `"foundation"`.

**Key:** `products.tags`

`tags` is an array of primitive strings, not objects. The engine resolves the
whole array and checks if *any element* satisfies the condition.

```
Condition:  products.tags  contains  "foundation"  (Any)

$.products[0]  →  tags = ["beauty", "mascara"]             →  any contains "foundation"?  ✗
$.products[1]  →  tags = ["beauty", "foundation", "makeup"] →  any contains "foundation"?  ✅
```

**Result:** The Foundation product is returned.

> **Tip:** Use the `=` operator with type **Any** for exact tag matching, or
> `contains` for partial matching within each tag string.

---

#### Case 4 — Deep Nesting (3+ Levels)

**Goal:** Find products that have a review comment containing `"great"`.

**Key:** `products.reviews.comment`

The path resolves through two levels: `products` (consumed by `$.products[N]`)
then `reviews` (array traversal) then `comment` (leaf on each review).

```
Condition:  products.reviews.comment  contains  "great"  (Str)

$.products[0]  →  reviews[*].comment = ["Great!", "OK"]  →  any contains "great"?  ✅
$.products[1]  →  reviews[*].comment = ["Nice", "Fine"]  →  any contains "great"?  ✗
```

**Example with a deeper structure** — suppose each review had a nested
`reviewer` object:

```json
"reviews": [
  {
    "rating": 5,
    "reviewer": { "name": "Alice", "email": "alice@example.com" }
  }
]
```

**Key:** `products.reviews.reviewer.name`

The engine navigates: `reviews[]` → each `reviewer` object → `name` field.
Use the condition `products.reviews.reviewer.name  contains  "alice"` to find
products reviewed by anyone whose name contains "alice".

---

#### Cross-Level AND Conditions

The most powerful use of nested path keys is combining conditions that live at
**different depths** into a single AND query. The engine always evaluates all
conditions at the **same result node** (the product level in the example below).

**Goal:** Find products where:
- `price > 9` (direct field)  
- At least one review has `date ≥ 2025-04-01` (inside the reviews array)  
- `rating ≥ 4.0` (direct field)

```
Chip 1:  products.price   >   "9"          (Num)
Chip 2:  products.reviews.date  ≥  "2025-04-01"   (Date / ISO 8601)
Chip 3:  products.rating  ≥  "4"           (Num)
```

How the engine processes `$.products[0]` (Mascara, price=9.99, rating=4.5):

```
Chip 1: products.price  →  9.99 > 9         ✅
Chip 2: products.reviews.date  →  collect ["2025-01-10...", "2025-03-22..."]
        any ≥ 2025-04-01?                    ✗  (both dates are before April 1)
```

Mascara fails chip 2 → not returned.

How the engine processes `$.products[1]` (Foundation, price=29.99, rating=3.8):

```
Chip 1: products.price  →  29.99 > 9        ✅
Chip 2: products.reviews.date  →  collect ["2025-04-01...", "2025-05-15..."]
        any ≥ 2025-04-01?                    ✅  ("2025-04-01..." qualifies)
Chip 3: products.rating  →  3.8 ≥ 4.0       ✗
```

Foundation fails chip 3 → not returned.

> **Remember:** ALL chips must pass for a product to appear. Use the
> [enable/disable toggle](#enabling--disabling-conditions) to temporarily
> remove a chip from evaluation while you refine your query.

---

#### Common Patterns

The table below shows ready-to-use condition recipes for common real-world
scenarios. All examples assume the `products` structure shown above.

| Goal | Key | Type | Operator | Value |
|------|-----|------|----------|-------|
| Products cheaper than $20 | `products.price` | Num | `<` | `20` |
| Products with rating ≥ 4 | `products.rating` | Num | `≥` | `4` |
| In-stock products | `products.availabilityStatus` | Str | `=` | `In Stock` |
| Products in beauty category | `products.category` | Str | `=` | `beauty` |
| Products tagged "mascara" | `products.tags` | Any | `contains` | `mascara` |
| Products with any 5-star review | `products.reviews.rating` | Num | `=` | `5` |
| Products with recent reviews | `products.reviews.date` | Date | `≥` | `2025-01-01` |
| Products reviewed with word "great" | `products.reviews.comment` | Str | `contains` | `great` |
| Products wider than 10 cm | `products.dimensions.width` | Num | `>` | `10` |
| Products with no return policy | `products.returnPolicy` | Str | `=` | `No return policy` |

**Multi-condition example** (combine as chips):

> *Find beauty products under $15 that have at least one 5-star review and
> were reviewed after January 2025.*

```
Chip 1:  products.category         =        "beauty"      (Str)
Chip 2:  products.price            <        "15"          (Num)
Chip 3:  products.reviews.rating   =        "5"           (Num)
Chip 4:  products.reviews.date     ≥        "2025-01-01"  (Date / ISO 8601)
```

---

#### Troubleshooting

**No results when I expect some**

1. **Check the key path.** Use text search (🔍) to confirm the key name exists
   and is spelled correctly. The autocomplete dropdown in the filter form also
   lists every key found in the document.

2. **Check the type.** If you select **Num** but the field is stored as a
   string (e.g. `"price": "9.99"`), the comparison fails because the value is
   not a `num` at runtime. Try **Any** instead.

3. **Check operator vs. data type.** `contains` only works for **Any** and
   **Str**. For arrays of numbers or booleans, use `=` with the appropriate
   type.

4. **"Any" condition on nested arrays.** When using type **Any** with arrays of
   objects (not primitives), the `.toString()` representation of the whole
   object is compared. This is rarely useful — use a dotted path to reach a
   specific leaf field instead.

5. **Date comparisons not working.** Make sure the format matches the actual
   stored format. Use the **ISO 8601** preset for strings like
   `"2025-04-30T09:41:02.053Z"`. If your dates are Unix timestamps, choose
   **Unix (s)** or **Unix (ms)** accordingly.

6. **Condition passes for the wrong level.** If you write key `reviews.date`
   (without the leading `products.`), the engine may match review objects
   directly instead of product objects. Always start the dotted path from the
   outermost array key (e.g. `products`) to anchor results at the product level.

**Results include objects I did not expect**

The engine uses an **any-match** rule for arrays: a product is returned if
*at least one* review satisfies the condition. If you want to require that
*all* reviews satisfy a condition, that is not directly supported — consider
adding a more restrictive condition (e.g. a minimum count) or post-filtering
the results manually in the tree view.

---

### AND Chaining

Each added condition appears as a **chip** in the filter bar. Multiple chips are joined with **AND** — a result must satisfy *all* active conditions to appear.

```
[ products.price > "9" Num × ]  AND  [ products.rating ≥ "4" Num × ]  + Add condition
```

There is no built-in OR operator between chips. To express OR logic, run separate filter queries or use the **Any** type with a broader value.

---

### Editing a Condition

Click the **body of any condition chip** to open the edit form pre-filled with that condition's current values. The **Add** button changes to **Save**.

While a chip is being edited:
- It displays a small pencil icon ( ✏ ) and a brighter border.
- Clicking the same chip again closes the form without saving.
- Clicking a *different* chip switches the form to edit that chip instead.

---

### Enabling / Disabling Conditions

Each chip has a **toggle icon** ( 🔵 on / ⚪ off ) on its left side. Click it to temporarily disable that condition without removing it.

- Disabled conditions are shown at reduced opacity.
- The **AND** label between chips also dims when a chip is disabled.
- Results update immediately — the badge reflects only the **active** conditions.
- Re-enable at any time by clicking the toggle again.

This is useful for comparing results with and without a specific condition, or for saving conditions you might need later.

---

### Switching Views

Object Filter results are displayed as a **flat path-list** by default:

```
> $.products[0]    {21 keys}
> $.products[3]    {21 keys}
> $.products[7]    {21 keys}
```

**Clicking a result row** switches to the Tree View, automatically expands the target object, and scrolls it into view. The breadcrumb bar shows the selected path.

The **list/tree toggle icon** ( ☰ / 🌲 ) in the filter bar lets you switch between the path-list and the tree at any time without losing your conditions.

---

## Quick Reference

### Text Search — Toolbar Icons

| Icon | Action |
|------|--------|
| 🔍 | Open / close search |
| ↑ / ↓ | Previous / next result |
| ⧉ | Copy all result paths |
| ✕ | Clear search |
| ☰ / 🌲 | Toggle path-list / tree view |

### Text Search — Scope & Filters

| Control | Location | Purpose |
|---------|----------|---------|
| Keys / Both / Values | Scope row | What to match against |
| Subtree | Scope row (when node selected) | Limit to current branch |
| Aa | Right of value field | Case-sensitive toggle |
| Str/Num/Bool/Null/Obj/Arr | Type row | Restrict by value type |

### Object Filter — Condition Chip Anatomy

```
[ 🔵 ✏  products.rating  ≥  "4"  Num  Aa  × ]
  ↑   ↑  ──── key ─────  op  val  type cs  remove
  │   └── editing indicator (when form is open)
  └─── enable/disable toggle
```

### Object Filter — Keyboard / Mouse Actions

| Action | Result |
|--------|--------|
| Click chip body | Open edit form for that condition |
| Click toggle (🔵/⚪) | Enable / disable condition |
| Click ✕ | Remove condition permanently |
| Click result row | Jump to node in tree view |
| Click ☰/🌲 | Switch path-list ↔ tree view |
| Click **Clear all** | Remove all conditions |
