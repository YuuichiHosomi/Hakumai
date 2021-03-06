//
//  UserViewController.swift
//  Hakumai
//
//  Created by Hiroyuki Onishi on 12/22/14.
//  Copyright (c) 2014 Hiroyuki Onishi. All rights reserved.
//

import Foundation
import AppKit

// constant value for storyboard
/*
 private let kStoryboardIdGeneralViewController = "GeneralViewController"
 */

final class UserViewController: NSViewController {
    // MARK: - Properties
    // MARK: Outlets
    @IBOutlet weak var userIdLabel: NSTextField!
    @IBOutlet weak var userNameLabel: NSTextField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var scrollView: NSScrollView!

    // MARK: Basics
    var userId: String? {
        didSet {
            var userIdLabelValue: String?
            var userNameLabelValue: String?
            if let userId = userId {
                userIdLabelValue = userId
                if let userName = NicoUtility.shared.cachedUserName(forUserId: userId) {
                    userNameLabelValue = userName
                }
                messages = MessageContainer.sharedContainer.messages(fromUserId: userId)
            } else {
                messages.removeAll(keepingCapacity: false)
                rowHeightCacher.removeAll(keepingCapacity: false)
            }
            userIdLabel.stringValue = "UserId: " + (userIdLabelValue ?? "-----")
            userNameLabel.stringValue = "UserName: " + (userNameLabelValue ?? "-----")
            reloadMessages()
        }
    }
    var messages = [Message]()
    var rowHeightCacher = [Int: CGFloat]()

    // MARK: - Object Lifecycle
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - NSViewController Functions
extension UserViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        registerNibs()
    }

    private func registerNibs() {
        let nibs = [
            (kNibNameRoomPositionTableCellView, kRoomPositionColumnIdentifier),
            (kNibNameScoreTableCellView, kScoreColumnIdentifier)]
        for (nibName, identifier) in nibs {
            guard let nib = NSNib(nibNamed: nibName, bundle: Bundle.main) else { continue }
            tableView.register(nib, forIdentifier: convertToNSUserInterfaceItemIdentifier(identifier))
        }
    }
}

// MARK: - NSTableViewDataSource Functions
extension UserViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return messages.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        let message = messages[row]

        if let cached = rowHeightCacher[message.messageNo] {
            return cached
        }

        var rowHeight: CGFloat = 0

        guard let commentTableColumn = tableView.tableColumn(withIdentifier: convertToNSUserInterfaceItemIdentifier(kCommentColumnIdentifier)) else { return rowHeight }
        let commentColumnWidth = commentTableColumn.width
        rowHeight = commentColumnHeight(forMessage: message, width: commentColumnWidth)

        rowHeightCacher[message.messageNo] = rowHeight

        return rowHeight
    }

    private func commentColumnHeight(forMessage message: Message, width: CGFloat) -> CGFloat {
        let leadingSpace: CGFloat = 2
        let trailingSpace: CGFloat = 2
        let widthPadding = leadingSpace + trailingSpace

        let (content, attributes) = contentAndAttributes(forMessage: message)

        let commentRect = content.boundingRect(with: CGSize(width: width - widthPadding, height: 0),
                                               options: NSString.DrawingOptions.usesLineFragmentOrigin, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
        // log.debug("\(commentRect.size.width),\(commentRect.size.height)")

        return commentRect.size.height
    }

    func tableViewColumnDidResize(_ aNotification: Notification) {
        guard let column = (aNotification as NSNotification).userInfo?["NSTableColumn"] as? NSTableColumn else { return }
        if convertFromNSUserInterfaceItemIdentifier(column.identifier) == kCommentColumnIdentifier {
            rowHeightCacher.removeAll(keepingCapacity: false)
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var view: NSTableCellView?
        if let identifier = tableColumn?.identifier {
            view = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView
            view?.textField?.stringValue = ""
        }
        let message = messages[row]
        if message.messageType == .chat, let _view = view, let tableColumn = tableColumn {
            configure(view: _view, forChat: message, withTableColumn: tableColumn)
        }
        return view
    }
}

private extension UserViewController {
    func configure(view: NSTableCellView, forChat message: Message, withTableColumn tableColumn: NSTableColumn) {
        guard let chat = message.chat else { return }

        var attributed: NSAttributedString?

        switch convertFromNSUserInterfaceItemIdentifier(tableColumn.identifier) {
        case kRoomPositionColumnIdentifier:
            guard let roomPosition = chat.roomPosition, let no = chat.no else { return }
            let roomPositionView = view as? RoomPositionTableCellView
            roomPositionView?.roomPosition = roomPosition
            roomPositionView?.commentNo = no
        case kScoreColumnIdentifier:
            (view as? ScoreTableCellView)?.chat = chat
        case kCommentColumnIdentifier:
            let (content, attributes) = contentAndAttributes(forMessage: message)
            attributed = NSAttributedString(string: content, attributes: convertToOptionalNSAttributedStringKeyDictionary(attributes))
        default:
            break
        }

        if let attributed = attributed {
            view.textField?.attributedStringValue = attributed
        }
    }

    // MARK: Utility
    func contentAndAttributes(forMessage message: Message) -> (String, [String: Any]) {
        var content: String!
        var attributes = [String: Any]()

        if message.messageType == .system, let _message = message.message {
            content = _message
            attributes = UIHelper.normalCommentAttributes()
        } else if message.messageType == .chat, let _message = message.chat?.comment {
            content = _message
            attributes = (message.firstChat == true ? UIHelper.boldCommentAttributes() : UIHelper.normalCommentAttributes())
        }

        return (content, attributes)
    }

    func shouldTableViewScrollToBottom() -> Bool {
        let viewRect = scrollView.contentView.documentRect
        let visibleRect = scrollView.contentView.documentVisibleRect
        // log.debug("\(viewRect)-\(visibleRect)")

        let bottomY = viewRect.size.height
        let offsetBottomY = visibleRect.origin.y + visibleRect.size.height
        let allowance: CGFloat = 10

        let shouldScroll = (bottomY <= (offsetBottomY + allowance))

        return shouldScroll
    }

    func scrollTableViewToBottom() {
        let clipView = scrollView.contentView
        let x = clipView.documentVisibleRect.origin.x
        let y = clipView.documentRect.size.height - clipView.documentVisibleRect.size.height
        let origin = NSPoint(x: x, y: y)

        clipView.setBoundsOrigin(origin)
    }

    func reloadMessages() {
        let shouldScroll = shouldTableViewScrollToBottom()
        tableView.reloadData()
        if shouldScroll {
            scrollTableViewToBottom()
        }
        scrollView.flashScrollers()
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToNSUserInterfaceItemIdentifier(_ input: String) -> NSUserInterfaceItemIdentifier {
    return NSUserInterfaceItemIdentifier(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
    guard let input = input else { return nil }
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
private func convertFromNSUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier) -> String {
    return input.rawValue
}
