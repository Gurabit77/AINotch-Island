
import Foundation
import Combine

enum FocusEvent: Equatable {
    case FocusOn
    case FocusOff
}

final class FocusViewModel: ObservableObject {
    @Published var focusEvent: FocusEvent? = nil
    
    private let service = FocusService()
    
    init() {
        service.onEvent = { [weak self] event in
            self?.focusEvent = event
        }
        service.start()
    }
}
