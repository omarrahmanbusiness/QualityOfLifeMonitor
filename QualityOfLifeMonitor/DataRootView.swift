import SwiftUI

public struct DataRootView: View {
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    LocationDataListView()
                } label: {
                    Label("Location", systemImage: "location.circle")
                }
                NavigationLink {
                    HealthDataListView()
                } label: {
                    Label("Health", systemImage: "heart.fill")
                }
            }
            .navigationTitle("Data")
        }
    }
}

#Preview {
    NavigationStack {
        DataRootView()
    }
}
