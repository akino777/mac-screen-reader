# mac-screen-reader

A macOS-native MCP (Model Context Protocol) server that captures your screen and reads all visible text using Apple's Vision Framework OCR.

macOS ネイティブの MCP サーバー。画面をキャプチャし、Apple Vision Framework の OCR でテキストを読み取ります。

## Features / 機能

- Captures the current macOS display as a screenshot (in-memory, no file saved)
- Recognizes all visible text using Apple Vision Framework OCR
- Supports English and Japanese text recognition
- Works as an MCP server via stdio transport (compatible with Claude Code, Claude Desktop, etc.)

---

- macOS ディスプレイのスクリーンショットをメモリ上で取得（ファイル保存なし）
- Apple Vision Framework の OCR で画面上の全テキストを認識
- 英語・日本語のテキスト認識に対応
- stdio トランスポートの MCP サーバーとして動作（Claude Code、Claude Desktop 等に対応）

## Requirements / 必要条件

- macOS 10.15 (Catalina) or later
- Swift 6.2+ (Xcode 16.3+)
- **Screen Recording permission** must be granted to the terminal or app running the server

## Installation / インストール

### Quick Install / 簡単インストール

```bash
git clone https://github.com/<YOUR_USERNAME>/mac-screen-reader.git
cd mac-screen-reader
./install.sh
```

### Manual Build / 手動ビルド

```bash
git clone https://github.com/<YOUR_USERNAME>/mac-screen-reader.git
cd mac-screen-reader
swift build -c release
cp .build/release/MacScreenReader ~/.local/bin/
```

### Download Binary / バイナリダウンロード

Download the latest universal binary from [Releases](https://github.com/<YOUR_USERNAME>/mac-screen-reader/releases).

## Setup / 設定

### Claude Code

```bash
claude mcp add mac-screen-reader ~/.local/bin/MacScreenReader
```

### Claude Desktop

Add the following to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "mac-screen-reader": {
      "command": "/Users/<YOUR_USERNAME>/.local/bin/MacScreenReader"
    }
  }
}
```

### Screen Recording Permission / 画面収録権限

The server requires Screen Recording permission to capture the display.

1. Open **System Settings** → **Privacy & Security** → **Screen Recording**
2. Enable the terminal app you use (e.g., Terminal.app, iTerm2, VS Code, Cursor)
3. Restart the terminal app after granting permission

---

サーバーが画面をキャプチャするには「画面収録」の権限が必要です。

1. **システム設定** → **プライバシーとセキュリティ** → **画面収録** を開く
2. 使用しているターミナルアプリ（Terminal.app、iTerm2、VS Code、Cursor 等）を有効にする
3. 権限を付与した後、ターミナルアプリを再起動する

## Usage / 使い方

Once configured, you can ask Claude to read your screen:

設定後、Claude に画面を読むよう指示できます：

- "Look at my screen and tell me what you see"
- "Read the error message on my screen"
- "画面を見て"
- "画面のエラーを読んで"

## Tool Specification / ツール仕様

### `read_screen_text`

Reads all visible text on the current macOS display using OCR.

| Property | Value |
|----------|-------|
| Name | `read_screen_text` |
| Input | None (no parameters) |
| Output | All recognized text from the screen |

## How It Works / 仕組み

1. **Screen Capture**: Uses `CGWindowListCreateImage` to capture the entire display in memory
2. **OCR Processing**: Passes the image to Apple's `VNRecognizeTextRequest` (Vision Framework)
3. **Text Extraction**: Collects recognized text lines and returns them as a single string
4. **MCP Protocol**: Communicates via JSON-RPC over stdio, following the MCP specification

## License

MIT License. See [LICENSE](LICENSE) for details.
