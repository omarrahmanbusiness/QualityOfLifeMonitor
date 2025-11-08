//
//  Logging.swift
//  QualityOfLifeMonitor
//
//  Created by Omar Rahman on 08/11/2025.
//

import Foundation
import os

// MARK: - Unified Logger
/// Centralized Logger instances for the app using Apple's unified logging system.
///
/// Use these for structured, queryable logs visible in Console.app.
enum AppLog {
    static let subsystem = "com.yourcompany.QualityOfLifeMonitor"
    static let location = Logger(subsystem: subsystem, category: "location")
    static let coredata = Logger(subsystem: subsystem, category: "coredata")
}

// MARK: - Lightweight File Logger
/// Minimal file logger for capturing logs during field testing.
/// Writes to Caches/app.log to avoid iCloud backups. Not for PII.
final class FileLogger {
    static let shared = FileLogger()

    private let url: URL
    private let queue = DispatchQueue(label: "FileLoggerQueue")
    private let dateFormatter: ISO8601DateFormatter

    private init() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        url = dir.appendingPathComponent("app.log")
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    /// Appends a line to the log file asynchronously.
    func log(_ message: String) {
        let line = "[\(dateFormatter.string(from: Date()))] \(message)\n"
        queue.async {
            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: self.url.path) {
                do {
                    let handle = try FileHandle(forWritingTo: self.url)
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } catch {
                    // Avoid recursive logging; it's okay to silently fail here.
                }
            } else {
                do {
                    try data.write(to: self.url)
                } catch {
                    // Ignore errors for file logging in production.
                }
            }
        }
    }

    /// Returns the URL of the current log file.
    func logURL() -> URL { url }

    /// Clears the current log file.
    func clear() {
        queue.async {
            try? FileManager.default.removeItem(at: self.url)
        }
    }
}
