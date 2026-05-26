
import SwiftUI

struct OnboardingNotchView: View {
    @Environment(\.openURL) private var openURL

    let step: OnboardingSteps
    let onStepChange: (OnboardingSteps) -> Void
    let onFinish: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            stepContent
            buttons
        }
        .animation(.spring(duration: 0.4), value: step)
        .padding(.horizontal, 35)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .first:
            OnboardingNotchFirstStepView()
        case .second:
            OnboardingNotchSecondStepView()
        case .third:
            OnboardingNotchThirdStepView()
        case .fourth:
            OnboardingNotchFourthStepView()
        }
    }
    
    @ViewBuilder
    private var buttons: some View {
        switch step {
        case .first:
            HStack {
                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    Text(L10n.app("notch.onboarding.exit", fallback: "Exit"))
                        .fontWeight(.medium)
                        .foregroundStyle(.red)
                }
                .buttonStyle(PrimaryButtonStyle(height: 35, backgroundColor: .red.opacity(0.2)))
                
                Spacer()
                
                Button(action: {
                    onStepChange(.second)
                }) {
                    Text(L10n.app("notch.onboarding.continue", fallback: "Continue"))
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(PrimaryButtonStyle(height: 35, backgroundColor: .blue.opacity(0.2)))
            }
            
        case .second:
            HStack {
                Button(action: {
                    guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") else {
                        return
                    }
                    openURL(url)
                    
                }) {
                    Text(L10n.app("notch.onboarding.openSettings", fallback: "Open Settings"))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .buttonStyle(PrimaryButtonStyle(height: 35, backgroundColor: .gray.opacity(0.2)))
                
                Spacer()
                
                Button(action: {
                    onStepChange(.third)
                }) {
                    Text(L10n.app("notch.onboarding.continue", fallback: "Continue"))
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(PrimaryButtonStyle(height: 35, backgroundColor: .blue.opacity(0.2)))
            }
            
        case .third:
            HStack {
                Button(action: {
                    HookInstaller.shared.installAll()
                }) {
                    Text(L10n.app("notch.onboarding.installHooks", fallback: "Install Hooks"))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .buttonStyle(PrimaryButtonStyle(height: 35, backgroundColor: .blue.opacity(0.3)))

                Spacer()

                Button(action: {
                    onStepChange(.fourth)
                }) {
                    Text(L10n.app("notch.onboarding.continue", fallback: "Continue"))
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(PrimaryButtonStyle(height: 35, backgroundColor: .blue.opacity(0.2)))
            }

        case .fourth:
            HStack {
                Button(action: {
                    guard let url = URL(string: "https://t.me/Dynamic_Notch") else {
                        return
                    }
                    openURL(url)
                    onFinish()
                }) {
                    Text(L10n.app("notch.onboarding.openTelegram", fallback: "Open Telegram"))
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                }
                .buttonStyle(PrimaryButtonStyle(height: 35, backgroundColor: .gray.opacity(0.2)))

                Spacer()

                Button(action: {
                    onFinish()
                }) {
                    Text(L10n.app("notch.onboarding.finish", fallback: "Finish"))
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(PrimaryButtonStyle(height: 35, backgroundColor: .blue.opacity(0.2)))
            }
        }
    }
}
