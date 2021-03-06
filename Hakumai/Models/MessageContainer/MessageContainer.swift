//
//  ChatContainer.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 11/26/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation

// thread safe chat container
final class MessageContainer {
    // MARK: - Properties
    // MARK: Public
    static let sharedContainer = MessageContainer()

    var beginDateToShowHbIfseetnoCommands: Date?
    var showHbIfseetnoCommands = false
    var enableMuteUserIds = false
    var muteUserIds = [[String: String]]()
    var enableMuteWords = false
    var muteWords = [[String: String]]()

    // MARK: Private
    private var sourceMessages = [Message]()
    private var filteredMessages = [Message]()

    private var firstChat = [String: Bool]()

    private var rebuildingFilteredMessages = false
    private var calculatingActive = false
}

extension MessageContainer {
    // MARK: - Basic Operation to Content Array
    func append(chatOrSystemMessage object: Any) -> (appended: Bool, count: Int) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        var message: Message!

        if let systemMessage = object as? String {
            message = Message(message: systemMessage)
        } else if let chat = object as? Chat {
            var isFirstChat = false
            if chat.isUserComment, let userId = chat.userId {
                isFirstChat = firstChat[userId] == nil ? true : false
                if isFirstChat {
                    firstChat[userId] = true
                }
            }
            message = Message(chat: chat, firstChat: isFirstChat)
        } else {
            assert(false, "appending unexpected object")
        }

        sourceMessages.append(message)

        let appended = append(message: message, into: &filteredMessages)
        let count = filteredMessages.count

        return (appended, count)
    }

    func count() -> Int {
        objc_sync_enter(self)
        let count = filteredMessages.count
        objc_sync_exit(self)
        return count
    }

    subscript (index: Int) -> Message {
        objc_sync_enter(self)
        let content = filteredMessages[index]
        objc_sync_exit(self)
        return content
    }

    func messages(fromUserId userId: String) -> [Message] {
        var userMessages = [Message]()

        objc_sync_enter(self)
        for message in sourceMessages {
            if message.messageType != .chat {
                continue
            }
            if message.chat?.userId == userId {
                userMessages.append(message)
            }
        }
        objc_sync_exit(self)

        return userMessages
    }

    func removeAll() {
        objc_sync_enter(self)
        sourceMessages.removeAll(keepingCapacity: false)
        filteredMessages.removeAll(keepingCapacity: false)
        firstChat.removeAll(keepingCapacity: false)
        Message.resetMessageNo()
        objc_sync_exit(self)
    }

    // MARK: - Utility
    func calculateActive(completion: @escaping (Int?) -> Void) {
        if rebuildingFilteredMessages {
            log.debug("detected rebuilding filtered messages, so skip calculating active.")
            completion(nil)
            return
        }

        if calculatingActive {
            log.debug("detected duplicate calculating, so skip calculating active.")
            completion(nil)
            return
        }

        objc_sync_enter(self)
        calculatingActive = true
        objc_sync_exit(self)

        // log.debug("calcurating active")

        // swift way to use background gcd, http://stackoverflow.com/a/25070476
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            var activeUsers = [String: Bool]()
            let tenMinutesAgo = Date(timeIntervalSinceNow: (Double)(-10 * 60))

            // log.debug("start counting active")

            objc_sync_enter(self)
            let count = self.sourceMessages.count
            objc_sync_exit(self)

            var i = count
            while 0 < i {
                objc_sync_enter(self)
                let message = self.sourceMessages[i - 1]
                objc_sync_exit(self)
                i -= 1
                if message.messageType == .system {
                    continue
                }
                guard let chat = message.chat, let date = chat.date, let userId = chat.userId else { continue }
                if !chat.isUserComment {
                    continue
                }
                // is "chat.date < tenMinutesAgo" ?
                if date.compare(tenMinutesAgo) == .orderedAscending {
                    break
                }
                activeUsers[userId] = true
            }

            // log.debug("end counting active")

            completion(activeUsers.count)

            objc_sync_enter(self)
            self.calculatingActive = false
            objc_sync_exit(self)
        }
    }

    func rebuildFilteredMessages(completion: @escaping () -> Void) {
        // 1st pass:
        // copy and filter source messages. this could be long operation so use background thread
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            // log.debug("started 1st pass rebuilding filtered messages (bg section)")

            var workingMessages = [Message]()
            let sourceCount = self.sourceMessages.count

            for i in 0..<sourceCount {
                _ = self.append(message: self.sourceMessages[i], into: &workingMessages)
            }

            // log.debug("completed 1st pass")

            // 2nd pass:
            // we need to replace old filtered messages with new one with the following conditions;
            // - exclusive to ui updates, so use main thread
            // - atomic to any other operation like append, count, calcurate and so on, so use objc_sync_enter/exit
            DispatchQueue.main.async {
                // log.debug("started 2nd pass rebuilding filtered messages (critical section)")

                objc_sync_enter(self)
                self.rebuildingFilteredMessages = true

                self.filteredMessages = workingMessages
                // log.debug("copied working messages to filtered messages")

                let deltaCount = self.sourceMessages.count
                for i in sourceCount..<deltaCount {
                    _ = self.append(message: self.sourceMessages[i], into: &self.filteredMessages)
                }
                // log.debug("copied delta messages \(sourceCount)..<\(deltaCount)")

                self.rebuildingFilteredMessages = false
                objc_sync_exit(self)

                // log.debug("completed 2nd pass")
                log.debug("completed to rebuild filtered messages")

                completion()
            }
        }
    }
}

// MARK: - Internal Functions
private extension MessageContainer {
    // MARK: Filtered Message Append Utility
    func append(message: Message, into messages: inout [Message]) -> Bool {
        var appended = false
        if shouldAppend(message: message) {
            messages.append(message)
            appended = true
        }
        return appended
    }

    // swiftlint:disable cyclomatic_complexity
    func shouldAppend(message: Message) -> Bool {
        // filter by message type
        if message.messageType == .system {
            return true
        }

        guard let chat = message.chat else { return false }

        // filter by comment
        if let comment = chat.comment {
            if comment.hasPrefix("/hb ifseetno ") {
                if showHbIfseetnoCommands == false {
                    return false
                }

                // kickout commands should be ignored before live starts. espacially in channel live,
                // there are tons of kickout commands. and they forces application performance to be slowed down.
                if chat.date != nil, let beginDate = beginDateToShowHbIfseetnoCommands {
                    // chat.date < beginDateToShowHbIfseetnoCommands
                    if chat.date?.compare(beginDate) == .orderedAscending {
                        return false
                    }
                }
            }

            if enableMuteWords {
                for muteWord in muteWords {
                    if let word = muteWord[MuteUserWordKey.word] {
                        if comment.lowercased().range(of: word.lowercased()) != nil {
                            return false
                        }
                    }
                }
            }
        }

        // filter by userid
        if let userId = chat.userId, enableMuteUserIds {
            for muteUserId in muteUserIds where muteUserId[MuteUserIdKey.userId] == userId {
                return false
            }
        }

        return true
    }
    // swiftlint:enable cyclomatic_complexity
}
