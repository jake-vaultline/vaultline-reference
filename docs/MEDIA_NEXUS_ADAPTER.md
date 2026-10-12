# Archive integration

The archive boundary is `ArchiveAdapter`. `DemoArchiveAdapter` reads bundled `archive.json`: original synthetic images and a three-second, 24 fps static video. Those are a representative **test catalog**, never a team's own footage. Fields and explanations say fixture; IDs start with `demo-`. The video range is verified against its generated media. Images have no invented ranges.

`MediaNexusAdapter` reuses the existing Core MCP JSON-RPC endpoint, not a hypothetical search API:

- POST `/api/mcp/v1/rpc`, bearer token, JSON-RPC 2.0 `tools/call`.
- `search_assets` arguments `terms` (up to six space-separated AND terms) and `mediaType: video`.
- Response `result.structuredContent`, authority `media-nexus`, `data.items` with `assetId`, `name`, `folder`, `matched`; `data.evidence` keyed by `id`.
- Thumbnails use `get_asset_visual` with `assetId`, returned as a bounded MCP image block. Tokens are never sent to thumbnail URLs from catalog content. Missing preview rights/derivatives show “Managed thumbnail unavailable”.

Inspected Core `vaultline_mcp.py` TOOL_SCHEMAS, ITEM_FIELDS, SPECIAL_TOOL_SCHEMAS, envelope and RPC handler; `vaultline_tools.py` `_tool_search_assets`; `vaultline_server.py` route `/api/mcp/v1/rpc`. Search returns catalog/tag/transcript evidence, not shot ranges. Real candidate timecodes therefore say not supplied. Metadata matches do not prove visual similarity, online volume availability, or original-media retrieval. Future shot search can use the separately existing `query_archive` contract after qualification of its evidence and ranges.

Choose “Media Nexus” in Connection & analysis, enter your exact MCP URL and an **existing read-scoped token**. HTTPS is required remotely; loopback HTTP works for local forwarding. The token lives only in memory for this workspace. This does not create credentials. A configured connection is labeled configured, never healthy until a search actually returns results. Errors do not substitute fixtures. Changing archive mode clears stale matches/selections.

This slice supports package export rather than archive mutations. The package contains imported reference media, corrected attributes, chosen asset IDs, evidence, source locations, provider attribution, and any supplied range. It does not copy archive originals, claim to have saved a Media Nexus collection, or invent a collection API.

Live end-to-end qualification remains dependent on an existing app connection token and authorized target; the development environment’s connector is not a transferable app credential. Local tests exercise the exact response contract and fail-closed behavior. Real archive fixtures are never embedded in the fork.
