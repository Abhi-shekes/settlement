# Changelog

All notable changes to this project are documented in this file.

This project follows [Semantic Versioning](https://semver.org) and the changelog
is generated automatically from [Conventional Commits](https://www.conventionalcommits.org)
by [release-please](https://github.com/googleapis/release-please). **Do not edit
entries below by hand** — write good commit messages instead.

## [1.2.2](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.2.1...settlement-v1.2.2) (2026-07-09)


### Bug Fixes

* **auth:** drop serverClientId that broke Google sign-in on release ([0e1b943](https://github.com/Abhi-shekes/settlement/commit/0e1b943bd68c6ac7d6adef169bf0e9142eb0bbc0))
* restore Google sign-in on release builds ([0127b03](https://github.com/Abhi-shekes/settlement/commit/0127b0396bb52bdc95e863309826632bfc54baa7))

## [1.2.1](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.2.0...settlement-v1.2.1) (2026-07-09)


### Bug Fixes

* **auth:** show a network-aware sign-in error message ([1c044f0](https://github.com/Abhi-shekes/settlement/commit/1c044f0aea4f167af7d444b299ba6de5954e038e))
* home unmount crash and clearer sign-in error ([e6f4066](https://github.com/Abhi-shekes/settlement/commit/e6f40664de55a13a181ec0acb67a0e9be24ea4cb))
* **home:** detach provider listeners without context.read in dispose ([d55fc11](https://github.com/Abhi-shekes/settlement/commit/d55fc11166cfb5f48847e9ed852a8de1a53e7890))

## [1.2.0](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.1.4...settlement-v1.2.0) (2026-07-09)


### Features

* **ai:** unify assistant into a single chat box ([a2fe855](https://github.com/Abhi-shekes/settlement/commit/a2fe855ccf44ce952980316c15e79883547d6b50))
* notification added & ai at one input ([27a9d6c](https://github.com/Abhi-shekes/settlement/commit/27a9d6c6956b86cbd4ea3eac9fa1806605f0e627))
* **notifications:** add in-app notification center ([795c35a](https://github.com/Abhi-shekes/settlement/commit/795c35a5a924d9b6e38858f462dae95bc57fbaec))
* single bot for all ai job ([4bc40a7](https://github.com/Abhi-shekes/settlement/commit/4bc40a7b9c6dd4d26f503a10e8bc5ac347069fa1))

## [1.1.4](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.1.3...settlement-v1.1.4) (2026-07-05)


### Bug Fixes

* firebase rule added ui gap reduced ([bc87248](https://github.com/Abhi-shekes/settlement/commit/bc87248919466fb127b1ee56fad550998b1c8fc8))
* firebase rule added ui gap reduced ([4db4386](https://github.com/Abhi-shekes/settlement/commit/4db4386e139e041c555d97760dac8d715d472143))

## [1.1.3](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.1.2...settlement-v1.1.3) (2026-07-05)


### Bug Fixes

* remove sms scan feature and permission ([564c7e6](https://github.com/Abhi-shekes/settlement/commit/564c7e6819d9051ca33d74207898baa1bbfee2f1))
* remove sms scan feature and permission ([d0ed2bd](https://github.com/Abhi-shekes/settlement/commit/d0ed2bdbdcf2dfcd24d73ca54dc4f2d78eb0a474))

## [1.1.2](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.1.1...settlement-v1.1.2) (2026-07-05)


### Documentation

* update README ([386ccc9](https://github.com/Abhi-shekes/settlement/commit/386ccc9e24f33ff9e02144485e821ffbbbcb029c))
* update README ([3cc7a3b](https://github.com/Abhi-shekes/settlement/commit/3cc7a3b010d7174d48289638f38a063187c82f99))

## [1.1.1](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.1.0...settlement-v1.1.1) (2026-07-04)


### Bug Fixes

* write release keystore to android/app so signing can find it ([#4](https://github.com/Abhi-shekes/settlement/issues/4)) ([e125eac](https://github.com/Abhi-shekes/settlement/commit/e125eacf8bdd3fb6d8243c2bd36eb27167e55a00))

## [1.1.0](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.0.0...settlement-v1.1.0) (2026-07-04)


### Features

* add personal-finance suite (accounts, recurring, AI, SMS import, widgets) ([#2](https://github.com/Abhi-shekes/settlement/issues/2)) ([bbac941](https://github.com/Abhi-shekes/settlement/commit/bbac941d8c71e5e3b6e3d89970ca10d919dfdc54))

## 1.0.0 (unreleased baseline)

Initial baseline. Entries for the next release will be generated here when the
first `feat:` / `fix:` commit lands on `main`.
