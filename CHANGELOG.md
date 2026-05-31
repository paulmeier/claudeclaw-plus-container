# Changelog

## [1.3.0](https://github.com/paulmeier/claudeclaw-plus-container/compare/v1.2.0...v1.3.0) (2026-05-31)


### Features

* **trixie base + Chromium runtime deps for the dev-browser plugin** ([#19](https://github.com/paulmeier/claudeclaw-plus-container/pull/19)) ([043b093](https://github.com/paulmeier/claudeclaw-plus-container/commit/043b0934a00caa3f207da56a721ba3aa56cbc28b))

This release rebases the image on **Debian 13 "trixie"** and pre-installs the Chromium runtime libraries the bundled [`dev-browser`](https://github.com/SawyerHood/dev-browser) plugin needs, so headless-browser automation works out of the box on both `linux/amd64` and `linux/arm64`. It brings ClaudeClaw+ to parity with the vanilla image's [v1.10.0](https://github.com/paulmeier/claudeclaw-container/releases/tag/v1.10.0).

* **Base image:** `node:24-slim` (Debian 12 "bookworm") → `node:24-trixie-slim` (Debian 13) — glibc 2.36 → **2.41**, Python 3.11 → **3.13**.
* **Chromium runtime libraries baked in** (Playwright's canonical Debian-13 set: `libglib2.0-0t64`, `libnss3`, `libgbm1`, `libasound2t64`, `libatk-bridge2.0-0t64`, …). `dev-browser` auto-installs on startup and now launches headless Chromium without an in-container `apt-get` — which hardened deployments block by dropping `CAP_SETGID`.
* **Removes the fragile musl-binary workaround** that older bookworm images needed for `dev-browser`; glibc 2.41 satisfies the upstream `dev-browser-linux-{x64,arm64}` binaries directly.
* **Image size:** ~1.32 GB → ~1.63 GB uncompressed (the Chromium libraries are the bulk).

#### ⚠️ Upgrade note — one-time Python migration

trixie ships Python **3.13**; the previous base shipped **3.11**. Any `pip`-installed packages saved in your volume under `python-user/lib/python3.11/` become invisible to the new interpreter (the files stay on disk — they are just off Python 3.13's search path). On first start the container's healthcheck prints a warning pointing here; restore them with:

```bash
docker compose exec claudeclaw-plus /migrate-python.sh
```

Your config, data, and npm / pnpm / uv tooling are unaffected (those are keyed differently). Nothing else changes — same entrypoint, ports, and `/root/.claude` volume.

## [1.2.0](https://github.com/paulmeier/claudeclaw-plus-container/compare/v1.1.0...v1.2.0) (2026-05-19)


### Features

* port UV + pnpm + migrations + healthcheck + Dockerfile-ENV to plus ([2b60f33](https://github.com/paulmeier/claudeclaw-plus-container/commit/2b60f334ebffcf74eda2fa752deeffcb96bd03e9))
* port UV + pnpm + migrations + healthcheck + Dockerfile-ENV to plus ([0b6a6a4](https://github.com/paulmeier/claudeclaw-plus-container/commit/0b6a6a44ec66289d63f0f7db77a53ee73c00b40e))

## [1.1.0](https://github.com/paulmeier/claudeclaw-plus-container/compare/v1.0.2...v1.1.0) (2026-05-18)


### Features

* install python3 + pip and persist pip-installed packages in the volume ([5e78c68](https://github.com/paulmeier/claudeclaw-plus-container/commit/5e78c68563baec1b56b14469c4702553c2b2b04c))
* install python3 + pip and persist pip-installed packages in the volume ([c1239ea](https://github.com/paulmeier/claudeclaw-plus-container/commit/c1239eadf5ea91748c88f848d5795ce49f56badd))

## [1.0.2](https://github.com/paulmeier/claudeclaw-plus-container/compare/v1.0.1...v1.0.2) (2026-05-18)


### Bug Fixes

* install python3 to support Claude Code subprocesses ([b261e6e](https://github.com/paulmeier/claudeclaw-plus-container/commit/b261e6e853e8171b2e153f3241b7c953d0535ed1))
* install python3 to support Claude Code subprocesses ([31f741b](https://github.com/paulmeier/claudeclaw-plus-container/commit/31f741b73ee9c47e1bde6864713a3285be360256))

## [1.0.1](https://github.com/paulmeier/claudeclaw-plus-container/compare/v1.0.0...v1.0.1) (2026-05-16)


### Bug Fixes

* chain docker-publish via workflow_dispatch (release event from GITHUB_TOKEN doesn't fire downstream workflows) ([0b49515](https://github.com/paulmeier/claudeclaw-plus-container/commit/0b49515fa70c155254acc3b57f56fb8b9c86d507))
* chain docker-publish via workflow_dispatch instead of release event ([ac58826](https://github.com/paulmeier/claudeclaw-plus-container/commit/ac5882600b9ae978723d46fe513dec2c6c1472db))

## 1.0.0 (2026-05-16)


### ⚠ BREAKING CHANGES

* removes the semantic-release pipeline. New releases go through the release-please PR flow instead of being auto-cut on every fix:/feat: merge to main.

### Features

* add claudeclaw-plus-container icon ([68fdcc4](https://github.com/paulmeier/claudeclaw-plus-container/commit/68fdcc4ea2332f034f6204e195133cca0898f5f6))
* migrate release pipeline from semantic-release to release-please ([586767d](https://github.com/paulmeier/claudeclaw-plus-container/commit/586767d63164eb2e8143b4aa6b1e3cf06365ffd2))


### Bug Fixes

* drop semantic-release git/changelog plugins blocked by branch protection ([e2647ca](https://github.com/paulmeier/claudeclaw-plus-container/commit/e2647caa0aaa3573a588fb3eea7cb735f73c8eb4))


### Miscellaneous Chores

* reset release-please seed and target initial 1.0.0 ([cdee647](https://github.com/paulmeier/claudeclaw-plus-container/commit/cdee647dc75ab9fb7df2a043eccf1d50ed05e7f6))
