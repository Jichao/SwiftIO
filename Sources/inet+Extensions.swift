//
//  Inet+Utilities.swift
//  SwiftIO
//
//  Created by Jonathan Wight on 5/20/15.
//
//  Copyright (c) 2014, Jonathan Wight
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Darwin

import SwiftUtilities

// MARK: in_addr extensions

extension in_addr: Equatable {
}

public func == (lhs: in_addr, rhs: in_addr) -> Bool {
    return unsafeBitwiseEquality(lhs, rhs)
}

extension in_addr: CustomStringConvertible {
    public var description: String {
        var s = self
        return tryElseFatalError() {
            return try Swift.withUnsafeMutablePointer(&s) {
                let ptr = UnsafePointer <Void> ($0)
                return try inet_ntop(addressFamily: AF_INET, address: ptr)
            }
        }

    }
}

// MARK: in6_addr extensions

extension in6_addr: Equatable {
}

public func == (lhs: in6_addr, rhs: in6_addr) -> Bool {
    return unsafeBitwiseEquality(lhs, rhs)
}

extension in6_addr: CustomStringConvertible {
    public var description: String {
        var s = self
        return tryElseFatalError() {
            return try Swift.withUnsafeMutablePointer(&s) {
                let ptr = UnsafePointer <Void> ($0)
                return try inet_ntop(addressFamily: AF_INET6, address: ptr)
            }
        }
    }
}

// MARK: Swift wrapper functions for useful (but fiddly) POSIX network functions

/**
`inet_ntop` wrapper that takes an address in network byte order (big-endian) to presentation format.

- parameter addressFamily: IPv4 (AF_INET) or IPv6 (AF_INET6) family.
- parameter address: The address structure to convert.

- throws: @schwa what's proper documentation for this?

- returns: The IP address in presentation format
*/
public func inet_ntop(addressFamily addressFamily: Int32, address: UnsafePointer <Void>) throws -> String {
    var buffer: Array <Int8>
    var size: Int

    switch addressFamily {
    case AF_INET:
        size = Int(INET_ADDRSTRLEN)
    case AF_INET6:
        size = Int(INET6_ADDRSTRLEN)
    default:
        fatalError("Unknown address family")
    }

    buffer = Array <Int8> (count: size, repeatedValue: 0)

    return buffer.withUnsafeMutableBufferPointer() {
        (inout outputBuffer: UnsafeMutableBufferPointer <Int8>) -> String in
        let result = inet_ntop(addressFamily, address, outputBuffer.baseAddress, socklen_t(size))
        return String(CString: result, encoding: NSASCIIStringEncoding)!
    }
}

// MARK: -

public func getnameinfo(addr: UnsafePointer<sockaddr>, addrlen: socklen_t, inout hostname: String?, inout service: String?, flags: Int32) throws {
    var hostnameBuffer = [Int8](count: Int(NI_MAXHOST), repeatedValue: 0)
    var serviceBuffer = [Int8](count: Int(NI_MAXSERV), repeatedValue: 0)
    let result = hostnameBuffer.withUnsafeMutableBufferPointer() {
        (inout hostnameBufferPtr: UnsafeMutableBufferPointer<Int8>) -> Int32 in
        serviceBuffer.withUnsafeMutableBufferPointer() {
            (inout serviceBufferPtr: UnsafeMutableBufferPointer<Int8>) -> Int32 in
            let result = getnameinfo(
                addr, addrlen,
                hostnameBufferPtr.baseAddress, socklen_t(NI_MAXHOST),
                serviceBufferPtr.baseAddress, socklen_t(NI_MAXSERV),
                flags)
            if result == 0 {
                hostname = String(CString: hostnameBufferPtr.baseAddress, encoding: NSASCIIStringEncoding)
                service = String(CString: serviceBufferPtr.baseAddress, encoding: NSASCIIStringEncoding)
            }
            return result
        }
    }
    guard result == 0 else {
        throw Errno(rawValue: errno) ?? Error.Unknown
    }
}

// MARK: -

public func getaddrinfo(hostname: String?, service: String? = nil, hints: addrinfo, block: UnsafePointer<addrinfo> throws -> Bool) throws {
    let hostname = hostname ?? ""
    let service = service ?? ""

    var hints = hints
    var info: UnsafeMutablePointer <addrinfo> = nil
    let result = getaddrinfo(hostname, service, &hints, &info)
    guard result == 0 else {
        let ptr = gai_strerror(result)
        if let string = String(UTF8String: ptr) {
            throw Error.Generic(string)
        }
        else {
            throw Error.Unknown
        }
    }

    var current = info
    while current != nil {
        if try block(current) == false {
            break
        }
        current = current.memory.ai_next
    }
    freeaddrinfo(info)
}

public func getaddrinfo(hostname: String?, service: String? = nil, hints: addrinfo) throws -> [Address] {
    var addresses: [Address] = []

    try getaddrinfo(hostname, service: service, hints: hints) {
        let addr = sockaddr_storage(addr: $0.memory.ai_addr, length: Int($0.memory.ai_addrlen))
        let address = Address(sockaddr: addr)
        addresses.append(address)
        return true
    }
    return Array(Set(addresses)).sort(<)
}

// MARK: -

public extension in_addr {
    var octets: (UInt8, UInt8, UInt8, UInt8) {
        let address = UInt32(networkEndian: s_addr)
        return (
            UInt8((address >> 24) & 0xFF),
            UInt8((address >> 16) & 0xFF),
            UInt8((address >> 8) & 0xFF),
            UInt8(address & 0xFF)
        )
    }
}

public extension in6_addr {
    var words: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16) {
        assert(sizeof(in6_addr) == sizeof((UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16)))
        var copy = self
        return withUnsafePointer(&copy) {
            let networkWords = UnsafeBufferPointer <UInt16> (start: UnsafePointer <UInt16> ($0), count: 8)
            let words = networkWords.map() { UInt16(networkEndian: $0) }
            return (words[0], words[1], words[2], words[3], words[4], words[5], words[6], words[7])
        }
    }
}
