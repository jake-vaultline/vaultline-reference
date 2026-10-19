# Your first Reference brief

Reference is the existing native Mac derivative of Snapwell. It runs on macOS 15
or later. Its brief workspace connects imported references, reviewed observations,
archive candidates and exported selects. iOS Reference and a web editing app are
not part of this release.

## Open Reference

For a qualified signed disk image supplied through an approved distribution route,
verify the supplied version and checksum, open the image, and copy **Vaultline
Reference.app** to Applications. Keep the accompanying notices and matching source.
Open the app through the normal macOS workflow. If Gatekeeper rejects it, retain
the exact error and artifact identity for the release owner; do not disable
Gatekeeper or re-sign the app to get past the check.

There is currently no public binary download. The [source setup](REFERENCE_SETUP.md)
builds and opens a developer version using Xcode 26 and XcodeGen. The executable
and Xcode scheme retain the upstream name `Snapwell`; the app display name is
Vaultline Reference and the bundle identifier is `com.vaultline.reference`.

In the library toolbar, choose **Reference → Footage**. The original library and
Spaces remain accessible after choosing **Done** in the workspace.

## Complete the synthetic walkthrough

1. Name your brief. Choose **Try sample reference**. The bundled coast image is
   original synthetic media; no private or client footage is needed.
2. Leave the archive on the visibly labeled local demo. Enter subject `coast`,
   lighting `warm`, and palette `orange teal`. Check those observations for search.
   Manual observations do not require analysis or a provider account.
3. Choose **Find archive footage**, inspect the warm coast candidate, then choose
   **Select**. Demo identities and evidence remain marked as synthetic.
4. Choose **Export selects**, then a writable folder using the native folder picker.
   Cancel the picker if you do not want to write a package.
5. Open the completed `Vaultline-Reference-<unique-id>` folder. Read `SELECTS.md`,
   inspect `manifest.json` and the `references/` folder, and verify that the selected
   identities/evidence and imported reference match what you chose.
6. Close and reopen the app. Confirm the saved brief, corrected observations and
   selects. Try another search; retained selects are snapshots of selection-time
   evidence. Availability can change after selection.

This demonstrates the workflow with fixtures. It does not establish relevance on
your archive, media rights, an archive-wide visual index, or current installed
connection readiness.

## Use your authorized archive

Use **Connection & analysis** to select the real Media Nexus connection. Enter
the existing deployment's approved HTTPS MCP URL and read-scoped token. Use the
explicit Keychain save/load/forget controls if desired, then **Test connection**.
Changing the endpoint clears the in-memory token. Do not put a token in the URL,
workspace, exported package, issue tracker or a screenshot.

The adapter uses `/api/mcp/v1/rpc` with the `mediaNexus.intelligence/1` contract.
Verify the returned installation identity. Read coverage/freshness and source
availability for each candidate. Missing ranges remain unknown; supplied ranges
are asset seconds. A preview may differ from the matched shot. Review the actual
media and supplied evidence before treating a candidate as useful.

The historical installed-archive qualification used a temporary local bridge to
an existing read-only stdio connector. That bridge was stopped and is not shipped
infrastructure. Direct HTTPS/token setup must be qualified on the actual existing
deployment. Do not create a token, widen access or change shared security as an
onboarding workaround. See [the adapter contract](MEDIA_NEXUS_ADAPTER.md).

## Inspect a handoff

The package contains the imported reference bytes, selected archive identities,
retained evidence, any supplied numeric ranges and reference SHA-256 checksums.
It does not copy archive originals or grant rights. Recipients need their own
authorized access to resolve the archive IDs. Preserve reference attribution and
license information separately when your media requires it; the app does not
establish a reference's license from its contents.

From inside the completed package, this read-only command verifies the reference
checksums on macOS without additional software:

```sh
python3 - <<'PY'
import hashlib, json, pathlib
root = pathlib.Path.cwd().resolve()
manifest = json.loads((root / 'manifest.json').read_text())
for relative, expected in manifest['checksums'].items():
    path = (root / relative).resolve()
    if not path.is_relative_to(root) or not path.is_file():
        raise SystemExit('Invalid or missing reference path: ' + relative)
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != expected:
        raise SystemExit('Checksum mismatch: ' + relative)
    print('OK', relative)
PY
```

## Recover safely

- **Archive unavailable:** retain the brief and selects. Check the approved
  endpoint, credential, network and archive status, then test the connection.
  Real connection failures do not substitute demo results. Unavailable indexing
  is different from a successful search with no matches.
- **Interrupted import/export:** completed packages stay separate from staging.
  Cancellation/failure removes partial output. Check the source file and choose
  a writable output folder before retrying. Do not delete completed packages.
- **Permission denied:** use the native picker to grant only the intended source
  or output-folder access. Do not alter global permissions or disable the sandbox.
- **Missing reference:** restore a removed brief reference using **Removed
  references**. A missing underlying media file requires restoring the library
  from its backup or reimporting the available source.
- **Conflicting writer:** close the other instance before saving again. Preserve
  the latest workspace; a stale writer is refused rather than overwriting it.
- **Damaged storage:** preserve the damaged bytes and follow the explicit backup
  recovery screen. Keep a complete library backup with the app closed. Signed
  sandbox storage and unsigned developer storage are separate; do not copy part
  of a running SQLite library or assume automatic migration between them.

Manual observations are sufficient for the walkthrough. Local Ollama analysis is
optional and needs an already installed vision model. Optional cloud analysis
sends media to the selected provider and may incur charges; review its disclosure
before invoking it. No analysis call is needed to import a reference in this
workspace. See [licensing](LICENSING.md) and [release boundaries](PRODUCTION_RELEASE.md).
