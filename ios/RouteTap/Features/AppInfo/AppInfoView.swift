import SwiftUI

struct AppInfoView: View {
	@Environment(\.dismiss) private var dismiss

	var body: some View {
		NavigationStack {
			Form {
				Section("保存した移動について") {
					Text("移動はこの端末内に保存されます。編集・削除は、一覧の各移動のメニューから行えます。")
					Text("独自のクラウド同期・バックアップ機能はありません。")
						.foregroundStyle(.secondary)
				}
				Section("サポート・プライバシー") {
					Link(
						"プライバシーポリシー",
						destination: URL(string: "https://rintaronasu.github.io/route-tap/privacy.html")!
					)
					.accessibilityIdentifier("appInfo.privacy")
					Link(
						"サポート・お問い合わせ",
						destination: URL(string: "https://rintaronasu.github.io/route-tap/")!
					)
					.accessibilityIdentifier("appInfo.support")
				}
			}
			.navigationTitle("RouteTapについて")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button("閉じる") { dismiss() }
				}
			}
		}
	}
}
