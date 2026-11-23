# HRC — Dev-cycle contract (SH-014 umbrella; onboarded via SH-018 2026-11-22).
#
# HRC is a React Native/Expo app — no unit-test harness today. Contract
# targets alias the npm scripts that exist (`npm run check` = tsc + lint).
# Full Expo builds happen via EAS (`eas-build.yml`), not in-band here.
#
# Budgets (SH-014):
#   ci-branch  ≤ 5 min   ci-patch ≤ 5 min   ci-release ≤ 15 min   ci-nightly ∞

.PHONY: build test test-affected smoke release-artifacts \
        prettier-check hook-commit hook-push check \
        ci-branch ci-patch ci-release ci-release-promote ci-nightly

build:  ## tsc + lint (no bundled artifact — EAS owns the device builds)
	npm run check

test:  ## no unit-test harness today; `check` stands in (SH-018)
	npm run check

test-affected: test  ## full-run alias (HRC has no module graph yet)

prettier-check:  ## SH-042 — prettier format check (commit-stage step)
	npx prettier . --check

# ---------------------------------------------------------------------------
# SH-042 — fleet-wide hook-commit / hook-push tier wrappers.
# Each tier name means the same thing on every fleet repo; step contents stay
# repo-native. HRC mapping: COMMIT_STEPS = prettier-check, PUSH_STEPS = check
# (alias for `npm run check` = tsc + eslint).
# Budgets: hook-commit ~15 s, hook-push ~2 min. See shepherd
# docs/plan/IDEAS-dev-workflow-contract-v3.md for the fleet mapping.
# ---------------------------------------------------------------------------
COMMIT_STEPS ?= prettier-check
PUSH_STEPS   ?= check

hook-commit: $(COMMIT_STEPS)
hook-push:   $(PUSH_STEPS)

check:  ## alias for `npm run check` (tsc + eslint) — used by PUSH_STEPS
	npm run check

smoke: test  ## 5-min post-merge smoke alias

release-artifacts:  ## no-op — EAS produces artifacts out-of-band
	@true

ci-branch: build test  ## 5-min PR gate (tsc + lint)

ci-patch: smoke  ## post-merge smoke

# ci-release-promote: FF dev → main + tag v<package.json.version> (SH-029 pattern,
# adapted to HRC's package.json version source). Runs only on `dev`.
ci-release-promote:
	@current=$$(git branch --show-current); \
	 [ "$$current" = "dev" ] || { echo "ci-release-promote must run on 'dev', got '$$current'"; exit 1; }
	@version=$$(node -p "require('./package.json').version"); \
	 echo "SH-029 promote: dev → main as v$$version"; \
	 git fetch origin main && \
	 git checkout main && \
	 git merge --ff-only origin/dev && \
	 git tag "v$$version" HEAD && \
	 git push origin main && \
	 git push origin "v$$version" && \
	 git checkout dev

ci-release: ci-release-promote  ## FF dev → main + tag (SH-029); EAS deploys continue via eas-build.yml
	@echo "ci-release: EAS device artifacts continue via .github/workflows/eas-build.yml"

ci-nightly: build test  ## slow lane — same as ci-branch for now; prettier check-only
	npx prettier . --check
