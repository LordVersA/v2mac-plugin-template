# CLAUDE.md (plugin-template)

GitHub template repo for Secure Sandbox plugins, plus the samples `hello-gui` and `hello-pty`
that test the platform. Plan: `../app/docs/SANDBOX.md` §5 and §6, milestone M6 (samples in M3/M4).

- A plugin = `Containerfile` (`FROM` a base image from `../sandbox-runtime`), `plugin.json`
  (plugin API, integer `api`, additive only), an icon, and a CI workflow that builds the OCI layers
  at a tag and attaches them to a GitHub Release.
- Plugins get only what `plugin.json` asks for and the user approved. Never add vsock, host paths or
  network setup to a plugin; the runtime owns those.
- Keep it minimal: it is what every plugin author copies.
- Not on GitHub yet: no remote, no pushing until the user asks.
