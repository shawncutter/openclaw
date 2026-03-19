import SwiftUI

struct SecondBrainContactListView: View {
    @StateObject private var viewModel = SecondBrainContactListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.contacts.isEmpty {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.contacts.isEmpty {
                    errorStateView(message: error)
                } else if viewModel.filteredContacts.isEmpty {
                    emptyStateView
                } else {
                    contactListView
                }
            }
            .navigationTitle("SecondBrain Contacts")
            .searchable(text: $viewModel.searchText, prompt: "Search contacts")
            .onChange(of: viewModel.searchText) {
                Task {
                    await viewModel.search()
                }
            }
            .refreshable {
                await viewModel.loadContacts()
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.syncFromGmail() }
                    } label: {
                        Label("Sync Gmail", systemImage: "envelope.arrow.triangle.branch")
                    }
                    .disabled(viewModel.isLoading)

                    Button {
                        Task { await viewModel.runDedup() }
                    } label: {
                        Label("Deduplicate", systemImage: "arrow.triangle.merge")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                await viewModel.loadContacts()
            }
        }
    }

    // MARK: - Subviews

    private var contactListView: some View {
        List(viewModel.filteredContacts) { contact in
            NavigationLink(value: contact) {
                SecondBrainContactRow(contact: contact)
            }
        }
        .listStyle(.insetGrouped)
        .navigationDestination(for: SecondBrainContact.self) { contact in
            SecondBrainContactDetailView(contact: contact)
        }
        .overlay(alignment: .bottom) {
            if viewModel.isLoading {
                ProgressView()
                    .padding()
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 8)
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Contacts", systemImage: "person.crop.circle.badge.questionmark")
        } description: {
            if viewModel.searchText.isEmpty {
                Text("Sync your contacts from Gmail or add them through SecondBrain.")
            } else {
                Text("No contacts match \"\(viewModel.searchText)\".")
            }
        } actions: {
            if viewModel.searchText.isEmpty {
                Button("Sync from Gmail") {
                    Task { await viewModel.syncFromGmail() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func errorStateView(message: String) -> some View {
        ContentUnavailableView {
            Label("Connection Error", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                Task { await viewModel.loadContacts() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Contact Row

struct SecondBrainContactRow: View {
    let contact: SecondBrainContact

    var body: some View {
        HStack(spacing: 12) {
            initialsCircle
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayNameOrComputed)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let email = contact.canonicalEmail, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let company = contact.company, !company.isEmpty {
                    Text(company)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var initialsCircle: some View {
        Text(contact.initials)
            .font(.system(.subheadline, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(initialsColor)
            )
    }

    private var initialsColor: Color {
        let hash = contact.displayNameOrComputed.hashValue
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint]
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - Contact Detail View

struct SecondBrainContactDetailView: View {
    let contact: SecondBrainContact

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 8) {
                    Text(contact.initials)
                        .font(.system(.title, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(.blue))

                    Text(contact.displayNameOrComputed)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let title = contact.title, !title.isEmpty,
                       let company = contact.company, !company.isEmpty {
                        Text("\(title) at \(company)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if let company = contact.company, !company.isEmpty {
                        Text(company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // Contact Info
            if contact.canonicalEmail != nil || contact.canonicalPhone != nil {
                Section("Contact Info") {
                    if let email = contact.canonicalEmail, !email.isEmpty {
                        LabeledContent("Email", value: email)
                    }
                    if let phone = contact.canonicalPhone, !phone.isEmpty {
                        LabeledContent("Phone", value: phone)
                    }
                }
            }

            // Organization
            if contact.company != nil || contact.title != nil {
                Section("Organization") {
                    if let company = contact.company, !company.isEmpty {
                        LabeledContent("Company", value: company)
                    }
                    if let title = contact.title, !title.isEmpty {
                        LabeledContent("Title", value: title)
                    }
                }
            }

            // Social Profiles
            if let profiles = contact.socialProfiles, !profiles.isEmpty {
                Section("Social Profiles") {
                    ForEach(profiles.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        LabeledContent(key.capitalized, value: value)
                    }
                }
            }

            // Metadata
            Section("Details") {
                LabeledContent("Created", value: contact.createdAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Updated", value: contact.updatedAt.formatted(date: .abbreviated, time: .shortened))
                if contact.enrichedFromClay {
                    LabeledContent("Enriched", value: "Yes (Clay)")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(contact.displayNameOrComputed)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Contact List") {
    SecondBrainContactListView()
}
#endif
