import Foundation
import Combine

@MainActor
final class SecondBrainContactListViewModel: ObservableObject {
    @Published var contacts: [SecondBrainContact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchText = ""
    @Published var totalCount = 0

    private let apiClient: SecondBrainContactAPIClient
    private let userId: UUID
    private var searchTask: Task<Void, Never>?

    init(apiClient: SecondBrainContactAPIClient = .shared, userId: UUID = UUID()) {
        self.apiClient = apiClient
        self.userId = userId
    }

    var filteredContacts: [SecondBrainContact] {
        guard !searchText.isEmpty else { return contacts }
        let query = searchText.lowercased()
        return contacts.filter { contact in
            contact.displayNameOrComputed.lowercased().contains(query)
                || (contact.canonicalEmail?.lowercased().contains(query) ?? false)
                || (contact.company?.lowercased().contains(query) ?? false)
                || (contact.title?.lowercased().contains(query) ?? false)
        }
    }

    func loadContacts() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await apiClient.getContacts(userId: userId, limit: 200, offset: 0)
            contacts = response.contacts
            totalCount = response.total
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func search() async {
        // Cancel any in-flight search
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            await loadContacts()
            return
        }

        searchTask = Task {
            isLoading = true
            errorMessage = nil

            do {
                let results = try await apiClient.searchContacts(userId: userId, query: query)
                if !Task.isCancelled {
                    contacts = results
                    totalCount = results.count
                }
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }

            if !Task.isCancelled {
                isLoading = false
            }
        }
    }

    func syncFromGmail() async {
        isLoading = true
        errorMessage = nil

        do {
            try await apiClient.triggerGmailSync(userId: userId)
            // Reload contacts after sync completes
            await loadContacts()
        } catch {
            errorMessage = "Gmail sync failed: \(error.localizedDescription)"
            isLoading = false
        }
    }

    func runDedup() async {
        isLoading = true
        errorMessage = nil

        do {
            let mergeCount = try await apiClient.triggerDedup(userId: userId)
            if mergeCount > 0 {
                // Reload to reflect merged contacts
                await loadContacts()
            } else {
                isLoading = false
            }
        } catch {
            errorMessage = "Dedup failed: \(error.localizedDescription)"
            isLoading = false
        }
    }
}
