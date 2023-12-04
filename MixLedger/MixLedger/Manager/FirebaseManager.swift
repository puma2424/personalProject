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
    
    var accountListener: ListenerRegistration?
    
    var userMessageListener: ListenerRegistration?
    
    // MARK: - 發送訊息 -
    func postMessage(toUserID: String, 
                     textToOtherUser: String,
                     textToMyself: String,
                     isDunningLetter: Bool, 
                     amount: Double,
                     fromAccoundID: String,
                     fromAccoundName: String, 
                     completion: @escaping (Result<String,Error>) -> Void){
        
        
        let message: [String : Any] = ["toSenderMessage": textToMyself,
                                       "toReceiverMessage": textToOtherUser,
                                       "fromUserID" : saveData.myInfo?.userID,
                                       "toUserID": toUserID,
                                       "isDunningLetter": isDunningLetter,
                                       "amount": amount,
                                       "formAccoundID": fromAccoundID,
                                       "fromAccoundName": fromAccoundName]
        
        db.collection("users").document(toUserID).updateData([
            "message": FieldValue.arrayUnion([message])
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
                completion(.failure(err))
            } else {
                if let myInfo = self.saveData.myInfo{
                    self.db.collection("users").document(myInfo.userID).updateData([
                        "message": FieldValue.arrayUnion([message])
                    ]) { err in
                        if let err = err {
                            print("Error updating document: \(err)")
                            completion(.failure(err))
                        } else {
                            completion(.success(""))
                        }
                    }
                }
            }
        }
    }
    
    // swiftlint:disable line_length
    // MARK: - 確認還款 -
    func confirmPayment(messageInfo: Message, textToOtherUser: String, textToMyself: String, completion: @escaping (Result<String,Error>) -> Void) {
        guard let accountID = saveData.myInfo?.ownAccount else {return}
        var othetUserAccountID: String = ""
        getUsreInfo(userID: [messageInfo.toUserID]){result in
            switch result{
            case .success(let data):
                othetUserAccountID = data[0].ownAccount
            case .failure(_):
                return
            }
        }
        guard let myInfo = self.saveData.myInfo else{return/*completion(.failure(_))*/}
        print(othetUserAccountID)
        
        let postTransactionToExpenses = Transaction(transactionType: TransactionType(iconName: "", name: TransactionMainType.expenses.text),
                                                    amount: messageInfo.amount, 
                                                    currency: "新台幣", date: Date(),
                                                    from: messageInfo.fromAccoundName,
                                                    note: "",
                                                    subType: TransactionType(iconName: "", name: "付款"))
        
        let postTransactionToShare = Transaction(transactionType: TransactionType(iconName: "", name: TransactionMainType.income.text),
                                                 amount: messageInfo.amount,
                                                 currency: "新台幣",
                                                 date: Date(),
                                                 from: messageInfo.fromAccoundName,
                                                 note: "",
                                                 subType: TransactionType(iconName: "", name: "收支平衡"))
        
        let postTransactionToIncome = Transaction(transactionType: TransactionType(iconName: "", name: TransactionMainType.income.text),
                                                 amount: messageInfo.amount,
                                                 currency: "新台幣",
                                                 date: Date(),
                                                 from: messageInfo.fromAccoundName,
                                                 note: "",
                                                 subType: TransactionType(iconName: "", name: "收款"))
        // 自己的帳本增加收入款項
        self.postIncome(toAccountID: myInfo.ownAccount, transaction: postTransactionToIncome, memberPayMoney: [:], memberShareMoney: [:]){ result in
            switch result{
            case .success(_):
                // 對方的帳本扣款
                self.postData(toAccountID: othetUserAccountID, transaction: postTransactionToExpenses, memberPayMoney: [:], memberShareMoney: [:]){ result in
                    switch result{
                    case .success(_):
                      
                        self.db.collection("users").document(messageInfo.toUserID).updateData([
                            "message": FieldValue.arrayRemove([["toSenderMessage": messageInfo.toSenderMessage,
                                                                "toReceiverMessage": messageInfo.toReceiverMessage,
                                                                "fromUserID" : messageInfo.fromUserID,
                                                                "toUserID": messageInfo.toUserID,
                                                                "isDunningLetter": messageInfo.isDunningLetter,
                                                                "amount": messageInfo.amount,
                                                                "formAccoundID": messageInfo.formAccoundID,
                                                                "fromAccoundName": messageInfo.fromAccoundName]]),
                        ]) { err in
                            if let err = err {
                                print("Error updating document: \(err)")
                                completion(.failure(err))
                            } else {
                                print("Document successfully updated postAgareShareAccount")
                                completion(.success("成功變動使用者擁有帳本資訊"))
                            }
                        }
                      
                        
                        self.postIncome(toAccountID: messageInfo.formAccoundID, transaction: postTransactionToShare, memberPayMoney: [messageInfo.fromUserID : messageInfo.amount], memberShareMoney: [messageInfo.toUserID : messageInfo.amount]){ _ in
                        return}
                        
                    case .failure(_):
                        return
                    }
                }
                return
            case .failure(_):
                return
            }
            
        }
        
        
        
        
        
        // 發送訊息
    }
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
                self.db.collection("users").document(self.saveData.myID).updateData([
                    "inviteCard": FieldValue.arrayRemove([["accountID": accountID, 
                                                           "inviterID": inviterID,
                                                           "inviterName": inviterName,
                                                           "accountName": accountName]]),
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
        guard let myID = saveData.myInfo?.userID else {return}
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

    // MARK: - 發送共享帳簿的邀請 -
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

    // MARK: - 新增新帳本 -
    func addNewAccount(name: String, budget: Double? = 0, iconName: String) {
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
    
    func aaaa(toAccountID: String,
              transaction: Transaction,
              memberPayMoney: [String: Double],
              memberShareMoney: [String: Double],
              accountInfo: TransactionsResponse,
              completion: @escaping (Result<Any, Error>) -> Void){
        var account = accountInfo
        
        for id in memberPayMoney.keys {
            if let index = accountInfo.shareUsersID?.firstIndex(where: { $0.keys.contains(id) }),
               var userDictionary = accountInfo.shareUsersID?[index]
            {
                // 找到需要增量的鍵
//                if let keyIndex = userDictionary.keys.firstIndex(of: id) {

                guard let payMoney = memberPayMoney[id] else { return }
                guard let shareMoney = memberShareMoney[id] else { return }
                // 使用 FieldValue.increment 增量值
                print(userDictionary)
                userDictionary[id] = (userDictionary[id] ?? 0.0) - shareMoney + payMoney

                // 更新字典
                account.shareUsersID?[index] = userDictionary
                print("找到的索引為 \(index)")
                print(id)
                print(userDictionary)
//                }
            }
            print(account.shareUsersID)
        }
        let postTransaction: [String: Any] = [
            "amount": transaction.amount,
            "date": transaction.date,
            "payUser": memberPayMoney,
            "shareUser": memberShareMoney,
            "note": transaction.note,
            "transactionType": ["iconName": transaction.transactionType.iconName, "name": transaction.transactionType.name],
            "subType": ["iconName": transaction.subType.iconName, "name": transaction.subType.name],
            "currency": "新台幣",
            "from": ""
        ]
//        let expense = ((saveData.accountData?.accountInfo.expense) ?? 0) - amount
//        let total = ((saveData.accountData?.accountInfo.total) ?? 0) - amount
//        print(expense)
        self.dateFont.dateFormat = "yyyy-MM"
        let dateM = dateFont.string(from: transaction.date)
        self.dateFont.dateFormat = "yyyy-MM-dd"
        let dateD = dateFont.string(from: transaction.date)

        db.collection("accounts").document(toAccountID).updateData([
            "transactions.\(dateM).\(dateD).\(Date())": postTransaction,
            "shareUsersID": account.shareUsersID,
            "accountInfo.income": FieldValue.increment(transaction.amount),
            "accountInfo.total": FieldValue.increment(transaction.amount),
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
            } else {
                print("Document successfully updated")
                completion(.success("Sent successfully"))
            }
        }
//
    }
    
    // swiftlint:disable line_length
    func postIncome(toAccountID: String, 
                    transaction: Transaction,
                    memberPayMoney: [String: Double],
                    memberShareMoney: [String: Double],
                    completion: @escaping (Result<Any, Error>) -> Void){
//
        
        if toAccountID != saveData.accountData?.accountID{
            getAccountData(accountID: toAccountID){ result in
                switch result{
                case .success(let accountData):
                    //                    accountInfo = accountData
                    self.aaaa(toAccountID: toAccountID,
                              transaction: transaction,
                              memberPayMoney: memberPayMoney,
                              memberShareMoney: memberShareMoney,
                              accountInfo: accountData){ result in
                        switch result{
                        case .success(_):
                            completion(.success(""))
                        case .failure(_):
                            return
                        }
                        
                    }
                case .failure(_):
                    return
                }
                
            }
        }else{
            guard let accountInfo: TransactionsResponse = saveData.accountData else{return}
            self.aaaa(toAccountID: toAccountID,
                      transaction: transaction,
                      memberPayMoney: memberPayMoney,
                      memberShareMoney: memberShareMoney,
                      accountInfo: accountInfo){ result in
                switch result{
                case .success(_):
                    completion(.success(""))
                case .failure(_):
                    return
                }
                
            }
        }
        
//        for id in memberPayMoney.keys {
//            if let index = accountInfo?.shareUsersID?.firstIndex(where: { $0.keys.contains(id) }),
//               var userDictionary = accountInfo?.shareUsersID?[index]
//            {
//                // 找到需要增量的鍵
////                if let keyIndex = userDictionary.keys.firstIndex(of: id) {
//
//                guard let payMoney = memberPayMoney[id] else { return }
//                guard let shareMoney = memberShareMoney[id] else { return }
//                // 使用 FieldValue.increment 增量值
//                print(userDictionary)
//                userDictionary[id] = (userDictionary[id] ?? 0.0) - shareMoney + payMoney
//
//                // 更新字典
//                accountInfo?.shareUsersID?[index] = userDictionary
//                print("找到的索引為 \(index)")
//                print(id)
//                print(userDictionary)
////                }
//            }
////            print(saveData.accountData?.shareUsersID)
//        }
//        let postTransaction: [String: Any] = [
//            "amount": transaction.amount,
//            "date": transaction.date,
//            "payUser": memberPayMoney,
//            "shareUser": memberShareMoney,
//            "note": transaction.note,
//            "transactionType": ["iconName": transaction.transactionType.iconName, "name": transaction.transactionType.name],
//            "subType": ["iconName": transaction.subType.iconName, "name": transaction.subType.name],
//            "currency": "新台幣",
//            "from": ""
//        ]
////        let expense = ((saveData.accountData?.accountInfo.expense) ?? 0) - amount
////        let total = ((saveData.accountData?.accountInfo.total) ?? 0) - amount
////        print(expense)
//        self.dateFont.dateFormat = "yyyy-MM"
//        let dateM = dateFont.string(from: transaction.date)
//        self.dateFont.dateFormat = "yyyy-MM-dd"
//        let dateD = dateFont.string(from: transaction.date)
//
//        db.collection("accounts").document(toAccountID).updateData([
//            "transactions.\(dateM).\(dateD).\(Date())": postTransaction,
//            "shareUsersID": accountInfo?.shareUsersID,
//            "accountInfo.income": FieldValue.increment(transaction.amount),
//            "accountInfo.total": FieldValue.increment(transaction.amount),
//        ]) { err in
//            if let err = err {
//                print("Error updating document: \(err)")
//            } else {
//                print("Document successfully updated")
//                completion(.success("Sent successfully"))
//            }
//        }
////        
    }

    // MARK: - 記帳 -
    
    func postData(toAccountID: String, 
                  transaction: Transaction,
                  memberPayMoney: [String: Double],
                  memberShareMoney: [String: Double],
                  completion: @escaping (Result<Any, Error>) -> Void) {
        print(saveData.accountData?.shareUsersID)
        for id in memberPayMoney.keys {
            if let index = saveData.accountData?.shareUsersID?.firstIndex(where: { $0.keys.contains(id) }),
               var userDictionary = saveData.accountData?.shareUsersID?[index]
            {
                guard let payMoney = memberPayMoney[id] else { return }
                guard let shareMoney = memberShareMoney[id] else { return }
                
                print(userDictionary)
                userDictionary[id] = (userDictionary[id] ?? 0.0) - shareMoney + payMoney

                // 更新字典
                saveData.accountData?.shareUsersID?[index] = userDictionary
                print("找到的索引為 \(index)")
                print(id)
                print(userDictionary)
            }
        }
        print(saveData.accountData?.shareUsersID)

        let postTransaction: [String: Any] = [
            "amount": transaction.amount,
            "date": transaction.date,
            "payUser": memberPayMoney,
            "shareUser": memberShareMoney,
            "note": transaction.note,
            "transactionType":  ["iconName": transaction.transactionType.iconName, "name": transaction.transactionType.name],
            "subType": ["iconName": transaction.subType.iconName, "name": transaction.subType.name],
            "currency": "新台幣",
            "from": "",
        ]
        dateFont.dateFormat = "yyyy-MM"
        let dateM = dateFont.string(from: transaction.date)
        dateFont.dateFormat = "yyyy-MM-dd"
        let dateD = dateFont.string(from: transaction.date)

        db.collection("accounts").document(toAccountID).updateData([
            "transactions.\(dateM).\(dateD).\(Date())": postTransaction,
            "shareUsersID": saveData.accountData?.shareUsersID,
            "accountInfo.expense": FieldValue.increment(transaction.amount),
            "accountInfo.total": FieldValue.increment(transaction.amount),
        ]) { err in
            if let err = err {
                print("Error updating document: \(err)")
            } else {
                print("Document successfully updated")
                completion(.success("Sent successfully"))
            }
        }

        if saveData.accountData?.accountID != saveData.myInfo?.ownAccount {
            updatePayerAccount(isMyAccount: false, memberPayMoney: memberPayMoney, date: transaction.date, note: transaction.note, type: transaction.subType) { result in
                switch result {
                case .success:
                    print("同步到付費者的個人帳本：成功")
                case let .failure(err):
                    print("同步到付費者的個人帳本：失敗")
                    print(err)
                    print("-----------------------")
                }
            }
        }
    }

    private func updatePayerAccount(isMyAccount: Bool, memberPayMoney: [String: Double], date: Date, note: String?, type: TransactionType?, completion: @escaping (Result<Any, Error>) -> Void) {
        if isMyAccount == false {
            for payerID in memberPayMoney.keys {
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

                let payer = saveData.userInfoData.filter{ $0.userID == payerID }
            
                let payerAccountID = payer[0].ownAccount

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

    // MARK: - 取得帳本資料 -
    
    func getAccountData(accountID: String, completion: @escaping (Result<TransactionsResponse, Error>) -> Void) {
        // 從 Firebase 獲取數據
        let docRef = db.collection("accounts").document(accountID)

        docRef.getDocument  { document, error in
            if let error = error as NSError? {
                self.errorMessage = "Error getting document: \(error.localizedDescription)"
            } else {
                if let document = document {
                    do {
                        print("-----get account undecode Data------")
                        print("----\n\(document.data())")
                        let data = try document.data(as: TransactionsResponse.self)
                        print("-----get account decode Data------")
                        completion(.success(data))
                    } catch {
                        print(error)
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    func removeAccountListener(){
        if accountListener != nil{
            accountListener?.remove()
        }
    }
    
    func addAccountListener(accountID: String, completion: @escaping (Result<TransactionsResponse, Error>) -> Void){
        // 從 Firebase 獲取數據
        let docRef = db.collection("accounts").document(accountID)
        
        removeAccountListener()
        
        accountListener = docRef.addSnapshotListener { document, error in
            if let error = error as NSError? {
                self.errorMessage = "Error getting document: \(error.localizedDescription)"
            } else {
                if let document = document {
                    do {
                        print("-----get account undecode Data------")
                        let accountData = try document.data(as: TransactionsResponse.self)
                        print("-----get account decode Data------")
                        self.saveData.accountData = accountData
                        print("\(self.saveData.accountData?.accountName)")
                        completion(.success(accountData))
                    } catch {
                        print(error)
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    func getUsreInfo(userID: [String], completion: @escaping (Result<[UsersInfoResponse], Error>) -> Void) {
        if !userID.isEmpty {
            var responData: [UsersInfoResponse] = []

            db.collection("users").whereField("userID", in: userID).getDocuments() { (querySnapshot, err) in
                do {
                    if let err = err {
                      print("Error getting documents: \(err)")
                        throw err
                    } else {
                      for document in querySnapshot!.documents {
                          let responseData = try document.data(as: UsersInfoResponse.self)
                          responData.append(responseData)
                      }
                        completion(.success(responData))
                    }
                } catch {
                    print(error)
                    
                }

              }

        }
        print("\(saveData.userInfoData)")
    }
    
    func removeUserMessageListener(){
        userMessageListener?.remove()
    }
    
    func addUserMessageListener(userID: String, completion: @escaping (Result<UsersInfoResponse, Error>) -> Void) {
        
        removeUserMessageListener()
        
        if !userID.isEmpty {
                let docRef = db.collection("users").document(userID)

                userMessageListener = docRef.addSnapshotListener { document, error in
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
                                completion(.success(responseData))
                            } catch {
                                print(error)
                                completion(.failure(error))
                            }
                        }
                        
                    }
                }
            
        }
        print("\(saveData.userInfoData)")
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


