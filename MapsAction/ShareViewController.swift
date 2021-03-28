//
//  ShareViewController.swift
//  MapsAction
//
//  Created by Marco Filetti on 23/06/2017.
//  Copyright © 2017 Marco Filetti. All rights reserved.
//

import UIKit
import Social

class ShareViewController: SLComposeServiceViewController {
    
    let groupId = Constants.groupId
    let maxNameLength = Constants.maxNameLength
    
    override func isContentValid() -> Bool {

        var trimmed = contentText.replacingOccurrences(of: "\n", with: " ")
        trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let trimLength = trimmed.count
        
        let remChars = maxNameLength - trimLength
        
        charactersRemaining = NSNumber(value: remChars)
        
        return trimLength > 0 && trimLength <= maxNameLength
    }

    override func didSelectPost() {

        // we want to finish eventually
        defer {
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        }

        // name entered by user, for destination
        guard let name = self.contentText else {
            return
        }
        
        // we should get one extension item with three attachments.
        guard extensionContext?.inputItems.count ?? 0 == 1,
              let extItem = extensionContext?.inputItems[0] as? NSExtensionItem,
              let attachments = extItem.attachments else {
                
                return
        
        }
        
        // one attachment is uti public.plain-text, another public.vcard and the
        // last public.url. We only get the url, since that contains the
        // coordinates in the ll parameter, which we want
        guard let itemProvider = attachments
               .filter({$0.hasItemConformingToTypeIdentifier("public.url")})
               .first else {
            return
        }
        
        // ask for the url
        itemProvider.loadItem(forTypeIdentifier: "public.url", options: nil) {
            item, error in
            
            // get url and split into components
            guard let url = item as? URL,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                    return
            }
            
            // get coordinate string, which should be a comma separated lat and long under ll
            guard let queryItem = components.queryItems?.filter({$0.name == "ll"}).first,
                  let coordString = queryItem.value else {
                    return
            }
            
            let splitString = coordString.components(separatedBy: ",")
            
            // decode items from string
            guard splitString.count == 2,
               let latitude = Double(splitString[0]),
               let longitude = Double(splitString[1]) else {
                return
            }

            // finally got our destination
            let destination = Destination(name: name, latitude: latitude, longitude: longitude)
            
            var addedArray: [[String: Any]] = UserDefaults(suiteName: self.groupId)!.array(forKey: "addedDestinations") as? [[String: Any]] ?? []
            
            addedArray.append(destination.toDict())
            
            UserDefaults(suiteName: self.groupId)!.set(addedArray, forKey: "addedDestinations")
            
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        defer {
            super.viewWillAppear(animated)
        }
        
        navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "add".localized
        navigationController?.navigationBar.backgroundColor = UIColor.black
        navigationController?.navigationBar.tintColor = Constants.arrowColor
        
    }

    override func textViewDidChange(_ textView: UITextView) {
        validateContent()
    }
    
}
