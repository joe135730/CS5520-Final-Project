import UIKit
import FirebaseAuth
import FirebaseFirestore

class MainScreenController: UIViewController, UITableViewDataSource, UITableViewDelegate, FriendsTableViewControllerDelegate {
   
    let mainScreenView = MainScreenView()
    let tableViewContacts = UITableView()
    let db = Firestore.firestore()
    
    var contactsList: [Contact] = []
    var friends: [Contact] = []
    
    weak var friendsTableVC: FriendsTableViewController?
    
    override func loadView() {
        view = mainScreenView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chat room"
        navigationController?.navigationBar.prefersLargeTitles = true
        mainScreenView.tableViewContacts.dataSource = self
        mainScreenView.tableViewContacts.delegate = self
                
        mainScreenView.floatingButtonAddChat.addTarget(self, action: #selector(floatingButtonTapped), for: .touchUpInside)
        view.bringSubviewToFront(mainScreenView.floatingButtonAddChat)
        view.bringSubviewToFront(mainScreenView.floatingButtonAddChat)
        loadContacts()
    }
    
    //MARK: save friend to Firestore - collection: users, document: userEmail
    func saveFriendToFirestore(friend: Contact) {
      guard let userEmail = Auth.auth().currentUser?.email?.lowercased() else { return }
      let collectionContacts = db.collection("users").document(userEmail).collection("contacts")
      
      do {
          try collectionContacts.addDocument(from: friend) { error in
              if let error = error {
                  print("Error saving friend to Firestore: \(error.localizedDescription)")
              } else {
                  print("Friend successfully saved to Firestore.")
              }
          }
      } catch {
          print("Error encoding friend data for Firestore: \(error)")
      }
    }
    
    func loadFriendsFirestore() {
        guard let userEmail = Auth.auth().currentUser?.email?.lowercased() else { return }
        let collectionContacts = db.collection("users").document(userEmail).collection("contacts")
        collectionContacts.whereField("email", isEqualTo: userEmail).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error loading friends from Firestore: \(error.localizedDescription)")
            } else {
                self.friends = snapshot?.documents.compactMap { document in
                    try? document.data(as: Contact.self)
                } ?? []
                
                DispatchQueue.main.async {
                    self.tableViewContacts.reloadData()
                }
            }
        }
    }
    
    @objc func floatingButtonTapped() {
        let friendsVC = FriendsTableViewController()
        friendsVC.delegate = self
        friendsVC.modalPresentationStyle = .pageSheet
        
        if let sheet = friendsVC.sheetPresentationController {
            // Only use medium detent for a half-screen presentation
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            
            // Prevent the sheet from being pulled up to full screen
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            
            // Ensure the sheet stays at medium height even in landscape
            sheet.selectedDetentIdentifier = .medium
        }
        
        present(friendsVC, animated: true)
    }
    
    private func loadContacts() {
        guard let currentUserEmail = Auth.auth().currentUser?.email?.lowercased() else { return }
        db.collection("users")
            .document(currentUserEmail)
            .collection("contacts")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading contacts: \(error)")
                    return
                }
                
                self?.contactsList = snapshot?.documents.compactMap { document -> Contact? in
                    do {
                        let contact = try document.data(as: Contact.self)
                        if contact.lastMessage != nil && contact.lastMessageTime != nil {
                            return contact
                        }
                        return nil
                    } catch {
                        print("Error decoding contact: \(error)")
                        return nil
                    }
                } ?? []
                
                self?.contactsList.sort { (contact1, contact2) -> Bool in
                    guard let time1 = contact1.lastMessageTime,
                            let time2 = contact2.lastMessageTime else {
                        return false
                    }
                    return time1 > time2
                }
                
                DispatchQueue.main.async {
                    self?.mainScreenView.tableViewContacts.reloadData()
                }
            }
        }

    func didSelectFriend(_ contact: Contact) {
        let chatVC = ChatViewController(contact: contact)
        chatVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(chatVC, animated: true)
    }
}

