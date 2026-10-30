import CryptoKit
import DeviceCheck
import Foundation
import UIKit
import PlateKit

/// The cloud stage (docs/DATA-AND-SERVICES.md §2–3): the recognised text, or the photo when there's almost none,
/// sent to our read server, which asks Claude and returns the same result as every stage. Only once the user
/// has said yes (CloudConsent), and only from this app (App Attest). Off until the server's address is set
/// (Info.plist `PL8ReadServer`).
enum CloudReader {
    static let seconds = 15.0

    static var server: URL? {
        guard let text = Bundle.main.object(forInfoDictionaryKey: "PL8ReadServer") as? String, !text.isEmpty else { return nil }
        return URL(string: text)
    }

    /// A server to ask, and a phone that can prove it's this app (not the Simulator).
    static var isAvailable: Bool { server != nil && DCAppAttestService.shared.isSupported }

    /// `POST /v1/read`: `{ "kind", "text", "image"?, "locale", "unit" }` → the result, or `{ "error": "unreadable" }`.
    struct Request: Encodable {
        let kind: String
        let text: String
        let image: String?
        let locale: String
        let unit: String
    }

    static func read(_ kind: ReadResult.Kind, text: String, image: UIImage?, unit: WeightUnit) async -> ReadResult? {
        guard let server else { return nil }
        let request = Request(kind: kind.rawValue, text: text, image: image.flatMap(prepared)?.base64EncodedString(),
                              locale: Locale.current.identifier(.bcp47), unit: unit.rawValue)
        guard let body = try? JSONEncoder().encode(request) else { return nil }
        // A key the server no longer knows (a reinstall on its side, a reset) is attested again, once.
        for attempt in 0..<2 {
            guard let headers = try? await AppAttest.headers(for: body, server: server) else { return nil }
            var post = URLRequest(url: server.appending(path: "v1/read"), timeoutInterval: seconds)
            post.httpMethod = "POST"
            post.httpBody = body
            post.setValue("application/json", forHTTPHeaderField: "Content-Type")
            for (name, value) in headers { post.setValue(value, forHTTPHeaderField: name) }
            guard let answer = try? await URLSession.shared.data(for: post),
                  let status = (answer.1 as? HTTPURLResponse)?.statusCode else { return nil }
            if status == 401 && attempt == 0 {
                AppAttest.forget()
                continue
            }
            guard status == 200 else { return nil }
            return try? JSONDecoder().decode(ReadResult.self, from: answer.0)
        }
        return nil
    }

    /// 1600 px on the long edge, JPEG at 0.7. Drawn anew, so no EXIF or location goes with it.
    static func prepared(_ image: UIImage) -> Data? {
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, 1600 / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let redrawn = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return redrawn.jpegData(compressionQuality: 0.7)
    }
}

/// Proves to the read server that a request comes from this app on a real iPhone (Apple's App Attest): a key made
/// on the phone is attested once against the server's challenge, then every request carries an assertion signed
/// with it over the request's body (`X-Attest-Key-Id`, `X-Attest-Assertion`).
enum AppAttest {
    static let keyIDKey = "appAttestKeyID"

    struct Challenge: Decodable { let challenge: String }

    struct Attestation: Encodable {
        let keyId: String
        let attestation: String
        let challenge: String
    }

    static func headers(for body: Data, server: URL) async throws -> [String: String] {
        let keyID = try await attestedKey(server: server)
        let assertion = try await DCAppAttestService.shared.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: body)))
        return ["X-Attest-Key-Id": keyID, "X-Attest-Assertion": assertion.base64EncodedString()]
    }

    /// The phone's key, attested with the server the first time.
    static func attestedKey(server: URL) async throws -> String {
        if let keyID = UserDefaults.standard.string(forKey: keyIDKey) { return keyID }
        let service = DCAppAttestService.shared
        let keyID = try await service.generateKey()
        let (challengeData, _) = try await URLSession.shared.data(for: URLRequest(url: server.appending(path: "v1/challenge"),
                                                                                   timeoutInterval: CloudReader.seconds))
        let challenge = try JSONDecoder().decode(Challenge.self, from: challengeData).challenge
        let attestation = try await service.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: Data(challenge.utf8))))
        var post = URLRequest(url: server.appending(path: "v1/attest"), timeoutInterval: CloudReader.seconds)
        post.httpMethod = "POST"
        post.setValue("application/json", forHTTPHeaderField: "Content-Type")
        post.httpBody = try JSONEncoder().encode(Attestation(keyId: keyID, attestation: attestation.base64EncodedString(), challenge: challenge))
        let (_, response) = try await URLSession.shared.data(for: post)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            throw URLError(.userAuthenticationRequired)
        }
        UserDefaults.standard.set(keyID, forKey: keyIDKey)
        return keyID
    }

    static func forget() { UserDefaults.standard.removeObject(forKey: keyIDKey) }
}

/// The one-time question before anything leaves the phone (App Review 5.1.2; docs §2.2), remembered, and the switch
/// in the iPhone's Settings app (Settings.bundle, the same key). Never asked: no answer yet.
enum CloudConsent {
    static let key = "cloudReading"

    static var answer: Bool? { UserDefaults.standard.object(forKey: key) as? Bool }

    static func allowed(asking ask: () async -> Bool) async -> Bool {
        if let answer { return answer }
        let yes = await ask()
        UserDefaults.standard.set(yes, forKey: key)
        return yes
    }
}
