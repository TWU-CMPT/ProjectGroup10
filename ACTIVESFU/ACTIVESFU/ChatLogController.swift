//
//  ChatLogController.swift
//  
//  Records and retrieves user messages to one another in Firebase. The user is able to select a buddy and then chat in real time.
//
//
//
//  Created by Bronwyn Biro on 2017-03-06.
//  Copyright © 2017 CMPT276 Group 10. All rights reserved.
//

import Foundation
import UIKit
import MobileCoreServices
import AVFoundation

import Firebase


//MARK: ChatLogController


class ChatLogController: UICollectionViewController, UITextFieldDelegate, UICollectionViewDelegateFlowLayout,  UINavigationControllerDelegate {
    
    lazy var inputContainerView: ChatInputContainerView = {
        
        let chatInputContainerView = ChatInputContainerView(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 50))
        chatInputContainerView.chatLogController = self
        
        return chatInputContainerView
    }()
    
    var messages = [Message]()
    
    var user: User? {
        
        didSet {
            navigationItem.title = user?.user
            observeMessages()
        }
    }
    
    var containerViewBottomAnchor: NSLayoutConstraint?
    
    override var inputAccessoryView: UIView? {
        
        get {
            
            return inputContainerView
        }
    }
    
    override var canBecomeFirstResponder : Bool {
        
        return true
    }
    
    let usersDatabaseReference = FIRDatabase.database().reference().child("Users")
    let userUID = FIRAuth.auth()?.currentUser?.uid
    let cellId = "cellId"
    
    @IBAction func backButton(_ sender: UIBarButtonItem) {
        
        dismiss(animated: true, completion: nil)
    }

    func handleSend() {
        
        let buddyId = user?.id
        let isBuddyBlocked = usersDatabaseReference.child(userUID!).child("Buddies").child(buddyId!)
        
        isBuddyBlocked.observeSingleEvent(of: .value, with: { (snapshot) in
            
            //user isn't blocked
            if snapshot.value! as? Int == 0 {
                
                let properties = ["text": self.inputContainerView.inputTextField.text!]
                self.sendMessageWithProperties(properties as [String : AnyObject])
            }
            else {
                
                self.userIsBlocked()
            }
        })
    }
    
    func observeMessages() {

        guard let uid = FIRAuth.auth()?.currentUser?.uid, let toId = user?.id
        else {
            
            return
        }
        
        /*
         //TODO: implement with uid, dont remove
        guard let uid = FIRAuth.auth()?.currentUser?.uid, let toId = user?.id else {
            return
        }
         */

        let userMessagesRef = FIRDatabase.database().reference().child("user-messages").child(uid).child(toId)
        userMessagesRef.observe(.childAdded, with: { (snapshot) in
            
            let messageId = snapshot.key
            let messagesRef = FIRDatabase.database().reference().child("messages").child(messageId)
            messagesRef.observeSingleEvent(of: .value, with: { (snapshot) in
                
                guard let dictionary = snapshot.value as? [String: AnyObject] else {
                    
                    return
                }
                self.messages.append(Message(dictionary: dictionary))
                DispatchQueue.main.async(execute: {
                    
                    self.collectionView?.reloadData()
                    //scroll to the last index
                    let indexPath = IndexPath(item: self.messages.count - 1, section: 0)
                    self.collectionView?.scrollToItem(at: indexPath, at: .bottom, animated: true)
                })
                
            }, withCancel: nil)
            
        }, withCancel: nil)
    }
    
    func dismissView() {
        
       // BuddiesViewController().fetchAllBuddiesInDatabase()
        dismiss(animated: true, completion: nil)
    }
    
    func setupKeyboardObservers() {
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardDidShow), name: NSNotification.Name.UIKeyboardDidShow, object: nil)
   // NotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleKeyboardWillShow), name: UIKeyboardWillShowNotification, object: nil)
        //
   // NotificationCenter.defaultCenter().addObserver(self, selector: #selector(handleKeyboardWillHide), name: UIKeyboardWillHideNotification, object: nil)
    }
    
    func handleKeyboardDidShow() {
        
        if messages.count > 0 {
            
            let indexPath = IndexPath(item: messages.count - 1, section: 0)
            collectionView?.scrollToItem(at: indexPath, at: .top, animated: true)
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    
    //MARK: UICollectionsViewController
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        collectionView?.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        //        collectionView?.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        collectionView?.alwaysBounceVertical = true
        collectionView?.backgroundColor = UIColor.white
        collectionView?.register(ChatMessageCell.self, forCellWithReuseIdentifier: cellId)
        collectionView?.keyboardDismissMode = .interactive
        
        let backButton = UIBarButtonItem(title: "Back", style: UIBarButtonItemStyle.plain, target: self, action: #selector(dismissView))
        let blockButton = UIBarButtonItem(title: "Options", style: UIBarButtonItemStyle.plain, target: self, action: #selector(optionsAlertHandler))
        navigationItem.leftBarButtonItem = backButton
        navigationItem.rightBarButtonItem = blockButton
        
        setupKeyboardObservers()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        super.viewDidDisappear(animated)

        NotificationCenter.default.removeObserver(self)
    }
    
    func handleKeyboardWillShow(_ notification: Notification) {
        
        let keyboardFrame = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as AnyObject).cgRectValue
        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        containerViewBottomAnchor?.constant = -keyboardFrame!.height
        UIView.animate(withDuration: keyboardDuration!, animations: {
            
            self.view.layoutIfNeeded()
        })
    }
    
    func handleKeyboardWillHide(_ notification: Notification) {
        
        let keyboardDuration = (notification.userInfo?[UIKeyboardAnimationDurationUserInfoKey] as AnyObject).doubleValue
        
        containerViewBottomAnchor?.constant = 0
        UIView.animate(withDuration: keyboardDuration!, animations: {
            
            self.view.layoutIfNeeded()
        })
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        return messages.count
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { //unnecessary?
        
        textField.resignFirstResponder()
        return true
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! ChatMessageCell
        
        cell.chatLogController = self
        
        let message = messages[indexPath.item]
        
        cell.message = message
        cell.textView.text = message.text
        
        setupCell(cell, message: message)
        
        if let text = message.text {
            
            //a text message
            cell.bubbleWidthAnchor?.constant = estimateFrameForText(text).width + 32
            cell.textView.isHidden = false
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 80
        
        let message = messages[indexPath.item]
        if let text = message.text {
            
            height = estimateFrameForText(text).height + 20
        }
        let width = UIScreen.main.bounds.width
        return CGSize(width: width, height: height)
    }
    
    
    //MARK: PRIVATE
    
    
    //cell constraints
    fileprivate func setupCell(_ cell: ChatMessageCell, message: Message) {
        
        if message.fromId == FIRAuth.auth()?.currentUser?.uid {
            
            //outgoing blue
            cell.bubbleView.backgroundColor = ChatMessageCell.blueColor
            cell.textView.textColor = UIColor.white
            
            cell.bubbleViewRightAnchor?.isActive = true
            cell.bubbleViewLeftAnchor?.isActive = false
        }
        else {
            
            //incoming gray
            cell.bubbleView.backgroundColor = UIColor(red:0.86, green:0.86, blue:0.86, alpha:1.0)
            cell.textView.textColor = UIColor.black
            
            cell.bubbleViewRightAnchor?.isActive = false
            cell.bubbleViewLeftAnchor?.isActive = true
        }
    }
    
    fileprivate func estimateFrameForText(_ text: String) -> CGRect {
        
        let size = CGSize(width: 200, height: 1000)
        let options = NSStringDrawingOptions.usesFontLeading.union(.usesLineFragmentOrigin)
        return NSString(string: text).boundingRect(with: size, options: options, attributes: [NSFontAttributeName: UIFont.systemFont(ofSize: 16)], context: nil)
    }

    fileprivate func sendMessageWithProperties(_ properties: [String: AnyObject]) {
        
        let ref = FIRDatabase.database().reference().child("messages")
        let childRef = ref.childByAutoId()
        //let toId = user?.email
        let toId = user?.id
        print("toId", toId)
        let fromId = FIRAuth.auth()!.currentUser!.uid
        print("from ID", fromId)
        
        let timestamp: NSNumber = NSNumber.init(value: Date().timeIntervalSince1970);
        var values: [String: AnyObject] = ["toId": toId as AnyObject, "fromId": fromId as AnyObject, "timestamp": timestamp]
        
        properties.forEach({values[$0] = $1})
        
        childRef.updateChildValues(values) { (error, ref) in
            if error != nil {
                
                print(error!)
                return
            }
            self.inputContainerView.inputTextField.text = nil
            
            let userMessagesRef = FIRDatabase.database().reference().child("user-messages").child(fromId).child(toId!)
            
            let messageId = childRef.key
            userMessagesRef.updateChildValues([messageId: 1])
            
            let recipientChatUserMessagesRef = FIRDatabase.database().reference().child("user-messages").child(toId!).child(fromId)
            recipientChatUserMessagesRef.updateChildValues([messageId: 1])
        }
    }
}
