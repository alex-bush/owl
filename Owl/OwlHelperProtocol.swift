import Foundation

@objc protocol OwlHelperProtocol {
    func setSleepDisabled(_ disabled: Bool, withReply reply: @escaping (Bool, String?) -> Void)
}
