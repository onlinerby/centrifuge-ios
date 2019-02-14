//
//  Clients.swift
//  Pods
//
//  Created by German Saprykin on 20/04/16.
//
//

import Starscream

final class CentrifugeClientImpl: CentrifugeClient {
    init(url: URL, credentials: CentrifugeCredentials, delegate: CentrifugeClientDelegate) {
        self.url = url
        self.creds = credentials
        self.delegate = delegate
        self.builder = CentrifugeClientMessageBuilderImpl()
        self.parser = CentrifugeServerMessageParserImpl()
    }
    
    // MARK: CentrifugeClient
    var isConnected: Bool {
        return webSocket.isConnected
    }
    weak var delegate: CentrifugeClientDelegate?
    
    func connect(withCompletion completion: @escaping CentrifugeMessageHandler) {
        assert(isConnected == false, "Already connected")
        blockingHandler = connectionProcessHandler
        connectionCompletion = completion
        webSocket.connect()
    }
    
    func disconnect() {
        webSocket.disconnect()
    }
    
    func ping(withCompletion completion: @escaping CentrifugeMessageHandler) {
        let message = builder.buildPingMessage()
        messageCallbacks[message.uid] = completion
        send(message: message)
    }
    
    //MARK: Channel related method
    func subscribe(toChannel channel: String, delegate: CentrifugeChannelDelegate, completion: @escaping CentrifugeMessageHandler) {
        let message = builder.buildSubscribeMessageTo(channel: channel)
        subscription[channel] = delegate
        messageCallbacks[message.uid] = completion
        send(message: message)
    }
    
    func subscribe(privateChannel channel: String, client: String, sign: String, info: [String: Any], delegate: CentrifugeChannelDelegate, completion: @escaping CentrifugeMessageHandler) {
        let channel = channel.hasPrefix(CentrifugePrivateChannelPrefix) ? channel : CentrifugePrivateChannelPrefix + channel
        let message = builder.buildSubscribeMessageToPrivate(channel: channel, client: client, sign: sign, info: info)
        subscription[channel] = delegate
        messageCallbacks[message.uid] = completion
        send(message: message)
    }
    
    func subscribe(toChannel channel: String, delegate: CentrifugeChannelDelegate, lastMessageUID uid: String, completion: @escaping CentrifugeMessageHandler) {
        let message = builder.buildSubscribeMessageTo(channel: channel, lastMessageUUID: uid)
        subscription[channel] = delegate
        messageCallbacks[message.uid] = completion
        send(message: message)
    }
    
    func publish(toChannel channel: String, data: [String : Any], completion: @escaping CentrifugeMessageHandler) {
        let message = builder.buildPublishMessageTo(channel: channel, data: data)
        messageCallbacks[message.uid] = completion
        send(message: message)
    }
    
    func unsubscribe(fromChannel channel: String, completion: @escaping CentrifugeMessageHandler) {
        let message = builder.buildUnsubscribeMessageFrom(channel: channel)
        messageCallbacks[message.uid] = completion
        send(message: message)
    }
    
    func presence(inChannel channel: String, completion: @escaping CentrifugeMessageHandler) {
        let message = builder.buildPresenceMessage(channel: channel)
        messageCallbacks[message.uid] = completion
        send(message: message)
    }
    
    func history(ofChannel channel: String, completion: @escaping CentrifugeMessageHandler) {
        let message = builder.buildHistoryMessage(channel: channel)
        messageCallbacks[message.uid] = completion
        send(message: message)
    }
    
    private lazy var webSocket = WebSocket(with: url, delegate: self)
    private let url: URL
    private let creds: CentrifugeCredentials
    private let builder: CentrifugeClientMessageBuilder
    private let parser: CentrifugeServerMessageParser
    
    private var messageCallbacks = [String : CentrifugeMessageHandler]()
    private var subscription = [String : CentrifugeChannelDelegate]()
    
    /** Handler is used to process websocket delegate method.
     If it is not nil, it blocks default actions. */
    private var blockingHandler: (([CentrifugeServerMessage]?, Error?) -> Void)?
    private var connectionCompletion: CentrifugeMessageHandler?
}

extension CentrifugeClientImpl: WebSocketDelegate {
    func websocketDidConnect(socket: WebSocketClient) {
        let message = builder.buildConnectMessage(credentials: creds)
        send(message: message)
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        guard let handler = blockingHandler else { return }
        let error = error ?? NSError(domain: CentrifugeErrorDomain, code: CentrifugeErrorCode.CentrifugeMessageWithError.rawValue, userInfo: [NSLocalizedDescriptionKey : "Unknown disconnect error"])
        handler(nil, error)
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        let data = text.data(using: String.Encoding.utf8)!
        let messages = try! parser.parse(data: data)
        
        if let handler = blockingHandler {
            handler(messages, nil)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        let messages = try! parser.parse(data: data)
        
        if let handler = blockingHandler {
            handler(messages, nil)
        }
    }
}

//MARK: - Helpers

private extension CentrifugeClientImpl {
    func unsubscribeFrom(channel: String) {
        subscription[channel] = nil
    }
    
    func send(message: CentrifugeClientMessage) {
        let dict: [String:Any] = [
            "uid" : message.uid,
            "method" : message.method.rawValue,
            "params" : message.params
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
            webSocket.write(data: data)
        } catch let error {
            assertionFailure("JSONSerialization error: \(error)")
        }
    }
    
    func setupConnectedState() {
        blockingHandler = defaultProcessHandler
    }
    
    func resetState() {
        blockingHandler = nil
        connectionCompletion = nil
        
        messageCallbacks.removeAll()
        subscription.removeAll()
    }
    
    //MARK: - Handlers
    /**
     Handler is using while connecting to server.
     */
    func connectionProcessHandler(messages: [CentrifugeServerMessage]?, error: Error?) -> Void {
        guard let handler = connectionCompletion else {
            assertionFailure("Error: No connectionCompletion")
            return
        }
        
        resetState()
        
        if let err = error {
            handler(nil, err)
            return
        }
        
        guard let message = messages?.first else {
            assertionFailure("Error: Empty messages array")
            return
        }
        
        if message.error == nil{
            setupConnectedState()
            handler(message, nil)
        } else {
            let error = NSError.errorWithMessage(message: message)
            handler(nil, error)
        }
    }
    
    /**
     Handler is using while normal working with server.
     */
    func defaultProcessHandler(messages: [CentrifugeServerMessage]?, error: Error?) {
        if let error = error {
            resetState()
            delegate?.client(self, didDisconnectWithError: error)
            return
        }
        
        guard let msgs = messages else {
            assertionFailure("Error: Empty messages array without error")
            return
        }
        
        for message in msgs {
            defaultProcessHandler(message: message)
        }
    }
    
    func defaultProcessHandler(message: CentrifugeServerMessage) {
        var handled = false
        if let uid = message.uid, messageCallbacks[uid] == nil {
            assertionFailure("Error: Untracked message is received")
            return
        }
        
        if let uid = message.uid, let handler = messageCallbacks[uid], message.error != nil {
            let error = NSError.errorWithMessage(message: message)
            handler(nil, error)
            messageCallbacks[uid] = nil
            return
        }
        
        if let uid = message.uid, let handler = messageCallbacks[uid] {
            handler(message, nil)
            messageCallbacks[uid] = nil
            handled = true
        }
        
        if (handled && (message.method != .unsubscribe && message.method != .disconnect)) {
            return
        }
        
        switch message.method {
            
        // Channel events
        case .message:
            guard let channel = message.body?["channel"] as? String, let delegate = subscription[channel] else {
                assertionFailure("Error: Invalid \(message.method) handler")
                return
            }
            delegate.client(self, didReceiveMessageInChannel: channel, message: message)
        case .join:
            guard let channel = message.body?["channel"] as? String, let delegate = subscription[channel] else {
                assertionFailure("Error: Invalid \(message.method) handler")
                return
            }
            delegate.client(self, didReceiveJoinInChannel: channel, message: message)
        case .leave:
            guard let channel = message.body?["channel"] as? String, let delegate = subscription[channel] else {
                assertionFailure("Error: Invalid \(message.method) handler")
                return
            }
            delegate.client(self, didReceiveLeaveInChannel: channel, message: message)
        case .unsubscribe:
            guard let channel = message.body?["channel"] as? String, let delegate = subscription[channel] else {
                assertionFailure("Error: Invalid \(message.method) handler")
                return
            }
            delegate.client(self, didReceiveUnsubscribeInChannel: channel, message: message)
            unsubscribeFrom(channel: channel)
            
        // Client events
        case .disconnect:
            resetState()
            webSocket.disconnect()
            delegate?.client(self, didDisconnectWithError: NSError.errorWithMessage(message: message))
        case .refresh:
            delegate?.client(self, didReceiveRefreshMessage: message)
        default:
            assertionFailure("Error: Invalid method type")
        }
    }
}

private extension WebSocket {
    convenience init(with url: URL, delegate: WebSocketDelegate) {
        self.init(url: url)
        self.delegate = delegate
    }
}
