import SwiftUI
import GoogleSignIn

@main
struct ezReaderApp: App {
    
    init() {
        NSLog("🚀🚀🚀 [ezReader] 앱 초기화 시작")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
