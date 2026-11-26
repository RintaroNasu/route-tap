# RouteTap（ルートタップ）

## アプリ概要

**よく使う出発地と目的地を保存し、Google Mapsの経路検索をすぐに開けるアプリです。**

通勤やお出かけのたびに同じ場所を入力する手間を減らします。ホーム画面のウィジェットからも、保存した移動の往路・復路を開けます。

ユーザー登録は不要で、移動データは端末内に保存します。

### 機能概要

1. **移動の登録・一覧表示**：表示名・出発地・目的地を登録し、よく使う移動をまとめて管理します。
2. **移動の編集・削除**：登録した移動を変更・削除できます。
3. **往路・復路の切り替え**：出発地と目的地を入れ替えて検索できます。
4. **Google Maps連携**：保存した場所を使って、公共交通機関の経路検索を開きます。
5. **ウィジェット**：表示する移動を選び、ホーム画面から往路・復路を開けます。
6. **ウィジェット追加ガイド**：操作画面の画像を使って、追加方法と移動の選び方を案内します。

※このREADMEはリポジトリ内の実装を記載しています。公開版と更新前の機能に差がある場合があります。

---

## デモ画像

<!-- 各セルに <img width="300" alt="画面の説明" src="画像URL" /> を追加してください。 -->

<table>
  <tr>
    <th>移動一覧</th>
    <th>移動の登録</th>
  </tr>
  <tr>
    <td>スクリーンショットを追加予定</td>
    <td>スクリーンショットを追加予定</td>
  </tr>
  <tr>
    <th>移動の編集</th>
    <th>往路・復路の切り替え</th>
  </tr>
  <tr>
    <td>スクリーンショットを追加予定</td>
    <td>スクリーンショットを追加予定</td>
  </tr>
  <tr>
    <th>ホーム画面のウィジェット</th>
    <th>ウィジェット追加ガイド</th>
  </tr>
  <tr>
    <td>スクリーンショットを追加予定</td>
    <td>スクリーンショットを追加予定</td>
  </tr>
</table>

---

## 技術スタック

### 使用言語・フレームワーク

| 技術 | 用途 |
| --- | --- |
| [Swift](https://www.swift.org/documentation/) | アプリ・ウィジェットの実装 |
| [SwiftUI](https://developer.apple.com/documentation/swiftui/) | 画面の構築 |
| [Combine](https://developer.apple.com/documentation/combine/) | ViewModelの状態変更を画面へ反映 |
| [Foundation](https://developer.apple.com/documentation/foundation/) | JSONの読み書き・ファイル操作・URLの生成 |
| [WidgetKit](https://developer.apple.com/documentation/widgetkit/) | ホーム画面ウィジェット |
| [App Intents](https://developer.apple.com/documentation/appintents/) | ウィジェットに表示する移動の選択 |
| [App Groups](https://developer.apple.com/documentation/xcode/configuring-app-groups) | アプリとウィジェットのデータ共有 |

### アーキテクチャ概要

画面を担当するViewと、入力の検証・一覧の更新を担当するViewModelに分けています。ファイルの読み書きはStoreにまとめています。

```text
アプリの画面（SwiftUI）
  ↓ 操作
SavedRoutesViewModel
  ↓ 読み込み・保存
SavedRouteStore
  ↓
App Groupsの共有領域
  └─ JSONファイル ← ウィジェットも読み込む

アプリ・ウィジェットで移動を選択
  ↓
Google Mapsの経路検索を開く
```

- **移動データ**：共有領域のJSONファイルに保存します。保存に失敗した場合はエラーを表示します。
- **案内の表示設定**：ウィジェットの初回案内を表示したかどうかを、`@AppStorage`（UserDefaults）で保存します。
- **Google Maps連携**：ユーザーの操作時に出発地・目的地をURLで渡します。ウィジェットからは、一度RouteTapを経由して開きます。

現在の構成はiOSアプリ内で完結しており、独自のAPI・サーバーDB・クラウド同期は使用していません。

詳細な機能要件は [docs/mvp.md](docs/mvp.md) を参照してください。

---

## 公開先

- [App Store](https://apps.apple.com/jp/app/id6836431900)
- [サポートページ](https://rintaronasu.github.io/route-tap/)
- [プライバシーポリシー](https://rintaronasu.github.io/route-tap/privacy.html)

---

## 開発環境のセットアップ手順

### 前提環境

- Mac・Xcode
- iOS / iPadOS 18.5以降の実機、または対応するSimulator
- 実機で動かす場合は、Appleアカウントと署名・App Groupsの設定

### 1. リポジトリをクローンする

```bash
git clone https://github.com/RintaroNasu/route-tap.git
cd route-tap
```

### 2. Xcodeでプロジェクトを開く

```bash
open ios/RouteTap.xcodeproj
```

### 3. アプリを起動する

1. Xcode上部のスキームで `RouteTap` を選択する。
2. 実行先にiPhoneまたはiPadのSimulatorを選択する。
3. `Command + R` で起動する。

APIキー・環境変数・DBの起動は不要です。

実機で動かす場合は、`RouteTap` と `RouteTapWidgets` の両ターゲットで同じTeamを選び、同じApp Groupを設定してください。別の開発者アカウントで動かす場合は、自分のBundle Identifier・App Groupに変更し、`SavedRouteStore.swift` 内の共有先IDとentitlementsの値も一致させてください。

---

## テスト

Xcodeで `Command + U` を押すか、リポジトリのルートで以下を実行します。

```bash
xcodebuild test \
  -project ios/RouteTap.xcodeproj \
  -scheme RouteTap \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY=-
```

`iPhone 16` は、インストール済みのSimulator名に置き換えられます。

### 主な確認内容

- 登録・更新・削除と、アプリ再起動後のデータ保持
- 保存失敗時に一覧を変更せず、再試行できること
- 指定した移動だけが更新・削除されること
- 壊れたJSONファイルを上書きしないこと
- Google MapsのURL生成・文字数制限・往復切り替え
- ウィジェットのリンク処理と、追加ガイドの表示

単体テストは [ios/RouteTapTests](ios/RouteTapTests)、UIテストは [ios/RouteTapUITests](ios/RouteTapUITests) に配置しています。

PR作成時と `main` / `develop` へのpush時に、[GitHub Actions](.github/workflows/ci.yml) でビルド・テストを実行します。App Storeへの配布は手動で行います。
