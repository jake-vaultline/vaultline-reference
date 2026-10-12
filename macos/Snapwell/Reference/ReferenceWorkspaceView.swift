import SwiftUI
import SwiftData
import AppKit

struct ReferenceWorkspaceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MediaItem.createdAt, order: .reverse) private var items: [MediaItem]
    @State private var service = ReferenceService()
    @State private var referenceID = ""
    @State private var configure = false
    @State private var operation: Task<Void, Never>?
    private var briefIndex: Int { service.activeIndex ?? 0 }
    private var entryIndex: Int? { service.briefs[briefIndex].references.firstIndex { $0.mediaID == referenceID } }
    private var currentItem: MediaItem? { items.first { $0.id == referenceID } }
    private var selectedCount: Int { service.briefs[briefIndex].references.reduce(0) { $0 + $1.selectedIDs.count } }

    var body: some View {
        VStack(spacing: 0) {
            header.disabled(service.busy)
            Divider()
            HStack(alignment: .top, spacing: 0) {
                referenceColumn.frame(width: 265).disabled(service.busy)
                Divider()
                ScrollView { attributeColumn.padding(24).id(service.activeID + referenceID) }.frame(width: 375).disabled(service.busy)
                Divider()
                ScrollView { candidateColumn.padding(24) }.frame(maxWidth: .infinity).disabled(service.busy)
            }
            Divider()
            HStack {
                if service.busy { ProgressView().controlSize(.small); Button("Cancel") { operation?.cancel() } }
                Text(service.message.isEmpty ? "1  Collect references    →    2  Describe the look    →    3  Choose usable footage" : service.message)
                    .font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
                Text("Built on Snapwell · GPL v3+").font(.caption).foregroundStyle(.secondary)
            }.padding(14)
        }
        .frame(minWidth: 1140, idealWidth: 1240, minHeight: 720, idealHeight: 790)
        .background(Color(red: 0.043, green: 0.059, blue: 0.078))
        .preferredColorScheme(.dark)
        .tint(Color(red: 0.32, green: 0.62, blue: 0.95))
        .sheet(isPresented: $configure) { configuration }
        .onChange(of: service.briefs) { service.persist() }
        .onChange(of: service.connection) {
            for i in service.briefs.indices { for j in service.briefs[i].references.indices {
                service.briefs[i].references[j].candidates = []; service.briefs[i].references[j].selectedIDs = []; service.briefs[i].references[j].searchOrigin = nil
            } }
        }
        .onChange(of: service.activeID) { referenceID = service.briefs[briefIndex].references.first?.mediaID ?? "" }
        .task { referenceID = service.briefs[briefIndex].references.first?.mediaID ?? "" }
        .onDisappear { operation?.cancel() }
    }
    private var header: some View {
        HStack(spacing: 16) {
            if let url = Bundle.main.url(forResource: "vaultline-symbol-white", withExtension: "png"), let logo = NSImage(contentsOf: url) {
                Image(nsImage: logo).resizable().scaledToFit().frame(width: 38, height: 38).accessibilityLabel("Vaultline")
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Vaultline Reference").font(.title2.weight(.semibold))
                Text("From inspiration to footage you already own").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Text(service.connection == "demo" ? "LOCAL DEMO · synthetic archive" : "MEDIA NEXUS · connection configured")
                .font(.caption.weight(.semibold)).padding(9).background(.white.opacity(0.08), in: Capsule())
            Button("Connection & analysis") { configure = true }
            Button("Export selects (\(selectedCount))") { exportPackage() }.disabled(selectedCount == 0)
            Button("Done") { dismiss() }
        }.padding(20)
    }
    private var referenceColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("01 / REFERENCE BRIEF").font(.caption.monospaced()).foregroundStyle(.secondary)
            Picker("Brief", selection: $service.activeID) {
                ForEach(service.briefs) { brief in Text(brief.title).tag(brief.id) }
            }
            Button("New brief", systemImage: "plus") { service.createBrief(); referenceID = "" }
            TextField("Brief title", text: $service.briefs[briefIndex].title).textFieldStyle(.roundedBorder)
            TextField("What are you preparing?", text: $service.briefs[briefIndex].notes, axis: .vertical).lineLimit(2...4)
            Button("Import references…", systemImage: "square.and.arrow.down") { importReferences() }.buttonStyle(.borderedProminent)
            Button("Try sample reference", systemImage: "photo") { importSample() }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(service.briefs[briefIndex].references, id: \.mediaID) { entry in
                        if let item = items.first(where: { $0.id == entry.mediaID }) {
                            Button { referenceID = item.id } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ReferenceThumbnail(url: MediaStorageService.shared.thumbnailURL(id: item.id)).frame(height: 108).clipped()
                                    Text(item.analysisResult?.imageSummary ?? (item.isVideo ? "Video reference" : "Image reference")).font(.callout)
                                    Text(item.id.prefix(8)).font(.caption.monospaced()).foregroundStyle(.secondary)
                                }.padding(8).background(referenceID == item.id ? Color.accentColor.opacity(0.18) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                    Divider()
                    Text("ADD FROM YOUR SNAPWELL LIBRARY").font(.caption2).foregroundStyle(.secondary)
                    ForEach(items.filter { item in !service.briefs[briefIndex].references.contains { $0.mediaID == item.id } }) { item in
                        Button("\(item.isVideo ? "Video" : "Image") · \(item.id.prefix(8))", systemImage: "plus.circle") { service.addReference(item.id); referenceID = item.id }
                    }
                }
            }
            Text("Images, screenshots and videos. Import here stays local; analysis runs only when requested.").font(.caption).foregroundStyle(.secondary)
        }.padding(20)
    }
    @ViewBuilder private var attributeColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("02 / DESCRIBE THE LOOK").font(.caption.monospaced()).foregroundStyle(.secondary)
            Text("What matters in this reference?").font(.title2.weight(.semibold))
            Text("Correct observations and check the attributes to use in search. Mood is an interpretation.").font(.callout).foregroundStyle(.secondary)
            if let j = entryIndex, let item = currentItem {
                ReferenceThumbnail(url: MediaStorageService.shared.thumbnailURL(id: item.id)).frame(height: 156).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                Text(service.provider == .ollama ? "Local analysis · \(service.model) · no media upload" : "Cloud analysis · \(service.provider.displayName) · image or sampled video frames will be sent to this provider")
                    .font(.caption).foregroundStyle(service.provider == .ollama ? .secondary : Color.orange)
                Button(service.briefs[briefIndex].references[j].analysisOrigin.hasPrefix("Not analyzed") ? "Analyze reference" : "Analyze / use cached result", systemImage: "sparkles") { operation = Task { await service.analyze(item: item) } }
                Text(service.briefs[briefIndex].references[j].analysisOrigin).font(.caption2).foregroundStyle(.secondary)
                ForEach(service.briefs[briefIndex].references[j].attributes.indices, id: \.self) { k in
                    let attribute = service.briefs[briefIndex].references[j].attributes[k]
                    VStack(alignment: .leading, spacing: 5) {
                        Toggle(isOn: $service.briefs[briefIndex].references[j].attributes[k].matters) {
                            Text(attribute.id.capitalized + (attribute.interpretation ? " · subjective" : " · observation")).font(.callout.weight(.medium))
                        }
                        TextField(attribute.id == "camera movement" ? "Unknown unless observed in video" : "Enter or correct attribute", text: $service.briefs[briefIndex].references[j].attributes[k].value, axis: .vertical)
                            .textFieldStyle(.roundedBorder).lineLimit(1...2)
                    }
                }
                .onChange(of: service.briefs[briefIndex].references[j].attributes) {
                    service.briefs[briefIndex].references[j].candidates = []
                    service.briefs[briefIndex].references[j].selectedIDs = []
                    service.briefs[briefIndex].references[j].searchOrigin = nil
                }
                Button("Find archive footage →") { operation = Task { await service.search(referenceID: referenceID) } }.buttonStyle(.borderedProminent)
                    .disabled(ReferenceMatching.tokens(service.briefs[briefIndex].references[j].attributes).isEmpty)
                if service.connection != "demo" {
                    Text("Catalog AND search · first six terms: " + ReferenceMatching.tokens(service.briefs[briefIndex].references[j].attributes).prefix(6).joined(separator: ", ")).font(.caption2).foregroundStyle(.secondary)
                }
            } else { ContentUnavailableView("Choose a reference", systemImage: "photo.on.rectangle", description: Text("Import media or add an item from your existing library.")) }
        }
    }
    private var candidateColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("03 / USABLE FOOTAGE").font(.caption.monospaced()).foregroundStyle(.secondary)
            Text("Build your selects").font(.title2.weight(.semibold))
            if let j = entryIndex {
                let entry = service.briefs[briefIndex].references[j]
                if let origin = entry.searchOrigin { Text(origin).font(.caption.weight(.medium)).foregroundStyle(.orange) }
                if entry.candidates.isEmpty {
                    ContentUnavailableView(entry.searchOrigin == nil ? "Ready when you are" : "No catalog matches", systemImage: "film.stack", description: Text("Choose the attributes that matter, then find archive footage. Try fewer words if the archive has no matches."))
                }
                ForEach(entry.candidates) { candidate in
                    VStack(alignment: .leading, spacing: 10) {
                        CandidateThumbnail(candidate: candidate, endpoint: service.endpoint, token: service.token).frame(height: 150).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                        HStack {
                            Text(candidate.name).font(.headline)
                            Spacer()
                            Button(entry.selectedIDs.contains(candidate.id) ? "Selected ✓" : "Select") {
                                if entry.selectedIDs.contains(candidate.id) { service.briefs[briefIndex].references[j].selectedIDs.remove(candidate.id) }
                                else { service.briefs[briefIndex].references[j].selectedIDs.insert(candidate.id) }
                            }.buttonStyle(.bordered)
                        }
                        Text("\(candidate.demo ? "DEMO" : "MEDIA NEXUS") · \(candidate.id)").font(.caption.monospaced()).foregroundStyle(.secondary)
                        Text(candidate.source).font(.caption).textSelection(.enabled)
                        Text(candidate.timecode ?? "Timecodes not supplied by archive").font(.caption.monospaced()).foregroundStyle(.secondary)
                        ForEach(candidate.evidence, id: \.self) { Text("• " + $0).font(.callout).textSelection(.enabled) }
                        if !candidate.demo { Text("Metadata match; visual equivalence and footage availability need producer review.").font(.caption).foregroundStyle(.secondary) }
                    }.padding(14).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            Text("Export includes the references, corrected attributes, selected asset IDs and match evidence. Archive originals stay in Media Nexus.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var configuration: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Connection & analysis").font(.title2)
            Picker("Archive", selection: $service.connection) {
                Text("Local demo · synthetic fixtures").tag("demo")
                Text("Media Nexus · existing MCP connection").tag("real")
            }.pickerStyle(.segmented)
            if service.connection == "real" {
                TextField("https://your-server/api/mcp/v1/rpc", text: $service.endpoint).textFieldStyle(.roundedBorder)
                SecureField("Existing read-scoped token (memory only)", text: $service.token).textFieldStyle(.roundedBorder)
                Text("Search sends chosen attribute words to your server. No reference media is uploaded to Media Nexus. Connection failures never fall back to demo.").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            Picker("Analysis provider", selection: $service.provider) {
                ForEach(AIProvider.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }.onChange(of: service.provider) { service.model = service.provider.defaultModel }
            TextField("Vision model", text: $service.model).textFieldStyle(.roundedBorder)
            Text(service.provider == .ollama ? "Ollama runs at localhost:11434. Install a vision model first. Manual observations work without a model." : "Clicking Analyze sends the reference image, or sampled video frames, directly to this cloud provider. It may incur charges. Add your own provider key in the app’s Settings (⌘,); credentials are never exported.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Analysis is cached by media content, provider, model and prompt. Briefs and selections are saved locally.").font(.caption)
            HStack { Spacer(); Button("Done") { configure = false }.keyboardShortcut(.defaultAction) }
        }.padding(26).frame(width: 600)
    }
    private func importReferences() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = SupportedMedia.importableContentTypes; panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        ingest(panel.urls)
    }
    private func importSample() {
        guard let url = Bundle.main.url(forResource: "warm-coast", withExtension: "png") else { service.message = "Sample resource missing"; return }
        ingest([url])
    }
    private func ingest(_ urls: [URL]) {
        Task { @MainActor in
            service.busy = true; defer { service.busy = false }
            var succeeded = 0
            for url in urls {
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    // Reuse upstream import and sidecar handling, deliberately bypassing automatic AI upload.
                    let before = Set(try context.fetch(FetchDescriptor<MediaItem>()).map(\.id))
                    try await ImportService().importSingleFile(url, into: context, spaceId: nil, analyze: false)
                    let imported = try context.fetch(FetchDescriptor<MediaItem>()).filter { !before.contains($0.id) }
                    for item in imported { service.addReference(item.id); referenceID = item.id }
                    succeeded += 1
                } catch { service.message = "Import failed: \(error.localizedDescription)" }
            }
            if succeeded == urls.count { service.message = "Imported \(succeeded) reference(s). Add observations or request analysis." }
        }
    }
    private func exportPackage() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.prompt = "Export here"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do { let target = try service.export(to: url, items: items); service.message = "Exported \(target.lastPathComponent)"; NSWorkspace.shared.activateFileViewerSelecting([target]) }
        catch { service.message = "Export failed: \(error.localizedDescription)" }
    }
}
private struct ReferenceThumbnail: View {
    let url: URL
    @State private var image: NSImage?
    var body: some View {
        Group {
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { ZStack { Color.white.opacity(0.05); Label("Thumbnail unavailable", systemImage: "photo").font(.caption) } }
        }.task(id: url) { image = NSImage(contentsOf: url) }
    }
}
private struct CandidateThumbnail: View {
    let candidate: ArchiveCandidate
    let endpoint: String
    let token: String
    @State private var image: NSImage?
    var body: some View {
        if candidate.demo, let thumbnail = candidate.thumbnail, let url = Bundle.main.url(forResource: thumbnail, withExtension: "png") {
            ReferenceThumbnail(url: url)
        } else {
            Group {
                if let image { Image(nsImage: image).resizable().scaledToFill() }
                else { ZStack { Color.white.opacity(0.05); Label("Managed thumbnail unavailable", systemImage: "film").font(.caption) } }
            }.task(id: candidate.id + endpoint) {
                guard let url = URL(string: endpoint), url.scheme == "https" || ["localhost", "127.0.0.1", "::1"].contains(url.host), !token.isEmpty else { return }
                if let data = try? await MediaNexusAdapter(endpoint: url, token: token).visual(assetID: candidate.id) { image = NSImage(data: data) }
            }
        }
    }
}
