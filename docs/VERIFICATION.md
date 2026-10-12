# Verification — 2026-10-12

Upstream source: `gustavscirulis/snapwell`, `4b2dd7c59c4c949dc8543714bd35c59975217971`.
Fork: https://github.com/jake-vaultline/vaultline-reference
Branch: `codex/vlp-2170-reference` · Console `VLP-2170`.
Environment: macOS, Xcode 26.6 (17F113), Swift 6, local unsigned developer build.

## Baseline

Before changes: generated the upstream Xcode project with XcodeGen/post-xcodegen, built the Mac app with `CODE_SIGNING_ALLOWED=NO`, and launched the original Snapwell application. Build succeeded; native library, import affordance, search toolbar and menu were present. Baseline build/log at `/private/tmp/vaultline-reference-baseline` and `/private/tmp/reference-baseline.log`. No upstream source notices were changed. `LICENSE` was compared byte-for-byte with `upstream/main:LICENSE` and remains identical; full GPL v3 text was added as `COPYING`.

## Automated checks

Final command:

```sh
xcodebuild test -project macos/Snapwell.xcodeproj -scheme Snapwell \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/vaultline-reference-dev CODE_SIGNING_ALLOWED=NO
```

**326 tests in 28 suites passed; TEST SUCCEEDED**. Final xcresult: `/private/tmp/vaultline-reference-dev/Logs/Test/Test-Snapwell-2026.10.12_00-33-32--0700.xcresult`. Log: `/private/tmp/reference-tests.log`.

Ten added tests cover selected-attribute matching and evidence, real MCP response parsing, the actual outgoing bounded search request, failed/malformed responses, structured attribute parsing, imported image/video and package export, cache reuse across process/service reload and model changes, separate video sample analysis/cache with movement withheld, corruption preservation, and token/HTTPS requirements. Provider calls in these tests are mocked; no paid cloud calls were made. Existing import, sidecar, spaces, sync, browsing/search models and local-provider tests pass. Malformed-image fixtures emit expected image-decoder diagnostics; there are no failing assertions.

`git diff --check` and `zsh -n scripts/run-reference.sh` passed. Generated three-second fixture was checked with ffprobe: 1920×1080, 24/1 fps, duration 3.000000 seconds. Only that catalog item has the supplied fixture video range; image entries have no ranges.

## Native UI walkthrough

1. Opened Reference → Footage, named a brief “Coastal launch film”, and imported the synthetic warm-coast image.
2. Selected the already-installed local Ollama `qwen3-vl:8b` model. Actual local inference returned all seven structured attributes: coastal subject/setting, horizontal composition, visible sun, orange/teal/tan/yellow palette, subjective serene/warm mood. Camera movement stayed unknown. The large local model took roughly two minutes on this workstation; a cancel control is available in the final build.
3. Repeated analysis: UI displayed **Cached Ollama / qwen3-vl:8b**, without another provider request.
4. Corrected subject, lighting and palette and unchecked setting/framing/mood. Search returned labeled synthetic candidates with thumbnails, source IDs and explanations quoting catalog fields. Selected `demo-coast-001`.
5. Exported via the actual native folder picker. UI confirmed `Vaultline-Reference-E8443872-CB14-409E-8BE5-01D61A604862`. Package is under `/private/tmp/reference-ui-export/`. It includes the reference, `manifest.json` and `SELECTS.md`, with the selected ID, source and supplied range. Exported reference SHA-256 `e4592a4abff9a2947084e4008ff5611d37c4548b8f9ea4158136357de8ae56a4` matches the imported bytes exactly.
6. Closed the workspace and opened the reference in the original Snapwell detail browser; original Share/Back controls remain present. Restarted the final tested app and reopened the workspace: title, notes, corrections, unchecked attributes, candidates and selection persisted; Export selects (1) remained enabled.
7. Imported the three-second video through the native file picker, entered manual observations, searched and selected footage. Switching between image and video preserved both selections (Export selects (2)).
8. Inspected the cloud-provider configuration: before analysis, the UI explains which media is sent, which provider receives it and possible charges. No cloud credential was entered or cloud analysis executed.

Screenshots are local and gitignored per the upstream repository instructions:

- `.screenshots/reference-to-selects-cropped.png` — final native workspace and selected candidate.
- `.screenshots/edit-attributes-and-select-cropped.png` — editable observed/subjective attributes and source/timecode evidence.
- `.screenshots/cloud-disclosure.png` — optional provider disclosure.
- `.screenshots/original-browsing.png` — preserved upstream detail browser.
- `.screenshots/upstream-baseline.png` — original launch.

Raw captures remain beside the cropped captures. Crops remove only unused screenshot canvas; no UI contents were altered.

## Prototype limits (superseded for Mac production branch)

The **local demo vertical slice is qualified**. The real adapter reuses the inspected Core MCP contract, including managed previews, and passes transport/response tests. A live app-scoped read token has not been supplied, so live search, live thumbnail rights and production metadata quality have **not** been qualified. Enter an existing token and target URL in Connection & analysis and repeat the same journey to qualify the real archive. No reference media is sent to Media Nexus; only chosen search words are sent.

Real search is catalog/tag/transcript AND matching, capped at six words, not a claim of semantic visual similarity. Search_assets supplies no shot ranges: the UI says “Timecodes not supplied by archive”. Collection writes are not implemented; export fulfills the save-or-export path. Archive original footage is not copied into the package. Optional cloud providers have unit/contract coverage from upstream, but were not called live. iOS and the upstream website are unchanged and were not qualified for Reference. No signed/notarized artifact, client deployment or public binary distribution was performed; corresponding-source planning is in LICENSING.md.


## Production hardening qualification — VLP-2172

Branch `codex/vlp-2172-reference-production`, based on prototype commit `91df939ef75b2569b2ba02b5d55624069493ae4d`. Full native suite: **342 tests in 30 suites passed**, TEST SUCCEEDED. Command: `xcodebuild test -project macos/Snapwell.xcodeproj -scheme Snapwell -destination 'platform=macOS' -derivedDataPath /private/tmp/reference-production-build CODE_SIGNING_ALLOWED=NO`. Evidence: `/private/tmp/reference-production-tests.log`; xcresult `Test-Snapwell-2026.10.12_02-10-13--0700.xcresult`.

Added coverage verifies workspace migration, backups, damaged-file preservation, conflicting-writer rejection, selection snapshots, removed-reference restore, provider credential origin reset, cancellable streamed imports/exports, partial-output cleanup, real semantic search contract, response freshness/coverage, supplied ranges and Vision distances. Tests retain upstream import, model, sidecar and browsing coverage. No paid cloud calls occurred.

The installed Sandbox was accessed read-only via its existing approved MCP stdio connection and an ephemeral loopback JSON-RPC bridge (only capabilities, query/rank, managed previews and asset details). The native app imported an actual owned archive preview; an installed local vision model described the visible subject/setting/palette. The operator corrected the setting, selected only that attribute, searched, viewed 30 real candidates, and compared the first 12 previews on-device. The known matching source ranked first, with online-volume and ready-proxy facts returned by asset_details. No range was supplied for that item, and the UI explicitly said so.

Selected that real candidate in the native UI and exported using the native folder picker. Package `/private/tmp/reference-production-export/Vaultline-Reference-1741E5C1-640E-42D0-ACDA-135459651532` contains one reference and one real selection. Every recorded reference checksum matches its exported bytes. Search refresh retained the saved selection. Private reference/catalog evidence stays local and is absent from this repository and Console. Screenshot `.screenshots/production-live-archive.png` captures this native experience; it is private, gitignored, and preserves the complete app capture.

Bounded visual retrieval: 12 transformed references against 12 older real archive previews (10 unique previews, two duplicate groups), source top-1 10/12, top-3 12/12, approximately 0.19 seconds for 144 comparisons. This is known-source preview retrieval, not blind creative relevance or archive-wide similarity qualification. Detailed private inputs remain outside Git.

Signed/notarized packaging is reproducible via scripts/package-reference.sh. Per-build signing/notarization, installation and runtime readbacks are recorded outside Git in the artifact directory keyed by the exact commit, so source identity remains reproducible. See PRODUCTION_RELEASE.md for supported scope and the customer's remaining configured-connection and creative-review gates.
