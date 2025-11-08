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
