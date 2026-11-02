import SwiftUI

struct AuthView: View {
	@ObservedObject var model: AuthModel
	@State private var mode: AuthMode = .login
	@State private var email = ""
	@State private var password = ""
	@State private var passwordVisible = false
	@FocusState private var focusedField: Field?
	private enum Field { case email, password }
	private let green = Color(red: 0.02, green: 0.60, blue: 0.33)

	var body: some View {
		GeometryReader { geometry in
			ScrollView {
				VStack(alignment: .leading, spacing: 0) {
					VStack(spacing: 12) {
						Image(systemName: "tram")
							.font(.system(size: 46, weight: .regular))
							.foregroundStyle(green)
							.accessibilityHidden(true)
						Text("RouteTap")
							.font(
								.system(
									size: 34, weight: .bold,
									design: .rounded))
						Text("いつもの移動を、\nワンタップで。")
							.font(.body)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
					}
					.frame(maxWidth: .infinity)
					.padding(.top, 32)
					.padding(.bottom, 36)

					Text(mode.title)
						.font(.largeTitle.bold())
						.accessibilityAddTraits(.isHeader)
						.accessibilityIdentifier("auth.heading")
						.padding(.bottom, 28)

					VStack(alignment: .leading, spacing: 20) {
						VStack(alignment: .leading, spacing: 9) {
							Text("メールアドレス").font(
								.subheadline.weight(.semibold))
							TextField("name@example.com", text: $email)
								.keyboardType(.emailAddress)
								.textContentType(.username)
								.textInputAutocapitalization(.never)
								.autocorrectionDisabled()
								.submitLabel(.next)
								.focused(
									$focusedField,
									equals: .email
								)
								.onSubmit {
									focusedField = .password
								}
								.accessibilityLabel("メールアドレス")
								.accessibilityIdentifier(
									"auth.email"
								)
								.padding(16)
								.background(fieldBackground)
						}
						VStack(alignment: .leading, spacing: 9) {
							Text("パスワード").font(
								.subheadline.weight(.semibold))
							HStack(spacing: 8) {
								Group {
									if passwordVisible {
										TextField(
											"パスワード",
											text:
												$password
										)
									} else {
										SecureField(
											"パスワード",
											text:
												$password
										)
									}
								}
								.textContentType(
									mode == .signup
										? .newPassword
										: .password
								)
								.textInputAutocapitalization(.never)
								.autocorrectionDisabled()
								.focused(
									$focusedField,
									equals: .password
								)
								.submitLabel(.go)
								.onSubmit { submit() }
								.accessibilityLabel("パスワード")
								.accessibilityIdentifier(
									"auth.password")
								Button {
									passwordVisible.toggle()
								} label: {
									Image(
										systemName:
											passwordVisible
											? "eye.slash"
											: "eye"
									)
									.foregroundStyle(.secondary)
									.frame(
										width: 44,
										height: 44)
								}
								.accessibilityLabel(
									passwordVisible
										? "パスワードを隠す"
										: "パスワードを表示")
							}
							.padding(.leading, 16)
							.padding(.trailing, 4)
							.padding(.vertical, 5)
							.background(fieldBackground)
						}
					}
					.disabled(model.isBusy)

					if let error = model.errorMessage {
						Text(error)
							.font(.subheadline)
							.foregroundStyle(.red)
							.accessibilityIdentifier("auth.error")
							.padding(.top, 16)
					}

					Button(action: submit) {
						HStack(spacing: 10) {
							if model.isBusy {
								ProgressView().tint(.white)
							}
							Text(mode.buttonTitle).fontWeight(.semibold)
						}
						.frame(maxWidth: .infinity, minHeight: 54)
					}
					.buttonStyle(.plain)
					.foregroundStyle(.white)
					.background(
						green.opacity(model.isBusy ? 0.65 : 1),
						in: RoundedRectangle(cornerRadius: 12)
					)
					.disabled(model.isBusy)
					.accessibilityIdentifier("auth.submit")
					.padding(.top, 24)

					Spacer(minLength: 40)
					Divider().padding(.bottom, 20)
					VStack(spacing: 8) {
						Text(
							mode == .login
								? "アカウントをお持ちでない方" : "すでにアカウントをお持ちの方"
						)
						.font(.subheadline)
						.foregroundStyle(.secondary)
						Button(mode == .login ? "新規登録" : "ログイン") {
							mode = mode == .login ? .signup : .login
							password = ""
							passwordVisible = false
							focusedField = nil
							model.clearError()
						}
						.font(.subheadline.weight(.semibold))
						.tint(green)
						.frame(minHeight: 44)
						.disabled(model.isBusy)
						.accessibilityIdentifier("auth.switch")
					}
					.frame(maxWidth: .infinity)
					.padding(.bottom, 20)
				}
				.frame(maxWidth: 440)
				.padding(.horizontal, 28)
				.frame(maxWidth: .infinity, minHeight: geometry.size.height)
			}
			.scrollDismissesKeyboard(.interactively)
		}
		.background(Color(.systemBackground))
	}

	private var fieldBackground: some View {
		RoundedRectangle(cornerRadius: 12)
			.fill(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: 12).stroke(
					Color(.systemGray3), lineWidth: 1))
	}

	private func submit() {
		guard !model.isBusy else { return }
		focusedField = nil
		Task { await model.submit(email: email, password: password, mode: mode) }
	}
}
