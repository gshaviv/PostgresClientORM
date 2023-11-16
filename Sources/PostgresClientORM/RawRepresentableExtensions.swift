//
//  File.swift
//
//
//  Created by Guy Shaviv on 16/11/2023.
//

import Foundation
import PostgresNIO

public extension RawRepresentable where RawValue == String {
  static var psqlType: PostgresDataType {
    .text
  }

  static var psqlFormat: PostgresFormat {
    .binary
  }

  @inlinable
  func encode(
    into byteBuffer: inout ByteBuffer,
    context: PostgresEncodingContext<some PostgresJSONEncoder>
  ) {
    byteBuffer.writeString(rawValue)
  }

  @inlinable
  init(
    from buffer: inout ByteBuffer,
    type: PostgresDataType,
    format: PostgresFormat,
    context: PostgresDecodingContext<some PostgresJSONDecoder>
  ) throws {
    switch (format, type) {
    case (_, .varchar),
         (_, .bpchar),
         (_, .text),
         (_, .name):
      // we can force unwrap here, since this method only fails if there are not enough
      // bytes available.
      if let v = Self(rawValue: buffer.readString(length: buffer.readableBytes)!) {
        self = v
      } else {
        throw PostgresDecodingError.Code.typeMismatch
      }
    default:
      throw PostgresDecodingError.Code.typeMismatch
    }
  }
}

public extension RawRepresentable where RawValue == Int {
  static var psqlType: PostgresDataType {
    switch MemoryLayout<Int>.size {
    case 4:
      return .int4
    case 8:
      return .int8
    default:
      preconditionFailure("Int is expected to be an Int32 or Int64")
    }
  }

  static var psqlFormat: PostgresFormat {
    .binary
  }

  @inlinable
  func encode(
    into byteBuffer: inout ByteBuffer,
    context: PostgresEncodingContext<some PostgresJSONEncoder>
  ) {
    byteBuffer.writeInteger(self.rawValue, as: Int.self)
  }

  @inlinable
  init(
    from buffer: inout ByteBuffer,
    type: PostgresDataType,
    format: PostgresFormat,
    context: PostgresDecodingContext<some PostgresJSONDecoder>
  ) throws {
    let raw: Int
    switch (format, type) {
    case (.binary, .int2):
      guard buffer.readableBytes == 2, let value = buffer.readInteger(as: Int16.self) else {
        throw PostgresDecodingError.Code.failure
      }
      raw = Int(value)
    case (.binary, .int4):
      guard buffer.readableBytes == 4, let value = buffer.readInteger(as: Int32.self).flatMap({ Int(exactly: $0) }) else {
        throw PostgresDecodingError.Code.failure
      }
      raw = value
    case (.binary, .int8):
      guard buffer.readableBytes == 8, let value = buffer.readInteger(as: Int.self).flatMap({ Int(exactly: $0) }) else {
        throw PostgresDecodingError.Code.failure
      }
      raw = value
    case (.text, .int2), (.text, .int4), (.text, .int8):
      guard let string = buffer.readString(length: buffer.readableBytes), let value = Int(string) else {
        throw PostgresDecodingError.Code.failure
      }
      raw = value
    default:
      throw PostgresDecodingError.Code.typeMismatch
    }

    if let value = Self(rawValue: raw) {
      self = value
    } else {
      throw PostgresDecodingError.Code.failure
    }
  }
}

public extension RawRepresentable where RawValue == UInt8 {
  static var psqlType: PostgresDataType {
    .char
  }

  static var psqlFormat: PostgresFormat {
    .binary
  }

  @inlinable
  func encode(
    into byteBuffer: inout ByteBuffer,
    context: PostgresEncodingContext<some PostgresJSONEncoder>
  ) {
    byteBuffer.writeInteger(self.rawValue, as: UInt8.self)
  }

  @inlinable
  init(
    from buffer: inout ByteBuffer,
    type: PostgresDataType,
    format: PostgresFormat,
    context: PostgresDecodingContext<some PostgresJSONDecoder>
  ) throws {
    switch type {
    case .bpchar, .char:
      guard buffer.readableBytes == 1, let value = buffer.readInteger(as: UInt8.self) else {
        throw PostgresDecodingError.Code.failure
      }
      if let enumValue = Self(rawValue: value) {
        self = enumValue
      } else {
        throw PostgresDecodingError.Code.failure
      }
    default:
      throw PostgresDecodingError.Code.typeMismatch
    }
  }
}
