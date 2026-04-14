import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var lockStore: LockStore
    @EnvironmentObject private var permissionManager: ScreenTimePermissionManager
    @State private var selectedTab: HomeTab = .add
    @State private var isAddingLock = false
    @State private var editingLock: AppLock?
    @State private var showScreenTimeRequiredAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                tabPage {
                    addLockContent
                }
                .navigationBarHidden(true)
            }
            .tabItem {
                Label("Add Lock", systemImage: "plus.circle")
            }
            .tag(HomeTab.add)

            NavigationStack {
                tabPage {
                    currentLocksContent
                }
                .navigationBarHidden(true)
            }
            .tabItem {
                Label("Current Locks", systemImage: "lock.square.stack")
            }
            .tag(HomeTab.locks)
        }
        .sheet(isPresented: $isAddingLock) {
            AddLockView()
        }
        .sheet(item: $editingLock) { lock in
            EditLockView(lock: lock)
        }
        .alert("Screen Time Access Needed", isPresented: $showScreenTimeRequiredAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Screen Time access is required before creating locks.")
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 104, height: 104)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: AppTheme.softShadow, radius: 16, x: 0, y: 10)
        }
        .frame(maxWidth: .infinity)
    }

    private func tabPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(spacing: 26) {
                header
                content()

                if let message = lockStore.lastErrorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
    }

    private var addLockContent: some View {
        VStack(spacing: 12) {
            SectionTitle(title: "Add New Lock")
            AddLockCard {
                if permissionManager.isAuthorized {
                    isAddingLock = true
                } else {
                    showScreenTimeRequiredAlert = true
                }
            }
        }
    }

    private var currentLocksContent: some View {
        VStack(spacing: 12) {
            SectionTitle(title: "Current Locks")
            if lockStore.locks.isEmpty {
                EmptyLocksView()
            } else {
                VStack(spacing: 12) {
                    ForEach(lockStore.locks) { lock in
                        LockCard(
                            lock: lock,
                            onEdit: { editingLock = lock },
                            onPause: { Task { await lockStore.togglePause(lock) } },
                            onDelete: { Task { await lockStore.delete(lock) } }
                        )
                    }
                }
            }
        }
    }
}

private enum HomeTab: String {
    case add
    case locks
}
