# pocket

Termux のホーム画面ショートカットから使う、Go 製の小さな道具箱。
「Go の CLI をそのままスマホのホームに置ける」ことを試すためのデモ。

| ホーム画面 / 共有メニュー | 動き |
|---|---|
| **クリップを解読** | コピー中の JSON / Base64 / URLエンコード / UNIX時刻 / JWT を自動判別して整形し、クリップボードに戻す（Android 10 以降はバックグラウンドからクリップボードを読めないため、ターミナルを開いて表示） |
| **クイックメモ** | ダイアログで一行入力 → 日時つきで `pocket-memo.md` に追記 |
| **メモを見る** | 最近 10 件のメモを表示 |
| **共有 → Termux** | ブラウザで見ているページを `[タイトル](URL)` にしてコピー |
| **okf検索** | 検索語を Gboard で入力 → 結果一覧から選んで読む（q で一覧に戻る） |
| **okf今日に追記** | Gboard で書いた文を、時刻つき箇条書きで今日のデイリーノートに追記（なければ Templates/daily から作成） |
| **okf新規ノート** | タイトル・本文・タグを Gboard で入力してノートを作成 |

okf 系は Termux のターミナルでは日本語入力がつらい問題への対策で、入力はすべて Android 標準のダイアログ（termux-dialog）で行う。
okf 本体は [Mokkori-Tom/okf](https://github.com/Mokkori-Tom/okf) の ja-human ブランチを、このリポジトリのリリースで arm64 向けにビルドして配っている。
バンドルの場所は `~/.config/pocket/env` の `OKF_BUNDLE`（setup.sh が共有ストレージの Obsidian 保管庫を探して書く）。

## セットアップ（Android）

1. F-Droid から **Termux / Termux:Widget / Termux:API** を入れる（入手元はそろえる）
2. Termux で:
   ```sh
   pkg install -y git && git clone https://github.com/Mokkori-Tom/pocket && pocket/setup.sh
   ```
3. ホーム画面を長押し → ウィジェット → Termux:Widget
4. Android 10 以降: 設定 → アプリ → Termux → **他のアプリの上に重ねて表示** を許可（ウィジェットからターミナルを開くのに必要）

更新は `cd pocket && git pull && ./setup.sh`。
リリースが無い場合や `./setup.sh --build` のときは端末上でビルドする（golang パッケージを入れる）。

## CLI として

```sh
pocket decode 1763100000          # → UNIX時刻 / 2025-11-14 15:00:00 JST (Fri)
echo '{"a":1}' | pocket decode    # → JSON を整形
pocket link https://go.dev/       # → [The Go Programming Language](https://go.dev/)
pocket memo 牛乳を買う             # 引数なしで最近のメモを表示
```

メモの保存先は `$POCKET_MEMO` → `~/storage/shared/Documents/pocket-memo.md`（`termux-setup-storage` 済みの場合）→ `~/pocket-memo.md` の順。

## リリース

`v*` タグを push すると GitHub Actions が `pocket-linux-arm64` をビルドしてリリースに添付する。`setup.sh` はまずこれをダウンロードする。
