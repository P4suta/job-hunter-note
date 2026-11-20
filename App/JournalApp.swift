import SwiftUI

@main
struct JournalApp: App {
  @UIApplicationDelegateAdaptor(NotificationRouter.self) private var router
  @State private var store = JournalStore.onDevice()
  @State private var reminders = LocalReminders()

  var body: some Scene {
    WindowGroup {
      JournalShell(store: store, reminders: reminders, router: router)
        .tint(Color.accentColor)
        .environment(\.locale, Locale(identifier: "ja_JP"))
    }
  }
}
