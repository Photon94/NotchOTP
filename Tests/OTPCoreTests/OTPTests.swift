import XCTest
@testable import OTPCore

final class OTPTests: XCTestCase {
    // RFC 6238 Appendix B: catches wrong HMAC, truncation, byte order and 32-bit clocks.
    func testRFC6238Vectors() throws {
        let times: [TimeInterval] = [59, 1111111109, 1111111111, 1234567890, 2000000000, 20000000000]
        let vectors: [(String, String, [String])] = [
            ("SHA1", "12345678901234567890", ["94287082", "07081804", "14050471", "89005924", "69279037", "65353130"]),
            ("SHA256", "12345678901234567890123456789012", ["46119246", "68084774", "67062674", "91819424", "90698825", "77737706"]),
            ("SHA512", "1234567890123456789012345678901234567890123456789012345678901234", ["90693936", "25091201", "99943326", "93441116", "38618901", "47863826"])
        ]
        for (algorithm, secret, expected) in vectors {
            for (time, want) in zip(times, expected) {
                XCTAssertEqual(try OTP.code(secret: Data(secret.utf8), algorithm: algorithm, time: time), want)
            }
        }
    }
}
