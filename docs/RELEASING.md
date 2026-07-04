# Releasing

This project uses a fully automated, production-grade release flow. You never
edit a version number by hand — you write good commit messages, and the version,
changelog, git tag, GitHub Release, and signed builds are all generated for you.

## The mental model

```
 Conventional Commit            release-please              Release workflow
 ┌─────────────────┐   push    ┌────────────────────┐  merge ┌──────────────────┐
 │ feat: add X     │──────────▶│ opens "Release PR" │───────▶│ tag + GH Release │
 │ fix:  fix Y     │   main    │  bumps version     │  the   │ build signed AAB │
 └─────────────────┘           │  writes CHANGELOG  │  PR    │ build signed APK │
                               └────────────────────┘        │ attach to release│
                                                             └──────────────────┘
```

## 1. Write Conventional Commits

Format: `type(optional-scope): summary`

| Commit                                   | Version effect (after 1.0.0) |
| ---------------------------------------- | ---------------------------- |
| `fix: correct split rounding`            | patch — `1.0.0 → 1.0.1`      |
| `feat: add budget alerts`                | minor — `1.0.1 → 1.1.0`      |
| `feat!: rework settlement API`           | major — `1.1.0 → 2.0.0`      |
| `refactor:` / `docs:` / `chore:` / `ci:` | no release on their own      |

A breaking change is either a `!` after the type or a `BREAKING CHANGE:` footer.
Commit style is enforced automatically on every PR by the **Commit Lint** workflow.

## 2. release-please maintains a Release PR

On each push to `main`, `release-please` opens (or updates) a PR titled like
`chore(main): release 1.1.0`. It computes the next SemVer from the commits and
shows the exact `CHANGELOG.md` diff. Review it, and **merge it when you want to
cut a release.** Merging is the "publish" action.

## 3. The release builds itself

Merging the Release PR tags `vX.Y.Z`, creates the GitHub Release with generated
notes, and the same workflow then builds and attaches:

- `app-release.aab` (for the Play Store, if you add that later)
- `app-release.apk` (directly installable / for GitHub download)

`versionName` comes from the tag; `versionCode` is the CI run number, which only
ever increases — so the Play Store's monotonic-versionCode rule can never break.

## One-time setup you must do in GitHub

### A. Add signing secrets

The release build signs the app using your keystore, supplied via repository
secrets (**Settings → Secrets and variables → Actions → New repository secret**):

| Secret name                 | Value                                                        |
| --------------------------- | ----------------------------------------------------------- |
| `ANDROID_KEYSTORE_BASE64`   | `base64 -w0 your-release-keystore.jks` output               |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore's `storePassword`                              |
| `ANDROID_KEY_ALIAS`         | the key alias                                                |
| `ANDROID_KEY_PASSWORD`      | the key's password                                          |

> Use a **real release keystore**, not the checked-in `new-debug.keystore`.
> Generate one once and keep it safe (losing it means you can't update the app):
>
> ```bash
> keytool -genkey -v -keystore release-keystore.jks -storetype JKS \
>   -keyalg RSA -keysize 2048 -validity 10000 -alias upload
> base64 -w0 release-keystore.jks    # paste into ANDROID_KEYSTORE_BASE64
> ```

### B. Allow the release bot to open PRs

**Settings → Actions → General → Workflow permissions**: enable
"Read and write permissions" and "Allow GitHub Actions to create and approve
pull requests".

### C. (Recommended) Enforce the flow

- **Settings → General → Pull Requests**: enable *Allow squash merging* and set
  the squash commit message to *"Pull request title"* so PR titles (which are
  commit-linted) become the merged commit.
- Add a branch protection rule on `main` requiring the **CI** and **Commit Lint**
  checks to pass.

## Caveat: application ID

`android/app/build.gradle.kts` still uses `applicationId = "com.example.settlement"`.
GitHub distribution doesn't care, but change it to a real ID (e.g.
`in.filamentai.settlement`) before any Play Store submission — and it must match
`package_name` in `google-services.json`.
