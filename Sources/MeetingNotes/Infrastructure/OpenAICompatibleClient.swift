import Foundation

/// 连接测试结果（需求 15.4）。
///
/// 用于设置界面展示某项服务的连接测试结论。`message` 为面向用户的中文文案（需求 1.1）；
/// 其中如需引用用户填写的接口地址或模型名，按原始内容原样回显，不做改写（需求 1.2）。
enum ConnectionResult: Equatable {
    /// 连接成功，携带中文提示文案。
    case success(message: String)
    /// 连接失败，携带中文失败原因文案。
    case failure(message: String)

    /// 是否连接成功。
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    /// 面向用户的中文文案（无论成功或失败均可读取）。
    var message: String {
        switch self {
        case let .success(message): return message
        case let .failure(message): return message
        }
    }
}

/// OpenAI 兼容客户端在请求过程中可能抛出的错误（需求 15.4）。
enum OpenAIClientError: Error, Equatable {
    /// 由 baseURL 与 path 拼接出的地址非法（无法构造 URL）。
    case invalidURL(base: String, path: String)
    /// 服务返回非 2xx 状态码，附带状态码与响应体文本（已截断）。
    case httpStatus(code: Int, body: String)
    /// 收到的响应不是 HTTP 响应。
    case nonHTTPResponse
}

/// OpenAI 兼容 HTTP 客户端抽象（基础设施层，对应设计「OpenAI 兼容客户端」）。
///
/// 转写服务（任务 8.2）与总结服务（任务 9.1）共用：
/// - `postJSON` 向指定 path POST 一段 JSON，鉴权用 `ServiceConfig.apiKey` 走 Bearer。
/// - `postMultipart` 向指定 path POST multipart/form-data（音频转写接口需要文件字段）。
/// - `testConnection` 探测某项服务连通性，返回中文 `ConnectionResult`（需求 15.4）。
///
/// - Important: `baseURL` 按用户输入原样使用（需求 1.2）。客户端仅在 base 与 path 之间做
///   标准的「补一个斜杠」拼接，不改写用户填写的协议、主机、路径前缀（如 `/v1`）。
protocol OpenAICompatibleClienting {
    /// 向 `path` POST 一段 JSON 请求体，返回原始响应数据（由调用方解析）。
    /// - Parameters:
    ///   - path: 相对 `config.baseURL` 的端点路径，如 `chat/completions`。
    ///   - body: 已序列化的 JSON 请求体。
    ///   - config: 目标服务配置（提供 baseURL 与 apiKey）。
    func postJSON(path: String, body: Data, config: ServiceConfig) async throws -> Data

    /// 向 `path` POST 一段 multipart/form-data 请求体（用于音频转写）。
    /// - Parameters:
    ///   - path: 相对 `config.baseURL` 的端点路径，如 `audio/transcriptions`。
    ///   - parts: multipart 各字段（文本字段或文件字段）。
    ///   - config: 目标服务配置（提供 baseURL 与 apiKey）。
    func postMultipart(path: String, parts: [MultipartPart], config: ServiceConfig) async throws -> Data

    /// 探测连接：成功/失败均返回中文文案结果（需求 15.4、1.1、1.2）。
    func testConnection(_ config: ServiceConfig) async -> ConnectionResult
}

/// multipart/form-data 的单个字段。
enum MultipartPart {
    /// 普通文本字段：字段名 + 文本值。
    case text(name: String, value: String)
    /// 文件字段：字段名 + 文件名 + MIME 类型 + 二进制内容。
    case file(name: String, filename: String, mimeType: String, data: Data)
}

/// 基于 `URLSession` 的 OpenAI 兼容客户端实现，不引入第三方网络依赖（对应设计技术选型）。
final class OpenAICompatibleClient: OpenAICompatibleClienting {
    private let session: URLSession
    /// 连接测试的超时时间（秒），避免无效地址长时间挂起。
    private let testTimeout: TimeInterval

    /// - Parameters:
    ///   - session: 注入的 URLSession，默认 `.shared`（便于测试替换）。
    ///   - testTimeout: 连接测试超时秒数，默认 15 秒。
    init(session: URLSession = .shared, testTimeout: TimeInterval = 15) {
        self.session = session
        self.testTimeout = testTimeout
    }

    func postJSON(path: String, body: Data, config: ServiceConfig) async throws -> Data {
        let url = try Self.endpointURL(base: config.baseURL, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
        return data
    }

    func postMultipart(path: String, parts: [MultipartPart], config: ServiceConfig) async throws -> Data {
        let url = try Self.endpointURL(base: config.baseURL, path: path)
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = Self.encodeMultipart(parts: parts, boundary: boundary)

        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
        return data
    }

    func testConnection(_ config: ServiceConfig) async -> ConnectionResult {
        // 用最小代价的 chat/completions 请求探测：包含用户填写的模型名（需求 1.2 原样使用）。
        let probeBody: [String: Any] = [
            "model": config.model,
            "messages": [["role": "user", "content": "ping"]],
            "max_tokens": 1
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: probeBody) else {
            return .failure(message: "无法构造测试请求，请检查模型名「\(config.model)」是否填写正确。")
        }

        do {
            let url = try Self.endpointURL(base: config.baseURL, path: "chat/completions")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = testTimeout
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = body

            let (data, response) = try await session.data(for: request)
            try Self.validate(response: response, data: data)
            // 能正常返回 2xx 即视为连通（模型可用、鉴权通过）。
            return .success(message: "连接成功，模型「\(config.model)」可用。")
        } catch let OpenAIClientError.invalidURL(base, _) {
            return .failure(message: "接口地址「\(base)」无效，请检查后重试。")
        } catch let OpenAIClientError.httpStatus(code, _) {
            return .failure(message: Self.failureMessage(forStatus: code, config: config))
        } catch OpenAIClientError.nonHTTPResponse {
            return .failure(message: "连接失败：未收到有效的 HTTP 响应，请检查接口地址「\(config.baseURL)」。")
        } catch {
            return .failure(message: "连接失败：\(error.localizedDescription)，请检查接口地址「\(config.baseURL)」与网络。")
        }
    }
}

// MARK: - 内部工具

extension OpenAICompatibleClient {
    /// 由用户填写的 `base` 与端点 `path` 拼接出请求 URL。
    ///
    /// 严格遵循需求 1.2「按用户输入原样使用」：不替换协议、不补 `/v1`、不裁剪用户路径，
    /// 仅在 base 末尾与 path 之间规范化斜杠，避免出现 `//` 或缺斜杠。
    static func endpointURL(base: String, path: String) throws -> URL {
        let trimmedBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBase = trimmedBase.hasSuffix("/")
            ? String(trimmedBase.dropLast())
            : trimmedBase
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let joined = normalizedPath.isEmpty ? normalizedBase : "\(normalizedBase)/\(normalizedPath)"
        guard let url = URL(string: joined), url.scheme != nil, url.host != nil else {
            throw OpenAIClientError.invalidURL(base: base, path: path)
        }
        return url
    }

    /// 校验响应为 HTTP 2xx，否则抛出带状态码与截断响应体的错误。
    static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIClientError.nonHTTPResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data.prefix(2048), encoding: .utf8) ?? ""
            throw OpenAIClientError.httpStatus(code: http.statusCode, body: bodyText)
        }
    }

    /// 将各 multipart 字段编码为请求体数据。
    static func encodeMultipart(parts: [MultipartPart], boundary: String) -> Data {
        var body = Data()
        let lineBreak = "\r\n"
        func append(_ string: String) {
            if let data = string.data(using: .utf8) { body.append(data) }
        }

        for part in parts {
            append("--\(boundary)\(lineBreak)")
            switch part {
            case let .text(name, value):
                append("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)")
                append("\(value)\(lineBreak)")
            case let .file(name, filename, mimeType, data):
                append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\(lineBreak)")
                append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)")
                body.append(data)
                append(lineBreak)
            }
        }
        append("--\(boundary)--\(lineBreak)")
        return body
    }

    /// 把 HTTP 状态码翻译为面向用户的中文失败文案（需求 1.1、15.4）。
    static func failureMessage(forStatus code: Int, config: ServiceConfig) -> String {
        switch code {
        case 401, 403:
            return "连接失败：密钥校验未通过（HTTP \(code)），请检查密钥是否正确。"
        case 404:
            return "连接失败：接口地址「\(config.baseURL)」未找到对应端点（HTTP 404），请检查地址。"
        case 400, 422:
            return "连接失败：模型「\(config.model)」可能不被支持（HTTP \(code)），请检查模型名。"
        case 429:
            return "连接失败：请求过于频繁（HTTP 429），请稍后重试。"
        case 500...599:
            return "连接失败：服务端异常（HTTP \(code)），请稍后重试。"
        default:
            return "连接失败：服务返回 HTTP \(code)，请检查接口地址「\(config.baseURL)」与模型「\(config.model)」。"
        }
    }
}
