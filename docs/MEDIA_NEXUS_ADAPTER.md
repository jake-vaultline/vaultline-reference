# Archive integration

`ArchiveAdapter` separates Media Nexus from the bundled synthetic demo. Demo results use `demo-` identities and visibly say DEMO; errors in a real connection never substitute fixtures.

The real adapter uses the inspected Core contract: JSON-RPC 2.0 `tools/call` at POST `/api/mcp/v1/rpc`, with an existing read-scoped bearer token. Responses must have contract `mediaNexus.intelligence/1` and authority `media-nexus`.

- `get_capabilities` verifies installation identity and available tools.
- `query_archive` receives selected reference attributes, video media type and limit 30. It can return indexed asset, visual-shot or transcript evidence. Coverage and freshness remain visible; unavailable indexing is not reported as an empty successful search.
- `rank_assets` supplies a bounded recent-video pool when visual comparison is requested without searchable attributes or when semantic results are absent.
- `get_asset_visual` retrieves bounded managed previews by asset ID. The app never follows a catalog thumbnail URL with credentials.
- `asset_details` supplies actual volume/proxy availability. Failure leaves availability unknown.

Up to 12 retrieved previews are compared to the reference locally with Apple Vision revision-2 feature prints. Lower distance means closer preview appearance, not a confidence probability or proof of equivalent footage. This is bounded candidate reranking, not an archive-wide visual index. It performs no paid model call. Aspect normalization uses scaleFill; the full-resolution reference remains unchanged.

Asset identity is namespaced by installation; selection snapshots preserve the original evidence, connection origin, freshness, availability and any supplied numeric range. Ranges are **asset seconds**, not SMPTE timecode. Missing ranges say “Timecodes not supplied by archive”. An asset preview can differ from a matched shot. Explanations quote metadata/evidence and report visual distance separately; they do not infer missing contents or timestamps.

Configure the exact HTTPS MCP URL and an existing read-scoped token in Connection & analysis. HTTP is allowed only for loopback forwarding; redirects are rejected. Credentials can be explicitly saved in Keychain, never workspace JSON. Any endpoint change clears the in-memory credential. Test connection before searching. No credential is created by this application.

Live native search, preview retrieval and availability were exercised against the installed Sandbox through its existing approved read-only stdio connector, using an ephemeral local allowlisted JSON-RPC bridge. That bridge is qualification infrastructure, not a shipped gateway. Direct remote HTTPS/token deployment still requires the existing deployment's configured endpoint and token. No private catalog or customer media is included in this repository.

The supported handoff is export: original imported references, corrected attributes, selected IDs/evidence/ranges and checksums. Archive originals are not copied; recipients resolve the IDs in their authorized Media Nexus installation. Collection writes are not implemented because no qualified collection-write interface was available.
