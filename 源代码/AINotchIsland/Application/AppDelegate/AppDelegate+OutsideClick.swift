import SwiftUI
import Combine

extension AppDelegate {
    func observeOutsideClickDismissal() {
        notchViewModel.$notchModel
            .map(\.isLiveActivityExpanded)
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }

                if isEnabled {
                    startOutsideClickMonitoring()
                } else {
                    stopOutsideClickMonitoring()
                }
            }
            .store(in: &cancellables)
    }

    func startOutsideClickMonitoring() {
        if localClickMonitor == nil {
            localClickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                let sourceWindow = event.window
                let screenLocation =
                    sourceWindow?.convertPoint(toScreen: event.locationInWindow) ??
                    NSEvent.mouseLocation

                Task { @MainActor [weak self] in
                    self?.handleLocalClick(from: sourceWindow, atScreenLocation: screenLocation)
                }

                return event
            }
        }

        globalClickMonitor.start { [weak self] _ in
            let screenLocation = NSEvent.mouseLocation
            Task { @MainActor [weak self] in
                self?.handleGlobalClick(atScreenLocation: screenLocation)
            }
        }

        startHoverCollapseMonitoringIfNeeded()
    }

    func stopOutsideClickMonitoring() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
        }

        localClickMonitor = nil
        globalClickMonitor.stop()
        stopHoverCollapseMonitoring()
    }

    @MainActor
    func handleLocalClick(from sourceWindow: NSWindow?, atScreenLocation screenLocation: NSPoint) {
        guard shouldHandleOutsideClick else { return }

        if sourceWindow === window { return }

        guard let activeNotchScreenRect else {
            notchViewModel.handleOutsideClick()
            return
        }

        guard !activeNotchScreenRect.contains(screenLocation) else { return }

        notchViewModel.handleOutsideClick()
    }

    @MainActor
    func handleGlobalClick(atScreenLocation screenLocation: NSPoint) {
        guard shouldHandleOutsideClick else { return }
        guard let activeNotchScreenRect else {
            notchViewModel.handleOutsideClick()
            return
        }

        guard !activeNotchScreenRect.contains(screenLocation) else { return }
        notchViewModel.handleOutsideClick()
    }

    @MainActor
    var shouldHandleOutsideClick: Bool {
        notchViewModel.notchModel.isLiveActivityExpanded
    }

    @MainActor
    var activeNotchScreenRect: CGRect? {
        guard let window else { return nil }

        let notchSize = notchViewModel.notchModel.size
        guard notchSize.width > 0, notchSize.height > 0 else { return nil }

        let origin = CGPoint(
            x: floor(window.frame.midX - notchSize.width / 2),
            y: window.frame.maxY - notchSize.height
        )

        return CGRect(origin: origin, size: notchSize).insetBy(dx: -12, dy: -8)
    }

    // MARK: - Hover Collapse Monitoring

    var isHoverExpandInteractionConfigured: Bool {
        settingsViewModel.isNotchTapToExpandEnabled &&
        settingsViewModel.notchExpandInteraction == .hover
    }

    func startHoverCollapseMonitoringIfNeeded() {
        guard isHoverExpandInteractionConfigured else { return }

        if localHoverMonitor == nil {
            localHoverMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleMouseMoveForHoverCollapse()
                }
                return event
            }
        }

        if globalHoverMonitor == nil {
            globalHoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleMouseMoveForHoverCollapse()
                }
            }
        }
    }

    func stopHoverCollapseMonitoring() {
        if let localHoverMonitor {
            NSEvent.removeMonitor(localHoverMonitor)
        }
        localHoverMonitor = nil

        if let globalHoverMonitor {
            NSEvent.removeMonitor(globalHoverMonitor)
        }
        globalHoverMonitor = nil

        hoverCollapseWorkItem?.cancel()
        hoverCollapseWorkItem = nil
    }

    @MainActor
    func handleMouseMoveForHoverCollapse() {
        guard notchViewModel.notchModel.isLiveActivityExpanded,
              isHoverExpandInteractionConfigured else {
            hoverCollapseWorkItem?.cancel()
            hoverCollapseWorkItem = nil
            return
        }

        let mouseLocation = NSEvent.mouseLocation

        if let rect = activeNotchScreenRect, rect.contains(mouseLocation) {
            hoverCollapseWorkItem?.cancel()
            hoverCollapseWorkItem = nil
        } else if hoverCollapseWorkItem == nil {
            let workItem = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.hoverCollapseWorkItem = nil

                    guard self.notchViewModel.notchModel.isLiveActivityExpanded,
                          self.isHoverExpandInteractionConfigured else { return }

                    let currentLocation = NSEvent.mouseLocation
                    if let rect = self.activeNotchScreenRect, rect.contains(currentLocation) {
                        return
                    }

                    self.notchViewModel.handleOutsideClick()
                }
            }

            hoverCollapseWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
        }
    }
}
