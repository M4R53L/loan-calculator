import Foundation

/// The latest consumer price index from the Central Bureau of Statistics:
/// how much prices rose over the 12 months to a given month.
struct CPIReading: Codable, Equatable, Sendable {
    /// Change over the last 12 months, in percent
    let yearly: Double
    let year: Int
    let month: Int

    /// The rate as the inflation field shows it: "1.6", "-0.3"
    var text: String { String(format: "%g", yearly) }

    /// "9/2026"
    var period: String { "\(month)/\(year)" }
}

/// The Central Bureau of Statistics' public price index API. It is free and
/// needs no key. A new index comes out around the 15th of each month.
enum CBS {
    /// 120010 is the general consumer price index
    static let latestURL = URL(string:
        "https://api.cbs.gov.il/index/data/price?id=120010&format=json&download=false&last=1")!

    static func latest(session: URLSession = .shared) async throws -> CPIReading {
        var request = URLRequest(url: latestURL, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try parse(data)
    }

    /// Reads the newest month out of the API's answer
    static func parse(_ data: Data) throws -> CPIReading {
        struct Answer: Decodable {
            struct Series: Decodable { let date: [Month] }
            struct Month: Decodable {
                let year: Int
                let month: Int
                let percentYear: Double
            }
            let month: [Series]
        }
        let months = try JSONDecoder().decode(Answer.self, from: data).month.flatMap(\.date)
        guard let newest = months.max(by: { ($0.year, $0.month) < ($1.year, $1.month) }) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "No months"))
        }
        return CPIReading(yearly: newest.percentYear, year: newest.year, month: newest.month)
    }
}
