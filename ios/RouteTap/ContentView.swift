import SwiftUI

struct ContentView: View {
	@StateObject private var widgetOpener = WidgetRouteOpener()
	@State private var showingWidgetError = false
	@Environment(\.openURL) private var openURL

	var body: some View {
		SavedRoutesView()
			.tint(Color(red: 0.02, green: 0.60, blue: 0.33))
			.onOpenURL { url in
				guard let destination = widgetOpener.destination(for: url) else { return }
				openURL(destination) { accepted in
					if !accepted { widgetOpener.errorMessage = "Google Mapsを開けませんでした。もう一度お試しください。" }
				}
			}
			.onChange(of: widgetOpener.errorMessage) { _, message in
				showingWidgetError = message != nil
			}
			.alert("移動を開けませんでした", isPresented: $showingWidgetError) {
				Button("閉じる", role: .cancel) { widgetOpener.errorMessage = nil }
			} message: {
				Text(widgetOpener.errorMessage ?? "もう一度お試しください。")
			}
	}
}

#Preview { ContentView() }
