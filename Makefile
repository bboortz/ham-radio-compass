# HRC — Dev-cycle contract (SH-014 umbrella; onboarded via SH-018 2026-11-22).
#
# HRC is a React Native/Expo app — no unit-test harness today. Contract
# targets alias the npm scripts that exist (`npm run check` = tsc + lint).
# Full Expo builds happen via EAS (`eas-build.yml`), not in-band here.
#
# Budgets (SH-014):
#   ci-branch  ≤ 5 min   ci-patch ≤ 5 min   ci-release ≤ 15 min   ci-nightly ∞

.PHONY: build test test-affected smoke release-artifacts \
        ci-branch ci-patch ci-release ci-release-promote ci-nightly

build:  ## tsc + lint (no bundled artifact — EAS owns the device builds)
	npm run check

test:  ## no unit-test harness today; `check` stands in (SH-018)
	npm run check

test-affected: test  ## full-run alias (HRC has no module graph yet)

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
