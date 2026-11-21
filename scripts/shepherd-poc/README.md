# shepherd-poc scripts — Release 0 (3rd pilot)

Third pilot of the Shepherd Release 0 POC after [`bboortz/healthy HC-008`](https://github.com/bboortz/healthy/blob/main/docs/stories/HC-008-shepherd-poc.md) and [`bboortz/beaconry BC-145`](https://github.com/bboortz/beaconry/blob/main/docs/stories/BC-145-shepherd-poc.md). The picks for the first two pilots turned out to be too dependency-clean to trigger Trivy; ham-radio-compass is an Expo / React Native app with a real `package-lock.json`, so this run gives the agent-fix path real material to work with.

Product design: [`bboortz/shepherd SH-004`](https://github.com/bboortz/shepherd/blob/main/docs/stories/SH-004-r0-poc-on-healthy.md)
Trust-boundary spec: [`bboortz/shepherd docs/DESIGN.md §12`](https://github.com/bboortz/shepherd/blob/main/docs/DESIGN.md)

## Files

| Script | Role |
|---|---|
| `install-trivy.sh` | Download Trivy v0.69.3 + `cosign verify-blob --new-bundle-format`. No `aquasecurity/trivy-action` wrapper (CVE-2026-33634). |
| `agent-call.sh` | `curl` to Anthropic Messages API with the findings JSON. Hard-coded R0 defaults: `max_tokens=4096` (~€1/run), 3 retries, scope level 1 (deps + lockfiles only). |
| `validate.sh` | Protected-files blocklist + 50-line diff cap. The only enforcement line in R0. |
| `open-pr.sh` | `git apply --check`, branch `shepherd-poc/<timestamp>`, commit, push, `gh pr create` against `main` (ham-radio-compass has no `dev` default) with labels `shepherd-poc` + `needs-review`. |

## Operator setup

```sh
gh secret set ANTHROPIC_API_KEY -R bboortz/ham-radio-compass
gh workflow run shepherd-poc.yml -R bboortz/ham-radio-compass
```

## R0 scope reminder

- Scope level 1: dependencies and lockfiles only. Any fix needing a source change → `NO_FIX_POSSIBLE`.
- Protected paths: `.github/workflows/**`, `.shepherd.yml`, `scripts/release.sh`, `VERSION`, `*.env`, `*.pem`, `*.key`.
- Diff cap: 50 changed lines.
- Sandbox gap (documented): agent step runs on a stock GitHub-hosted runner — no network perimeter. R1 adds it.
