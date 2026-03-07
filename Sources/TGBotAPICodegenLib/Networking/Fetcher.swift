import Foundation

public enum Fetcher {
    public static func fetchHTML(from urlString: String) throws -> String {
        guard let url = URL(string: urlString) else {
            throw FetchError.invalidURL(urlString)
        }

        var html: String?
        var fetchError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                fetchError = error
                return
            }
            guard let data, let text = String(data: data, encoding: .utf8) else {
                fetchError = FetchError.noData
                return
            }
            html = text
        }
        task.resume()
        semaphore.wait()

        if let error = fetchError { throw error }
        guard let result = html else { throw FetchError.noData }
        return result
    }

    public enum FetchError: Error {
        case invalidURL(String)
        case noData
    }
}
