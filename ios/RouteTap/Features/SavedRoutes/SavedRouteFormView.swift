import SwiftUI

struct SavedRouteFormView: View {
	@ObservedObject var viewModel: SavedRoutesViewModel
	@Environment(\.dismiss) private var dismiss
	@State private var input = SavedRouteInput()
	@FocusState private var focusedField: Field?
	private enum Field: String { case name, origin, destination }

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 26) {
				closeButton
				Text("移動を登録")
					.font(.largeTitle.bold())
					.accessibilityAddTraits(.isHeader)
				inputField(title: "表示名", placeholder: "例：会社への移動", text: $input.name, field: .name)
				inputField(
					title: "出発地", placeholder: "例：大井町駅、東京都品川区", text: $input.origin, field: .origin)
				VStack(alignment: .leading, spacing: 10) {
					inputField(
						title: "目的地", placeholder: "例：浜松町駅、東京都港区", text: $input.destination,
						field: .destination)
					Text("駅名・住所・施設名で登録できます。")
						.font(.caption)
						.foregroundStyle(.secondary)
					Text("同じ名前の場所を区別するため、地域や住所も含めてください。")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				if let error = viewModel.saveError {
					Text(error)
						.font(.subheadline)
						.foregroundStyle(.red)
						.accessibilityIdentifier("routes.saveError")
				}
			}
			.frame(maxWidth: 520)
			.padding(24)
			.frame(maxWidth: .infinity)
		}
		.background(Color(.systemBackground))
		.scrollDismissesKeyboard(.interactively)
		.safeAreaInset(edge: .bottom) { saveButton }
		.interactiveDismissDisabled(viewModel.isSaving)
		.onAppear { viewModel.clearSaveError() }
		.onChange(of: input) { _, _ in viewModel.clearSaveError() }
	}

	private var closeButton: some View {
		Button {
			dismiss()
		} label: {
			Image(systemName: "xmark")
				.font(.title3.weight(.semibold))
				.foregroundStyle(.primary)
				.frame(width: 44, height: 44)
		}
		.disabled(viewModel.isSaving)
		.accessibilityLabel("閉じる")
		.accessibilityIdentifier("routes.close")
	}

	private func inputField(title: String, placeholder: String, text: Binding<String>, field: Field)
		-> some View
	{
		VStack(alignment: .leading, spacing: 10) {
			Text(title).font(.subheadline.weight(.semibold))
			TextField(placeholder, text: text)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
				.focused($focusedField, equals: field)
				.submitLabel(field == .destination ? .done : .next)
				.onSubmit {
					switch field {
					case .name: focusedField = .origin
					case .origin: focusedField = .destination
					case .destination: focusedField = nil
					}
				}
				.padding(16)
				.background(
					RoundedRectangle(cornerRadius: 12)
						.stroke(Color(.systemGray3), lineWidth: 1)
				)
				.disabled(viewModel.isSaving)
				.accessibilityLabel(title)
				.accessibilityIdentifier("routes.\(field.rawValue)")
		}
	}

	private var saveButton: some View {
		Button {
			focusedField = nil
			Task {
				if await viewModel.save(input) { dismiss() }
			}
		} label: {
			HStack(spacing: 10) {
				if viewModel.isSaving { ProgressView().tint(.white) }
				Text("保存").font(.headline)
			}
			.frame(maxWidth: .infinity, minHeight: 56)
		}
		.buttonStyle(.plain)
		.foregroundStyle(.white)
		.background(
			Color.accentColor.opacity(viewModel.isSaving || viewModel.isLoading ? 0.6 : 1),
			in: RoundedRectangle(cornerRadius: 14)
		)
		.disabled(viewModel.isSaving || viewModel.isLoading)
		.accessibilityIdentifier("routes.save")
		.frame(maxWidth: 520)
		.padding(.horizontal, 24)
		.padding(.vertical, 16)
		.frame(maxWidth: .infinity)
		.background(Color(.systemBackground))
	}
}
