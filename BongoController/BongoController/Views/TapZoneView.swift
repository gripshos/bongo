import SwiftUI

struct TapZoneView: View {
    var onTapLeft: () -> Void
    var onTapRight: () -> Void
    
    @State private var leftFlash = false
    @State private var rightFlash = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Zone
            ZStack {
                Color.blue.opacity(0.3)
                if leftFlash {
                    Color.white.opacity(0.5)
                }
                Text("LEFT")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle()) // Make entire area tappable
            .onTapGesture {
                onTapLeft()
                triggerFlash(left: true)
            }
            
            // Right Zone
            ZStack {
                Color.red.opacity(0.3)
                if rightFlash {
                    Color.white.opacity(0.5)
                }
                Text("RIGHT")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                onTapRight()
                triggerFlash(left: false)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    func triggerFlash(left: Bool) {
        if left {
            leftFlash = true
            withAnimation(.easeOut(duration: 0.1)) {
                leftFlash = false
            }
        } else {
            rightFlash = true
            withAnimation(.easeOut(duration: 0.1)) {
                rightFlash = false
            }
        }
    }
}
