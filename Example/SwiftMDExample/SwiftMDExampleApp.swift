import SwiftUI

@main
struct HairballExampleApp: App {
    var body: some Scene {
        WindowGroup {
            StreamingChatDemoView()
                .preferredColorScheme(.dark)
        }
    }
}
