//
//  ComposeContainerViewModel.swift
//  ProtonMail - Created on 15/04/2019.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonMail.
//
//  ProtonMail is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonMail is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonMail.  If not, see <https://www.gnu.org/licenses/>.
    

import Foundation

extension ComposeContainerViewModel: Codable {
    enum CodingKeys: CodingKey {
        case messageID, messageAction
    }
    
    enum Errors: Error {
        case noUnderlyingMessage
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        if let message = self.childViewModel.message {
            try container.encode(message.messageID, forKey: .messageID)
        }
        try container.encode(self.childViewModel.messageAction.rawValue, forKey: .messageAction)
    }
}

class ComposeContainerViewModel: TableContainerViewModel {
    internal var childViewModel: ContainableComposeViewModel
    
    // for FileImporter
    internal lazy var documentAttachmentProvider = DocumentAttachmentProvider(for: self)
    internal lazy var imageAttachmentProvider = PhotoAttachmentProvider(for: self)
    internal let kDefaultAttachmentFileSize : Int = 25 * 1000 * 1000 // 25 mb
    
    init(editorViewModel: ContainableComposeViewModel) {
        self.childViewModel = editorViewModel
        super.init()
    }
    
    required convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let messageID = try container.decode(String.self, forKey: .messageID)
        let messageActionRaw = try container.decode(Int.self, forKey: .messageAction)
        
        guard let message = sharedMessageDataService.fetchMessages(withIDs: NSMutableSet(array: [messageID])).first,
            let action =  ComposeMessageAction(rawValue: messageActionRaw) else
        {
            throw Errors.noUnderlyingMessage
        }
        let childViewModel = ContainableComposeViewModel(msg: message, action: action)
        
        self.init(editorViewModel: childViewModel)
    }
    
    override var numberOfSections: Int {
        return 1
    }
    override func numberOfRows(in section: Int) -> Int {
        return 2
    }
    
    internal func filesExceedSizeLimit() -> Bool {
        return self.childViewModel.currentAttachmentsSize >= self.kDefaultAttachmentFileSize
    }
    
    internal func filesAreSupported(from itemProviders: [NSItemProvider]) -> Bool {
        return itemProviders.reduce(true) { $0 && $1.hasItem(types: self.filetypes) != nil }
    }
    
    internal func importFiles(from itemProviders: [NSItemProvider],
                              errorHandler: @escaping (String)->Void,
                              successHandler: @escaping ()->Void) {
        for itemProvider in itemProviders {
            guard let type = itemProvider.hasItem(types: self.filetypes) else { return }
            self.importFile(itemProvider, type: type, errorHandler: errorHandler, handler: successHandler)
        }
    }
}

extension ComposeContainerViewModel: FileImporter, AttachmentController {
    func present(_ controller: UIViewController, animated: Bool, completion: (() -> Void)?) {
        fatalError()
    }
    var barItem: UIBarButtonItem? {
        return nil
    }
    func error(_ description: String) {
        self.showErrorBanner(description)
    }
    
    func fileSuccessfullyImported(as fileData: FileData) {
        guard self.childViewModel.currentAttachmentsSize + fileData.contents.dataSize < self.kDefaultAttachmentFileSize else {
            self.showErrorBanner(LocalString._the_total_attachment_size_cant_be_bigger_than_25mb)
            return
        }
        let stripMetadata = userCachedStatus.metadataStripping == .stripMetadata
        let attachment = fileData.contents.toAttachment(self.childViewModel.message!, fileName: fileData.name, type: fileData.ext, stripMetadata: stripMetadata)
        self.childViewModel.uploadAtt(attachment)
    }
}
