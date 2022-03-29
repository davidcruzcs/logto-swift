import Logto
@testable import LogtoClient
import LogtoMock
import XCTest

class LogtoAuthSessionSuccessMock: LogtoAuthSession {
    override func start() {
        completion(.success(response: try! JSONDecoder().decode(LogtoCore.CodeTokenResponse.self, from: Data("""
        {
            "accessToken": "foo",
            "refreshToken": "bar",
            "idToken": "baz",
            "scope": "openid offline_access",
            "expiresIn": 300
        }
        """.utf8))))
    }
}

class LogtoAuthSessionFailureMock: LogtoAuthSession {
    override func start() {
        completion(.failure(error: LogtoAuthSession.Errors.SignIn(type: .unknownError, innerError: nil)))
    }
}

extension LogtoClientTests {
    func testSignInOk() async throws {
        let client = buildClient()
        let error = try await client.signInWithBrowser(
            authSessionType: LogtoAuthSessionSuccessMock.self,
            redirectUri: "io.logto.dev://callback"
        )

        XCTAssertNil(error)
        XCTAssertEqual(client.idToken, "baz")
        XCTAssertEqual(client.refreshToken, "bar")
        XCTAssertEqual(client.accessTokenMap[client.buildAccessTokenKey(for: nil, scopes: [])]?.token, "foo")
    }

    func testSignInUnableToConstructRedirectUri() async throws {
        let client = buildClient()
        let error = try await client.signInWithBrowser(redirectUri: "")

        XCTAssertEqual(error?.type, .unableToConstructRedirectUri)
    }

    func testSignInUnableToFetchOidcConfig() async throws {
        let client = buildClient(withOidcEndpoint: "/bad")

        do {
            _ = try await client.signInWithBrowser(redirectUri: "io.logto.dev://callback")
        } catch let error as LogtoClient.Errors.OidcConfig {
            XCTAssertEqual(error.type, .unableToFetchOidcConfig)
            return
        }

        XCTFail()
    }

    func testSignInUnknownError() async throws {
        let client = buildClient()
        let error = try await client.signInWithBrowser(
            authSessionType: LogtoAuthSessionFailureMock.self,
            redirectUri: "io.logto.dev://callback"
        )

        XCTAssertEqual(error?.type, .unknownError)
    }
}