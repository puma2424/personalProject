//
//  FirebaseManager.swift
//  MixLedger
//
//  Created by 莊羚羊 on 2023/11/18.
//

import FirebaseCore
import FirebaseFirestore
import Foundation

class FirebaseManager {
    static let shared = FirebaseManager()

    let db = Firestore.firestore()

    let saveData = SaveData.shared

    @Published var errorMessage: String?

    let dateFont = DateFormatter()

//
//    let accountInfo = ["accountID": "HbS5e81PWHRY41A8nBwl",
//                    "accountName": "去嘉義玩",
//                       "shareUsersID": ["users":[["userID":"QJeplpxVXBca5xhXWgbT","unbalance" : 0.0],
//                            ["userID":"bGzuwR00sPRNmBamK91D","unbalance" : 0.0]
//                           ]],
//                       "accountInfo": ["total": 100.0, "expense": 300.0, "income": 600.0, "budget": 1000.0]
//                    "transaction.\(Date())":[]
//    ] as [String : Any]

    // MARK: - 回覆共享帳簿的邀請 -

    // 回覆共享帳簿的邀請
    func postRespondToInvitation(respond: Bool, accountID: String, accountName: String, inviterID: String, inviterName: String, completion: @escaping (Result<String, Error>) -> Void) {
        if respond {
            postAgareShareAccount(accountID: accountID, accountName: accountName, inviterID: inviterID, inviterName: inviterName) { result in
                switch result {
                case let .success(response):
                    print("\(response)---------")
                    completion(.success("成功加入帳本"))
                case let .failure(err):
                    print("---------\n postAgareShareAccount failure\n\(err)\n --------")
                    completion(.failure(err))
                }
            }
        } else {
            postAdjectShareAccount(accountID: accountID, accountName: accountName, inviterID: inviterID, inviterName: inviterName) { result in
                switch result {
                case let .success(response):
                    print("\(response)---------")
                    completion(.success("成功加入帳本"))
                case let .failure(err):
                    print("---------\n postAgareShareAccount failure\n\(err)\n --------")
                    completion(.failure(err))
                }
            }
        }
    }

    // 同意邀請
    private func postAgareShareAccount(accountID: String, accountName: String, inviterID: String, inviterName: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let myInfo = saveData.myInfo else { return }

        db.collection("accounts").document(accountID).updateData([
            "shareUsersID": FieldValue.arrayUnion([[myInfo.userID: 0.0]]),
            "invitees": FieldValue.arrayRemove([myInfo.userID]),
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
                completion(.failure(err))
            } else {
                completion(.success("成功變更帳本的共享者資訊"))
                print("Document successfully updated postAgareShareAccount")
                self.db.collection("users").document(myID).updateData([
                    "inviteCard": FieldValue.arrayRemove([["accountID": accountID, "inviterID": inviterID, "inviterName": inviterName, "accountName": accountName]]),
                    "shareAccount": FieldValue.arrayUnion([accountID]),
                ]) { err in
                    if let err = err {
                        print("Error updating document: \(err)")
                        completion(.failure(err))
                    } else {
                        print("Document successfully updated postAgareShareAccount")
                        completion(.success("成功變動使用者擁有帳本資訊"))
                    }
                }
            }
        }
    }

    // 拒絕邀請
    private func postAdjectShareAccount(accountID: String, accountName: String, inviterID: String, inviterName: String, completion: @escaping (Result<String, Error>) -> Void) {
        db.collection("accounts").document(accountID).updateData([
            "invitees": FieldValue.arrayRemove([myID]),
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
                completion(.failure(err))
            } else {
                completion(.success("成功變更帳本的共享者資訊"))
                print("Document successfully updated postAgareShareAccount")
                self.db.collection("users").document(myID).updateData([
                    "inviteCard": FieldValue.arrayRemove([["accountID": accountID, "inviterID": inviterID, "inviterName": inviterName, "accountName": accountName]]),
                ]) { err in
                    if let err = err {
                        print("Error updating document: \(err)")
                        completion(.failure(err))
                    } else {
                        print("Document successfully updated postAgareShareAccount")
                        completion(.success("成功變動使用者擁有帳本資訊"))
                    }
                }
            }
        }
    }

    private func postShareAccountToInivitee(inviteeID: String, shareAccountID: String) {
        guard let myName = saveData.myInfo?.name else { return print("no myName") }
        guard let accountName = saveData.accountData?.accountName else { return print("no accountName") }
        db.collection("users").document(inviteeID).updateData([
            "inviteCard": FieldValue.arrayUnion([["accountID": shareAccountID, "inviterID": saveData.myInfo?.userID, "inviterName": myName, "accountName": accountName]]),
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
            } else {
                print("Document successfully updated postShareAccountToInivitee")
            }
        }
    }

    // 發送共享帳簿的邀請
    func postShareAccountInivite(inviteeID: String, shareAccountID: String, shareAccountName _: String, inviterName _: String, completion _: @escaping (Result<[UsersInfoResponse], Error>) -> Void) {
        db.collection("accounts").document(shareAccountID).updateData([
            "invitees": FieldValue.arrayUnion([inviteeID]),
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
            } else {
                print("Document successfully updated")
                self.postShareAccountToInivitee(inviteeID: inviteeID, shareAccountID: shareAccountID)
            }
        }
    }

    func getAllUser(completion: @escaping (Result<[UsersInfoResponse], Error>) -> Void) {
        db.collection("users").getDocuments { querySnapshot, err in
            var responeArray: [UsersInfoResponse] = []
            if let err = err {
                print("Error getting documents: \(err)")
            } else {
                for document in querySnapshot!.documents {
                    print("\(document.documentID) => \(document.data())")
                    do {
                        // print("----\n\(document.data())")
                        let data = try document.data(as: UsersInfoResponse.self)
                        responeArray.append(data)

                    } catch {
                        print(error)
                        completion(.failure(error))
                    }
                }
                completion(.success(responeArray))
            }
        }
    }

    func addNewAccount(name: String, budget _: Double? = 0, iconName: String) {
        let newAccount = db.collection("account").document()
        guard let myInfo = saveData.myInfo else { return }
        let sharesID = [[myInfo.userID: 0.0]]
        let accountInfo = AccountInfo(budget: 0, expense: 0, income: 0, total: 0)
        let newAccountInfo = TransactionsResponse(accountID: newAccount.documentID, accountInfo: accountInfo, accountName: name, shareUsersID: sharesID, iconName: iconName)

        do {
            try db.collection("accounts").document(newAccount.documentID).setData(from: newAccountInfo) { err in
                if let err = err {
                    print("Error writing document: \(err)")
                } else {
                    self.db.collection("users").document(myInfo.userID).updateData([
                        "shareAccount": FieldValue.arrayUnion([newAccount.documentID]),
                    ])
                    print("Document successfully written!")
                }
            }
        } catch {
            print("Error writing city to Firestore: \(error)")
        }
    }

    // swiftlint:disable line_length
    func postData(toAccountID: String, amount: Double, date: Date, note: String?, type: TransactionType, memberPayMoney: [String: Double], memberShareMoney: [String: Double], completion: @escaping (Result<Any, Error>) -> Void) {
        print(saveData.accountData?.shareUsersID)
        for id in memberPayMoney.keys {
            if let index = saveData.accountData?.shareUsersID?.firstIndex(where: { $0.keys.contains(id) }),
               var userDictionary = saveData.accountData?.shareUsersID?[index]
            {
                // 找到需要增量的鍵
//                if let keyIndex = userDictionary.keys.firstIndex(of: id) {

                guard let payMoney = memberPayMoney[id] else { return }
                guard let shareMoney = memberShareMoney[id] else { return }
                // 使用 FieldValue.increment 增量值
                print(userDictionary)
                userDictionary[id] = (userDictionary[id] ?? 0.0) - shareMoney + payMoney

                // 更新字典
                saveData.accountData?.shareUsersID?[index] = userDictionary
                print("找到的索引為 \(index)")
                print(id)
                print(userDictionary)
//                }
            }
//            print(saveData.accountData?.shareUsersID)
        }
        print(saveData.accountData?.shareUsersID)

        let transaction = [
            "amount": amount,
            "date": date,
            "payUser": memberPayMoney,
            "shareUser": memberShareMoney,
            "note": note,
            "type": ["iconName": type.iconName, "name": type.name],
            "currency": "新台幣",
            "from": "",
        ] as [String: Any]
//        let expense = ((saveData.accountData?.accountInfo.expense) ?? 0) - amount
//        let total = ((saveData.accountData?.accountInfo.total) ?? 0) - amount
//        print(expense)
        dateFont.dateFormat = "yyyy-MM"
        let dateM = dateFont.string(from: date)
        dateFont.dateFormat = "yyyy-MM-dd"
        let dateD = dateFont.string(from: date)

        db.collection("accounts").document(toAccountID).updateData([
            "transactions.\(dateM).\(dateD).\(Date())": transaction,
            "shareUsersID": saveData.accountData?.shareUsersID,
            "accountInfo.expense": FieldValue.increment(amount),
            "accountInfo.total": FieldValue.increment(amount),
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
            } else {
                print("Document successfully updated")
                completion(.success("Sent successfully"))
            }
        }
        
        if saveData.accountData?.accountID != saveData.myInfo?.ownAccount{
            updatePayerAccount(isMyAccount: false, memberPayMoney: memberPayMoney, date: date, note: note, type: type){result in
                switch result{
                case .success(_):
                    print("同步到付費者的個人帳本：成功")
                case .failure(let err):
                    print("同步到付費者的個人帳本：失敗")
                    print(err)
                    print("-----------------------")
                }
            }
        }
    }
    
    private func updatePayerAccount(isMyAccount: Bool, memberPayMoney: [String: Double], date: Date, note: String?, type: TransactionType?, completion: @escaping (Result<Any, Error>) -> Void){
        if isMyAccount == false{
            for payerID in memberPayMoney.keys{
                guard let amount = memberPayMoney[payerID] else { return }
                let transaction = [
                    "amount": amount,
                    "date": date,
                    "note": note,
                    "type": ["iconName": type?.iconName, "name": type?.name],
                    "currency": "新台幣",
                    "from": "\(saveData.accountData?.accountName)",
                ] as [String: Any]
                
                dateFont.dateFormat = "yyyy-MM"
                let dateM = dateFont.string(from: date)
                dateFont.dateFormat = "yyyy-MM-dd"
                let dateD = dateFont.string(from: date)
                
                guard let payerAccountID = saveData.userInfoData[payerID]?.ownAccount else{return}
                
                db.collection("accounts").document(payerAccountID).updateData([
                    "transactions.\(dateM).\(dateD).\(Date())": transaction,
                    "accountInfo.expense": FieldValue.increment(amount),
                    "accountInfo.total": FieldValue.increment(amount),
                ]) { err in
                    if let err = err {
                        print("Error updating document: \(err)")
                        completion(.failure(err))
                    } else {
                        print("Document successfully updated")
                        completion(.success("Sent successfully"))
                    }
                }
                
            }
        }
    }

    // swiftlint:enable line_length

    func getData(accountID: String, completion: @escaping (Result<Any, Error>) -> Void) {
        // 從 Firebase 獲取數據
        let docRef = db.collection("accounts").document(accountID)

        docRef.addSnapshotListener { document, error in
            if let error = error as NSError? {
                self.errorMessage = "Error getting document: \(error.localizedDescription)"
            } else {
                if let document = document {
                    do {
                        print("-----get account undecode Data------")
                        print("----\n\(document.data())")
                        self.saveData.accountData = try document.data(as: TransactionsResponse.self)
                        print("-----get account decode Data------")
                        print("\(self.saveData.accountData?.accountName)")
                        completion(.success(self.saveData.accountData))
                    } catch {
                        print(error)
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    func findUser(userID: [String], completion: @escaping (Result<[String: UsersInfoResponse], Error>) -> Void) {
        if !userID.isEmpty {
            for id in userID {
                let docRef = db.collection("users").document(id)

                docRef.addSnapshotListener { document, error in
                    if let error = error as NSError? {
                        self.errorMessage = "Error getting document: \(error.localizedDescription)"
                        completion(.failure(error))
                    } else {
                        if let document = document {
                            print("-----find User------")
                            print(document.data())
                            do {
                                let responseData = try document.data(as: UsersInfoResponse.self)
                                print(responseData)
                                completion(.success([id: responseData]))
                            } catch {
                                print(error)
                                completion(.failure(error))
                            }
                        }
                    }
                }
            }
        }
        print("\(saveData.userInfoData)")
//        completion(.success(saveData.userInfoData))
    }

    func findAccount(account: [String], completion: @escaping (Result<Any, Error>) -> Void) {
        print("-------account array---------")
        print(account)

        let docRef = db.collection("accounts")
        if !account.isEmpty {
            docRef.whereField("accountID", in: account).getDocuments { querySnapshot, err in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    if let querySnapshot = querySnapshot {
                        for document in querySnapshot.documents {
                            //                print("\(document.documentID) => \(document.data())")
                            print(document.data()["accountName"])
                            if let id = document.data()["accountID"] as? String /* , let name = [document.data()["accountName"]] as? String */ {
                                self.saveData.myShareAccount[id] = document.data()["accountName"] as? String
                            } else {
                                print(document.data()["accountID"])
                                print(document.data()["accountName"])
                            }
                        }
                    }
                    completion(.success("success"))
                }
                print(self.saveData.myShareAccount)
            }
        }
    }

    // MARK: - 如果用子集合的寫法

    func getDate2() {
        // 從 Firebase 獲取數據
        let docRef = db.collection("accounts").document("SUyJNUlNOAI26DREgF0T").collection("")

        docRef.getDocuments { querySnapshot, error in
            if let error = error {
                print("Error getting subcollection documents: \(error.localizedDescription)")
            } else {
                for document in querySnapshot!.documents {
                    do {
                        // 解析子集合的每個文件的數據
                        let transactionData = try document.data(as: TransactionsResponse.self)
                        print("Transaction Data: \(transactionData)")
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }

    func postData2() {
//        dateFont.dateFormat = "yyyy-MM"
//        let dateM = dateFont.string(from: date)
//        dateFont.dateFormat = "yyyy-MM-dd"
//        let dateD = dateFont.string(from: date)

        let docRef = db.collection("accounts").document("SUyJNUlNOAI26DREgF0T").collection("transactions")

//        docRef.document(dateM).updateData([dateM:transaction])
    }
}

struct TransactionsResponse: Codable {
    var transactions: [String: [String: [String: Transaction]]]?
    var accountID: String
    var accountInfo: AccountInfo
    var accountName: String
    var shareUsersID: [[String: Double]]?
    var iconName: String?
}

struct AccountInfo: Codable {
    var budget: Double
    var expense: Double
    var income: Double
    var total: Double
}

// struct ShareUsers: Codable {
//    var unbalance: Double
//    var userID: String
// }

// struct ShareUsers: Codable {
//    var users: [ShareUser]
// }
//
// struct ShareUser: Codable {
//    var unbalance: Double
//    var userID: String
// }

struct Transaction: Codable{
//    var id = UUID().uuidString
    
    var year: String?
//    var id = UUID().uuidString
    var amount: Double
    var currency: String
    var date: Date
    var from: String?
    var note: String?
    var payUser: [String: Double]?
    var shareUser: [String: Double]?
    var type: TransactionType
    
    
    init(amount: Double, currency: String, date: Date, from: String?, note: String?, payUser: [String: Double]?, shareUser: [String: Double]?, type: TransactionType, year: String) {
        let dateFont = DateFormatter()
        dateFont.dateFormat = "yyyy"
        let dateString = dateFont.string(from: date)
//        self.id = id
        self.amount = amount
        self.currency = currency
        self.date = date
        self.from = from
        self.note = note
        self.payUser = payUser
        self.shareUser = shareUser
        self.type = type
        self.year = dateString
    }
}

struct TransactionType: Codable {
    var iconName: String
    var name: String
}

struct UsersInfoResponse: Codable {
    var name: String
    var ownAccount: String
    var shareAccount: [String]
    var userID: String
    var inviteCard: [InviteCard]?
}

struct InviteCard: Codable {
    var inviterID: String
    var accountID: String
    var accountName: String
    var inviterName: String
}