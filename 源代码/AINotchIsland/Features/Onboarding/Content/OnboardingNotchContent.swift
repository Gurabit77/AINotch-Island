
import SwiftUI

enum OnboardingEvent: Equatable {
    case onboarding
}

struct OnboardingNotchContent : NotchContentProtocol {
    let id: String
    
    let stackID = OnboardingSteps.stackID
    let step: OnboardingSteps
    let notchEventCoordinator: NotchEventCoordinator
    
    var priority: Int { NotchContentRegistry.Onboarding.priority }
    
    init(step: OnboardingSteps, notchEventCoordinator: NotchEventCoordinator) {
        self.id = step.liveActivityID
        self.step = step
        self.notchEventCoordinator = notchEventCoordinator
    }
    
    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize {
        step.notchSize(baseWidth: baseWidth, baseHeight: baseHeight)
    }
    
    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        return (top: 24, bottom: 36)
    }
    
    @MainActor
    func makeView() -> AnyView {
        AnyView(
            OnboardingNotchView(
                step: step,
                onStepChange: { nextStep in
                    notchEventCoordinator.showOnboarding(step: nextStep)
                },
                onFinish: {
                    notchEventCoordinator.finishOnboarding()
                }
            )
        )
    }
}
