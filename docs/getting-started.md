# Getting started (planned)

Placeholder. Plugin API v1 is planned (FrameBeam 0.11) and not implemented; nothing here can be run yet. This page will be filled when the API is fixed.

## Planned layout of a plugin

```text
my-plugin/
  manifest.json   # id, version, api, permissions, games, entry (see manifest.example.jsonc, draft)
  main.lua        # entry point, Lua 5.4 in the FrameBeam sandbox
  i18n/           # UI strings: en.json (source), de.json (first translation)
  assets/         # own artwork only, never game content
```

## Open

- Exact Lua API, building-block catalog and manifest settings schema (FrameBeam design handoff and runtime work package).
- Local install and developer mode (FrameBeam 0.11).
- Packaging and signing as `.fbplugin`.

Interface description: FrameBeam `docs/architecture/12-plugins.md`.
