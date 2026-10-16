import Foundation
import AppKit
import SQLite3
import CryptoKit

let sqlTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum ClipKind: String { case text, image }
enum ClipOrder { case recent, frequent }
struct ClipRecord: Identifiable {
    let id: String
    let kind: ClipKind
    let text: String
    let thumbnail: Data?
    let byteCount: Int
    let firstAt: Date
    let lastAt: Date
    let count: Int
}
struct ClipPayload {
    let kind: ClipKind
    let text: String
    let data: Data
    let thumbnail: Data?
    var id: String { SHA256.hash(data: Data(kind.rawValue.utf8) + data).map { String(format: "%02x", $0) }.joined() }
    static func text(_ value: String) -> ClipPayload { ClipPayload(kind: .text, text: value, data: Data(value.utf8), thumbnail: nil) }
    static func image(_ image: NSImage) -> ClipPayload? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) else { return nil }
        let thumb = NSImage(size: NSSize(width: 240, height: 150))
        thumb.lockFocus()
        NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: 240, height: 150).fill()
        let scale = min(240 / image.size.width, 150 / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: NSRect(x: (240-size.width)/2, y: (150-size.height)/2, width: size.width, height: size.height))
        thumb.unlockFocus()
        let thumbnail = thumb.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))?.representation(using: .png, properties: [:])
        return ClipPayload(kind: .image, text: "图片 · \(rep.pixelsWide) × \(rep.pixelsHigh)", data: png, thumbnail: thumbnail)
    }
}

final class HistoryStore {
    private var db: OpaquePointer?
    let url: URL
    init(url: URL) throws {
        self.url = url
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw failure() }
        sqlite3_busy_timeout(db, 3000)
        do {
            try exec("PRAGMA journal_mode=WAL; PRAGMA synchronous=FULL; PRAGMA secure_delete=ON;")
            try exec("CREATE TABLE IF NOT EXISTS clips (id TEXT PRIMARY KEY, kind TEXT NOT NULL, text TEXT NOT NULL, payload BLOB NOT NULL, thumbnail BLOB, bytes INTEGER NOT NULL, first_at REAL NOT NULL, last_at REAL NOT NULL, copies INTEGER NOT NULL CHECK(copies>0)); CREATE INDEX IF NOT EXISTS clips_recent ON clips(last_at DESC); CREATE INDEX IF NOT EXISTS clips_frequent ON clips(copies DESC,last_at DESC); PRAGMA user_version=1;")
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch { sqlite3_close(db); db = nil; throw error }
    }
    deinit { sqlite3_close(db) }
    private func failure() -> NSError { NSError(domain: "ClipGarden.Database", code: Int(sqlite3_errcode(db)), userInfo: [NSLocalizedDescriptionKey: db.map { String(cString: sqlite3_errmsg($0)) } ?? "无法打开本地数据库"]) }
    private func exec(_ sql: String) throws { guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw failure() } }
    private func statement(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else { throw failure() }; return stmt
    }
    private func bind(_ value: String, _ stmt: OpaquePointer, _ index: Int32) { sqlite3_bind_text(stmt, index, value, Int32(value.utf8.count), sqlTransient) }
    private func bind(_ value: Data?, _ stmt: OpaquePointer, _ index: Int32) {
        guard let value else { sqlite3_bind_null(stmt, index); return }
        _ = value.withUnsafeBytes { sqlite3_bind_blob(stmt, index, $0.baseAddress, Int32(value.count), sqlTransient) }
    }
    private func string(_ stmt: OpaquePointer, _ index: Int32) -> String { sqlite3_column_text(stmt, index).map { String(decoding: UnsafeBufferPointer(start: $0, count: Int(sqlite3_column_bytes(stmt, index))), as: UTF8.self) } ?? "" }
    private func data(_ stmt: OpaquePointer, _ index: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(stmt, index) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(stmt, index)))
    }
    func ingest(_ value: ClipPayload, at date: Date = Date()) throws {
        let stmt = try statement("INSERT INTO clips(id,kind,text,payload,thumbnail,bytes,first_at,last_at,copies) VALUES(?,?,?,?,?,?,?,?,1) ON CONFLICT(id) DO UPDATE SET last_at=excluded.last_at,copies=clips.copies+1")
        defer { sqlite3_finalize(stmt) }
        bind(value.id, stmt, 1); bind(value.kind.rawValue, stmt, 2); bind(value.text, stmt, 3); bind(value.data, stmt, 4); bind(value.thumbnail, stmt, 5)
        sqlite3_bind_int64(stmt, 6, Int64(value.data.count)); sqlite3_bind_double(stmt, 7, date.timeIntervalSince1970); sqlite3_bind_double(stmt, 8, date.timeIntervalSince1970)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw failure() }
    }
    func fetch(order: ClipOrder, search: String = "", limit: Int = 60, offset: Int = 0) throws -> [ClipRecord] {
        let sort = order == .recent ? "last_at DESC,id ASC" : "copies DESC,last_at DESC,id ASC"
        let stmt = try statement("SELECT id,kind,text,thumbnail,bytes,first_at,last_at,copies FROM clips WHERE instr(lower(text),lower(?))>0 ORDER BY \(sort) LIMIT ? OFFSET ?")
        defer { sqlite3_finalize(stmt) }
        bind(search, stmt, 1); sqlite3_bind_int(stmt, 2, Int32(limit)); sqlite3_bind_int(stmt, 3, Int32(offset))
        var result: [ClipRecord] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_DONE { return result }
            guard step == SQLITE_ROW else { throw failure() }
            result.append(ClipRecord(id: string(stmt, 0), kind: ClipKind(rawValue: string(stmt, 1)) ?? .text, text: string(stmt, 2), thumbnail: data(stmt, 3), byteCount: Int(sqlite3_column_int64(stmt, 4)), firstAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5)), lastAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6)), count: Int(sqlite3_column_int64(stmt, 7))))
        }
    }
    func payload(id: String) throws -> ClipPayload? {
        let stmt = try statement("SELECT kind,text,payload,thumbnail FROM clips WHERE id=?"); defer { sqlite3_finalize(stmt) }; bind(id, stmt, 1)
        let status = sqlite3_step(stmt)
        if status == SQLITE_DONE { return nil }; guard status == SQLITE_ROW else { throw failure() }
        return ClipPayload(kind: ClipKind(rawValue: string(stmt, 0)) ?? .text, text: string(stmt, 1), data: data(stmt, 2) ?? Data(), thumbnail: data(stmt, 3))
    }
    func delete(id: String) throws {
        let stmt = try statement("DELETE FROM clips WHERE id=?"); defer { sqlite3_finalize(stmt) }; bind(id, stmt, 1)
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw failure() }
        try compact()
    }
    func clear() throws { try exec("DELETE FROM clips;"); try compact() }
    private func compact() throws { try exec("PRAGMA wal_checkpoint(TRUNCATE); VACUUM;") }
    func count() throws -> Int { let stmt = try statement("SELECT count(*) FROM clips"); defer { sqlite3_finalize(stmt) }; guard sqlite3_step(stmt) == SQLITE_ROW else { throw failure() }; return Int(sqlite3_column_int64(stmt, 0)) }
    var diskBytes: Int64 {
        [url.path, url.path + "-wal", url.path + "-shm"].reduce(0) { sum, path in sum + ((try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.int64Value ?? 0) }
    }
}
