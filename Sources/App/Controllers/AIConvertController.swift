import Vapor

struct AIConvertController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("ai-convert", use: convert)
    }

    func convert(req: Request) async throws -> Response {
        struct Upload: Content {
            var file: File
        }
        let upload = try req.content.decode(Upload.self)
        let file = upload.file

        let applioURL = URI(string: "http://localhost:8000/convert") // 필요시 실제 Applio 서버 주소로 변경

        let clientResponse = try await req.client.post(applioURL) { clientReq in
            let boundary = "Boundary-\(UUID().uuidString)"
            clientReq.headers.contentType = .init(type: "multipart", subType: "form-data", parameters: ["boundary": boundary])
            var body = ByteBufferAllocator().buffer(capacity: 0)
            body.writeString("--\(boundary)\r\n")
            body.writeString("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.filename)\"\r\n")
            body.writeString("Content-Type: \(file.contentType?.description ?? "application/octet-stream")\r\n\r\n")
            body.writeBytes(file.data.readableBytesView)
            body.writeString("\r\n--\(boundary)--\r\n")
            clientReq.body = .init(buffer: body)
        }

        return Response(
            status: clientResponse.status,
            headers: clientResponse.headers,
            body: .init(buffer: clientResponse.body ?? ByteBuffer())
        )
    }
} 
