//
//  CentrifugeClientMessageBuilderImpl.swift
//  Pods
//
//  Created by German Saprykin on 18/04/16.
//
//

protocol CentrifugeClientMessageBuilder {
    func buildConnectMessage(credentials: CentrifugeCredentials) -> CentrifugeClientMessage
    func buildDisconnectMessage() -> CentrifugeClientMessage
    func buildSubscribeMessageTo(channel: String) -> CentrifugeClientMessage
    func buildSubscribeMessageToPrivate(channel: String, client: String, sign: String) -> CentrifugeClientMessage
    func buildSubscribeMessageTo(channel: String, lastMessageUUID: String) -> CentrifugeClientMessage
    func buildUnsubscribeMessageFrom(channel: String) -> CentrifugeClientMessage
    func buildPresenceMessage(channel: String) -> CentrifugeClientMessage
    func buildHistoryMessage(channel: String) -> CentrifugeClientMessage
    func buildPingMessage() -> CentrifugeClientMessage
    func buildPublishMessageTo(channel: String, data: [String: Any]) -> CentrifugeClientMessage
}

final class CentrifugeClientMessageBuilderImpl: CentrifugeClientMessageBuilder {
    
    func buildConnectMessage(credentials: CentrifugeCredentials) -> CentrifugeClientMessage {
        
        let user = credentials.user, timestamp = credentials.timestamp, token = credentials.token
        
        var params = ["user" : user,
                      "timestamp" : timestamp,
                      "token" : token]
        
        if let info = credentials.info {
            params["info"] = info
        }
        
        return buildMessage(method: .сonnect, params: params)
    }
    
    func buildDisconnectMessage() -> CentrifugeClientMessage {
        return buildMessage(method: .disconnect, params: [:])
    }
    
    func buildSubscribeMessageTo(channel: String) -> CentrifugeClientMessage {
        return buildMessage(method: .subscribe, params: ["channel" : channel])
    }
    
    func buildSubscribeMessageToPrivate(channel: String, client: String, sign: String) -> CentrifugeClientMessage {
        let params = [
            "channel" : channel,
            "client" : client,
            "sign" : sign
        ]
        return buildMessage(method: .subscribe, params: params)
    }
    
    func buildSubscribeMessageTo(channel: String, lastMessageUUID: String) -> CentrifugeClientMessage {
        let params: [String : Any] = ["channel" : channel,
                      "recover" : true,
                      "last" : lastMessageUUID]
        return buildMessage(method: .subscribe, params: params)
    }
    
    func buildUnsubscribeMessageFrom(channel: String) -> CentrifugeClientMessage {
        return buildMessage(method: .unsubscribe, params: ["channel" : channel])
    }
    
    func buildPublishMessageTo(channel: String, data: [String : Any]) -> CentrifugeClientMessage {
        let params = ["channel" : channel,
                      "data" : data] as [String : Any]
        return buildMessage(method: .publish, params: params)
    }
    
    func buildPresenceMessage(channel: String) -> CentrifugeClientMessage {
        return buildMessage(method: .presence, params: ["channel" : channel])
    }
    
    func buildHistoryMessage(channel: String) -> CentrifugeClientMessage {
        return buildMessage(method: .history, params: ["channel" : channel])
    }
    
    func buildPingMessage() -> CentrifugeClientMessage {
        return buildMessage(method: .ping, params: [:])
    }
}

private extension CentrifugeClientMessageBuilderImpl {
    func buildMessage(method: CentrifugeMethod, params: [String: Any]) -> CentrifugeClientMessage {
        let uid = generateUUID()
        let message = CentrifugeClientMessage(uid: uid, method: method, params: params)
        return message
    }
    
    func generateUUID() -> String {
        return NSUUID().uuidString
    }
}
