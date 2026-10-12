# Vaultline Reference — local setup

Requirements: macOS 15+, Xcode 26 (tested 26.6), XcodeGen on PATH. Mac build has no third-party Swift package dependencies. iOS remains the upstream companion, has not been rebranded/qualified, and does not implement Reference briefs; its DEBUG-only DialKit dependency remains unchanged. The marketing website remains upstream.

```sh
git clone https://github.com/jake-vaultline/vaultline-reference.git
cd vaultline-reference
git checkout codex/vlp-2172-reference-production
./scripts/run-reference.sh
```

The unsigned developer build is `/private/tmp/vaultline-reference-dev/Build/Products/Debug/Snapwell.app`, display name Vaultline Reference. The binary/module/scheme retain Snapwell to keep upstream tests and imports intact. Bundle ID `com.vaultline.reference`; developer-build data in `~/Library/Application Support/VaultlineReference`; signed sandbox data lives inside `~/Library/Containers/com.vaultline.reference/Data/Library/Application Support/`. Upstream Snapwell data and keys are separate; no iCloud sync is enabled in the derivative Mac build. Build without signing does not imply notarization or distributable installation readiness. `dev.sh` remains the upstream release helper, **not** an authorized derivative release path.

Click **Reference → Footage** in the library toolbar. Name a brief, import PNG/JPEG/screenshot or video, or use **Try sample reference**. Add existing library items with the plus controls. For a credential-free walkthrough, type subject `coast`, lighting `warm`, and palette `orange teal`; check the attributes to include and click **Find archive footage**. Choose the warm coast result, **Select**, then **Export selects**, and choose an output folder. The resulting folder has the actual reference media, `manifest.json` with SHA-256 checksums, and `SELECTS.md`. Selections are snapshots and survive new searches. Cancelled imports/exports clean up their staging files. Removed references can be restored. Close/reopen the workspace to verify saved briefs and selections. Original library import, browse, spaces, search, playback and share remain accessible behind Done.

## Analysis providers

Manual observations always work. Default analysis is local Ollama at `localhost:11434`, with a user-selected installed vision model. Example setup:

```sh
ollama pull gemma3:4b
ollama serve
```

If Ollama already runs, do not start a second server. In Connection & analysis choose your installed vision model (this workstation also has `qwen3-vl:8b`). Analysis sends a still image or frames at 33% and 66% of video duration to the chosen provider. Sampled frames cannot prove camera movement, so that attribute stays empty for user review. The seven attributes distinguish observations from subjective mood; model descriptions still require review.

Optional cloud providers reuse upstream OpenAI, Anthropic, Gemini and OpenRouter implementations. Add your own credential in app Settings (⌘,) and select provider/model in the workspace. The workspace displays upload/cost disclosure before Analyze. Cloud analysis sends media directly to that provider. Workspace import makes **no** automatic model call. The legacy library preserves upstream automatic tagging when a provider is configured; choose local Ollama to keep that workflow local. No cloud calls are required for this demo.

Analysis cache keys include media bytes, provider, model and prompt. Repeat requests reuse results, including cached video samples after a partial failure. Corrections belong to the brief and persist independently of the original Snapwell analysis. Reanalysis can replace corrections; the action is explicitly labeled. Credentials are never in workspace files or exports. Release builds store provider credentials only in Keychain and surface errors rather than falling back to plaintext. Archive credentials use a separate Keychain namespace and explicit Save/Load/Forget controls. Changing the endpoint clears the in-memory token. Never add runtime data or `.keys.json` to Git.

Workspace writes are atomic, keep a last valid backup, and reject conflicting writers. If storage cannot be read, the app preserves it and offers recovery rather than resetting the library. See [Production release](PRODUCTION_RELEASE.md) for the signed candidate and deployment boundaries.

## Checks

```sh
cd macos
xcodegen generate
scripts/post-xcodegen.sh
xcodebuild test -project Snapwell.xcodeproj -scheme Snapwell -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/vaultline-reference-tests CODE_SIGNING_ALLOWED=NO
```

Tests use temporary storage and an in-memory SwiftData container. New tests cover fixture match evidence, ignored attributes, real MCP parsing/errors, structured analysis validation, image/video import, brief persistence, selection/export and connection safety. See `VERIFICATION.md` for recorded runs/screenshots and limitations; `LICENSING.md` for distribution duties.
