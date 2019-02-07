//
//  Centrifugal.swift
//  Pods
//
//  Created by German Saprykin on 18/04/16.
//
//

import Foundation
import CentrifugeiOS.CommonCryptoBridge

public let CentrifugeErrorDomain = "com.Centrifuge.error.domain"
public let CentrifugeWebSocketErrorDomain = "com.Centrifuge.error.domain.websocket"
public let CentrifugeErrorMessageKey = "com.Centrifuge.error.messagekey"

public let CentrifugePrivateChannelPrefix = "$"

public enum CentrifugeErrorCode: Int {
    case CentrifugeMessageWithError
}

public typealias CentrifugeMessageHandler = (CentrifugeServerMessage?, Error?) -> Void

public final class Centrifuge {
    public class func client(url: URL, creds: CentrifugeCredentials, delegate: CentrifugeClientDelegate) -> CentrifugeClient {
        return CentrifugeClientImpl(url: url, credentials: creds, delegate: delegate)
    }
    
    public class func createToken(string: String, key: String) -> String {
        return CentrifugeCommonCryptoBridge.hexHMACSHA256(forData: string, withKey: key)
    }
}
