# Footguns

Things that have bitten us and will bite again if undocumented.

---

## Tailwind CSS does not scan extension templates

**Symptom:** Tailwind utility classes (including heroicons like `hero-arrow-up`) used in an extension's LiveView templates appear to have no effect — elements are invisible or unstyled.

**Cause:** The Tailwind build is configured in `apps/wiki/assets/css/app.css` with explicit `@source` paths. It scans `apps/wiki/lib/wiki_web` by default but knows nothing about other apps in the umbrella.

**Fix:** Add an explicit `@source` line for each new extension app:

```css
/* apps/wiki/assets/css/app.css */
@source "../../lib/wiki_web";
@source "../../../deliberation/lib";   /* ← add one line per extension */
```

**Why not a glob?** `@source "../../../*/lib"` looks like it should work but proved unreliable in practice — icons became invisible again when the glob replaced the explicit path. Use explicit lines until this is revisited.
