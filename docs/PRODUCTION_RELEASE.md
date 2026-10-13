# Production candidate

This branch hardens the native Mac reference-to-selects workflow. It retains upstream import/browse behavior, GPL notices and the full corresponding source. iOS and the upstream website are outside this release.

## Build and package

Use Xcode 26, XcodeGen and macOS 15 or later. Run the documented local setup or open the generated Snapwell project. The app's product name is Vaultline Reference; the module and executable remain Snapwell.

For a clean, committed checkout, use an existing approved Developer ID fingerprint and notarytool Keychain profile:

```sh
REFERENCE_SIGNING_IDENTITY='<verified Developer ID fingerprint>' \
REFERENCE_NOTARY_PROFILE='<existing Keychain profile>' \
./scripts/package-reference.sh
```

The script builds arm64 and x86_64, signs with hardened runtime and App Sandbox, notarizes/staples the app and disk image, checks Gatekeeper, and writes release.json with exact source identity and checksums. Output is outside Git under Vaultline/artifacts/reference/<commit>. The DMG contains the app, LICENSE, COPYING and an exact git-archive source tarball. No public binary upload is performed. Keep the corresponding source available wherever this derivative is distributed; a private fork does not remove GPL duties. See LICENSING.md. `notarization-upload.zip` is submission material, not the distributable.

## Operations and data

Use one running app per workspace. Atomic workspace writes include schema/revision validation, a last-valid backup and a file lock; stale writers fail visibly. Damaged files are preserved. SwiftData startup failure opens a recovery screen instead of deleting the library. Keep routine backups of the entire app support folder, including media and database sidecars.

Signed sandbox builds use the bundle's macOS container. Unsigned prototype data outside that container is not automatically migrated; retain it and reimport references or restore a complete support-folder backup while the app is closed. Within a workspace, legacy brief JSON is migrated without deletion. Do not copy partial SQLite files while the app is running.

Archive tokens and release provider keys use Keychain with no plaintext fallback. Tokens are cleared on endpoint change. Manual review works without a provider. Local Ollama sends media only to the local server; optional cloud analysis is disclosed before sending compact media and may incur provider charges. Analysis is cached by media/provider/model/prompt; no automatic format or transient retry repeats Reference provider requests.

Imports and exports stage streamed copies away from completed files and remove partial output on failure/cancellation. Export checksum manifests refer to the original reference bytes. Saved selects survive changes to attributes and search results. Removed references can be restored.

## Qualification boundaries

A signed/notarized build, a successful test install, a read-only live archive journey and creative relevance acceptance are separate evidence. Native integration was qualified against the installed Sandbox through its approved read-only connector and temporary loopback transport. A customer's configured HTTPS endpoint/token, collection writes, cloud provider calls, iOS and client deployment are not qualified by that test.

The visual retrieval check used 12 transformations of known-source previews against 12 older archive previews (10 unique previews): 10/12 source top-1 and 12/12 source top-3, about 0.19 seconds for 144 local comparisons. This validates known-source retrieval in a bounded pool; it does not establish thematic match quality on unseen briefs or across the whole archive. A producer must review previews, metadata, source availability and supplied ranges before using footage.
