import AppKit
import CoreGraphics
import Foundation
import Vision

// ==========================================
// Server Metadata
// ==========================================

let serverName = "mac-screen-reader"
let serverVersion = "1.0.0"

// ==========================================
// 1. JSON-RPC / MCP プロトコル定義
// ==========================================

struct JSONRPCRequest: Decodable {
    let jsonrpc: String
    let method: String
    let params: AnyCodable?
    let id: AnyCodable?  // IDはIntかStringの可能性があるため
}

struct JSONRPCResponse: Encodable {
    let jsonrpc: String = "2.0"
    let result: AnyCodable?
    let error: AnyCodable?
    let id: AnyCodable?
}

// 汎用的にJSONを扱うためのラッパー
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int.self) {
            value = x
        } else if let x = try? container.decode(Double.self) {
            value = x
        } else if let x = try? container.decode(String.self) {
            value = x
        } else if let x = try? container.decode(Bool.self) {
            value = x
        } else if let x = try? container.decode([String: AnyCodable].self) {
            value = x.mapValues { $0.value }
        } else if let x = try? container.decode([AnyCodable].self) {
            value = x.map { $0.value }
        } else {
            value = ""
        }  // Fallback
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let x = value as? Int {
            try container.encode(x)
        } else if let x = value as? Double {
            try container.encode(x)
        } else if let x = value as? String {
            try container.encode(x)
        } else if let x = value as? Bool {
            try container.encode(x)
        } else if let x = value as? [String: Any] {
            try container.encode(x.mapValues { AnyCodable($0) })
        } else if let x = value as? [Any] {
            try container.encode(x.map { AnyCodable($0) })
        } else {
            try container.encode("null")
        }
    }
}

// ==========================================
// 2. macOS Native OCR Logic (Vision Framework)
// ==========================================

func performScreenOCR() -> String {
    // スクリーンショットをメモリ上で取得 (CoreGraphics)
    // kCGWindowListOptionOnScreenOnly: 画面上のウィンドウのみ
    guard
        let cgImage = CGWindowListCreateImage(
            CGRect.infinite,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        )
    else {
        return "Error: Failed to capture screen. Screen Recording permission may not be granted. / エラー: 画面のキャプチャに失敗しました。「画面収録」の権限がない可能性があります。"
    }

    var recognizedText = ""
    let semaphore = DispatchSemaphore(value: 0)

    // 文字認識リクエストの作成
    let request = VNRecognizeTextRequest { (request, error) in
        defer { semaphore.signal() }

        guard let observations = request.results as? [VNRecognizedTextObservation], error == nil
        else {
            recognizedText = "Error: Text recognition failed. / エラー: 文字認識に失敗しました。"
            return
        }

        // 認識されたテキスト行を結合
        let text = observations.compactMap { observation in
            // topCandidates(1)で最も確度の高い候補を取得
            return observation.topCandidates(1).first?.string
        }.joined(separator: "\n")

        recognizedText = text
    }

    // 設定: 正確さ優先、言語自動検出(英語・日本語含む)
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    // 画像処理を実行
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
    } catch {
        return "Error: Failed to start OCR engine. Please check Screen Recording permissions. / エラー: OCRエンジンの起動に失敗しました。「画面収録」権限を確認してください。"
    }

    semaphore.wait()  // 処理完了を待つ
    return recognizedText.isEmpty ? "(No text found on screen / 画面上に文字が見つかりませんでした)" : recognizedText
}

// ==========================================
// 3. メインループ (MCP Server)
// ==========================================

// ログ出力用（stderrに出すことでMCPの通信(stdout)を邪魔しない）
func log(_ message: String) {
    fputs("[SwiftMCP] \(message)\n", stderr)
}

func send(response: JSONRPCResponse) {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(response),
        let str = String(data: data, encoding: .utf8)
    {
        print(str)
        fflush(stdout)  // 必須: これがないとClaudeが応答を待ち続ける
    }
}

while let line = readLine() {
    guard let data = line.data(using: .utf8) else { continue }

    do {
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        // --- メソッド分岐 ---
        switch request.method {

        case "initialize":
            let capabilities: [String: Any] = [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": serverName, "version": serverVersion],
            ]
            send(
                response: JSONRPCResponse(
                    result: AnyCodable(capabilities), error: nil, id: request.id))

        case "notifications/initialized":
            log("Client initialized.")

        case "ping":
            send(
                response: JSONRPCResponse(
                    result: AnyCodable([String: Any]()), error: nil, id: request.id))

        case "tools/list":
            let tools: [String: Any] = [
                "tools": [
                    [
                        "name": "read_screen_text",
                        "description":
                            "Reads all visible text on the current macOS display using OCR. Use when the user says 'look at my screen', 'read this error', etc. / 現在のディスプレイに表示されている全テキストをOCRで読み取ります。",
                        "inputSchema": [
                            "type": "object",
                            "properties": [String: Any](),  // 引数なし
                        ],
                    ]
                ]
            ]
            send(response: JSONRPCResponse(result: AnyCodable(tools), error: nil, id: request.id))

        case "tools/call":
            guard let params = request.params?.value as? [String: Any],
                let name = params["name"] as? String
            else {
                continue
            }

            if name == "read_screen_text" {
                log("Executing OCR...")
                let text = performScreenOCR()

                // 結果が長すぎる場合のトリミング（念のため）
                let finalText = text.count > 10000 ? String(text.prefix(10000)) + "...(truncated / 省略)" : text

                let content: [String: Any] = [
                    "content": [
                        [
                            "type": "text",
                            "text": "OCR result from current screen / 現在の画面から読み取ったテキスト:\n\n---\n\(finalText)\n---",
                        ]
                    ]
                ]
                send(
                    response: JSONRPCResponse(
                        result: AnyCodable(content), error: nil, id: request.id))
            } else {
                // エラーレスポンス
                let error: [String: Any] = ["code": -32601, "message": "Method not found"]
                send(
                    response: JSONRPCResponse(result: nil, error: AnyCodable(error), id: request.id)
                )
            }

        default:
            if request.id != nil {
                // Request with id: return Method not found error
                let error: [String: Any] = ["code": -32601, "message": "Method not found: \(request.method)"]
                send(
                    response: JSONRPCResponse(result: nil, error: AnyCodable(error), id: request.id)
                )
            }
            // Notifications (no id): silently ignore
        }

    } catch {
        log("JSON Parse Error: Invalid request format")
    }
}
