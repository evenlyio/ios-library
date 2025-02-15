/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif


/**
 * Action to open chat.
 *
 * The action will call `openChat` on the `AirshipChat` instance.
 *
 * This action is registered under the name `open_chat_action`.
 *
 * Expected argument value is nil, or a dictionary with `chat_input` key with the prefilled message as a String.
 *
 * Valid situations:  UASituationLaunchedFromPush, UASituationWebViewInvocation, UASituationManualInvocation,
 * UASituationForegroundInteractiveButton, and UASituationAutomation
 *
 * Result value: empty
 */
@available(iOS 13.0, *)
@objc(UAOpenChatAction)
public class OpenChatAction : NSObject, Action {

    public static let name = "open_chat_action"
    static let routingKey = "chat_routing"
    static let prepopulatedMessagesKey = "prepopulated_messages"
    static let inputKey = "chat_input"

    public typealias AirshipChatProvider = () -> Chat

    private let chatProvider : AirshipChatProvider

    @objc
    public override convenience init() {
        self.init {
            return Chat.shared
        }
    }

    init(chatProvider: @escaping AirshipChatProvider) {
        self.chatProvider = chatProvider
        super.init()
    }

    public func acceptsArguments(_ arguments: ActionArguments) -> Bool {
        switch(arguments.situation) {
        case .automation, .manualInvocation, .webViewInvocation, .launchedFromPush, .foregroundInteractiveButton:
            return true
        default:
            return false
        }
    }

    public func perform(with arguments: ActionArguments, completionHandler: @escaping UAActionCompletionHandler) {
        let chat = self.chatProvider()
        let args = arguments.value as? [String: Any]
        let message = args?[OpenChatAction.inputKey] as? String
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        
        if let routing = args?[OpenChatAction.routingKey] as? ChatRouting {
            chat.conversation.routing = routing
        } else if let routing = args?[OpenChatAction.routingKey] as? [String : AnyHashable] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: routing, options:[])
                let parsed = try decoder.decode(ChatRouting.self, from: jsonData)
                chat.conversation.routing = parsed
            }
            catch {
                AirshipLogger.error("Failed to parse routing \(error)")
            }
        }
            
        if let incoming = args?[OpenChatAction.prepopulatedMessagesKey] as? [Any] {
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: incoming, options: .fragmentsAllowed)
                let parsed = try decoder.decode([ChatIncomingMessage].self, from: jsonData)
                chat.addIncoming(parsed)
            }
            catch {
                AirshipLogger.error("Failed to parse outgoing messages \(error)")
            }
        }
        
        chat.openChat(message: message)

        completionHandler(ActionResult.empty())
    }
}
