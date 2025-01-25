import SwiftUI

@main
struct macheliteApp: App {
    // This connects our AppDelegate to the SwiftUI lifecycle
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // We use Settings scene type because it doesn't create a window
        Settings {
            EmptyView()
        }
    }
}
