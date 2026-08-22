# Changelog

All notable changes to this project are documented in this file.

This project follows [Semantic Versioning](https://semver.org) and the changelog
is generated automatically from [Conventional Commits](https://www.conventionalcommits.org)
by [release-please](https://github.com/googleapis/release-please). **Do not edit
entries below by hand** — write good commit messages instead.

## [1.4.0](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.3.0...settlement-v1.4.0) (2026-08-22)


### Features

* add personal-finance suite (accounts, recurring, AI, SMS import, widgets) ([#2](https://github.com/Abhi-shekes/settlement/issues/2)) ([5901721](https://github.com/Abhi-shekes/settlement/commit/59017215f4519dad081049538709dd533bdc173b))
* **ai:** draft and create splits from the AI assistant ([ab9a803](https://github.com/Abhi-shekes/settlement/commit/ab9a803d958b08d78ce4c10ae4744f6b701ca76d))
* **ai:** unify assistant into a single chat box ([4000686](https://github.com/Abhi-shekes/settlement/commit/4000686de1e964c992545b6c1e3c8e20df7c6f33))
* custom spending categories, AI-drafted splits, and group deletion fix ([b384cde](https://github.com/Abhi-shekes/settlement/commit/b384cdee4ed2149d31a6b228018925de00ba9060))
* **expenses:** custom user-defined spending categories ([a3740da](https://github.com/Abhi-shekes/settlement/commit/a3740da3d9ea08dc349d63244e86f45dc613988f))
* notification added & ai at one input ([4bd97fb](https://github.com/Abhi-shekes/settlement/commit/4bd97fbcbaabbc9a1c56a15cd29502a3b6a7572d))
* **notifications:** add in-app notification center ([3f80e90](https://github.com/Abhi-shekes/settlement/commit/3f80e903be63947f53a1cab670fe97062c28df6c))
* single bot for all ai job ([f71ff18](https://github.com/Abhi-shekes/settlement/commit/f71ff18c1a70d325b4fe508e2a0a0879d1705427))


### Bug Fixes

* **auth:** drop serverClientId that broke Google sign-in on release ([8fcd644](https://github.com/Abhi-shekes/settlement/commit/8fcd644f5cb6b312a3810b0ea31f64f501caff9f))
* **auth:** register release (upload) keystore SHA in Firebase config ([5d0a0b3](https://github.com/Abhi-shekes/settlement/commit/5d0a0b3727ac0ecb7774b8724844a3fa0260da8b))
* **auth:** show a network-aware sign-in error message ([f6af55d](https://github.com/Abhi-shekes/settlement/commit/f6af55d47b3ae21531fc0e943bcab3a0db799ae4))
* firebase rule added ui gap reduced ([b916f4d](https://github.com/Abhi-shekes/settlement/commit/b916f4dbf6667564f0ea5c9cdd0f9338d913d1aa))
* firebase rule added ui gap reduced ([cf29829](https://github.com/Abhi-shekes/settlement/commit/cf29829d643bf24fa06615d6a338c3984294e2be))
* **groups:** let the group admin query group splits so delete works ([b14e269](https://github.com/Abhi-shekes/settlement/commit/b14e26946ba0b8a1ad1b8b8bc3fe8951c230fad3))
* home unmount crash and clearer sign-in error ([4cd1eff](https://github.com/Abhi-shekes/settlement/commit/4cd1eff0afe7edea1700ec96e017205b913dde39))
* **home:** detach provider listeners without context.read in dispose ([0b67222](https://github.com/Abhi-shekes/settlement/commit/0b67222f606678b1a1a87a6c6f2133507afad487))
* remove sms scan feature and permission ([09d14a6](https://github.com/Abhi-shekes/settlement/commit/09d14a676a90a4d075b2b795f24866cf48793d6e))
* remove sms scan feature and permission ([550eb6b](https://github.com/Abhi-shekes/settlement/commit/550eb6b0319ad5f35618e01c3a0b734e3b7504db))
* restore Google sign-in on release builds ([a758740](https://github.com/Abhi-shekes/settlement/commit/a758740b0f053284dbfda80158ca63ee1249a60e))
* write release keystore to android/app so signing can find it ([fbfec6e](https://github.com/Abhi-shekes/settlement/commit/fbfec6ec0424f1275443fd6306c960882855bc90))
* write release keystore to android/app so signing can find it ([#4](https://github.com/Abhi-shekes/settlement/issues/4)) ([af0babb](https://github.com/Abhi-shekes/settlement/commit/af0babb13275d7caa02101024d00fbbfea99f2b7))


### Documentation

* update README ([99e2a34](https://github.com/Abhi-shekes/settlement/commit/99e2a3446955d6d823d15c260579c0f2652f496b))
* update README ([857a979](https://github.com/Abhi-shekes/settlement/commit/857a9799dd292f1687799054170d28e77b8e3994))

## [1.3.0](https://github.com/Abhi-shekes/settlement/compare/settlement-v1.2.2...settlement-v1.3.0) (2026-07-12)


### Features

* **ai:** draft and create splits from the AI assistant ([e3ea352](https://github.com/Abhi-shekes/settlement/commit/e3ea3520e6c43062abb838ba6b83fa0cdd639630))
* custom spending categories, AI-drafted splits, and group deletion fix ([815e78d](https://github.com/Abhi-shekes/settlement/commit/815e78d3fdb7d5dfa06dcc8554886b784e255188))
* **expenses:** custom user-defined spending categories ([9aaa8eb](https://github.com/Abhi-shekes/settlement/commit/9aaa8eb5ba3aba373de7d544bae56a3066cec517))


### Bug Fixes

* **auth:** register release (upload) keystore SHA in Firebase config ([f800879](https://github.com/Abhi-shekes/settlement/commit/f800879ba4944dd27e7abeed97087ac7fb905f72))
* **groups:** let the group admin query group splits so delete works ([8767c18](https://github.com/Abhi-shekes/settlement/commit/8767c1885bdd5778165353dc2634daf8c7165164))

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
