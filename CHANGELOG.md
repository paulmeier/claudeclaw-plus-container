# Changelog

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
