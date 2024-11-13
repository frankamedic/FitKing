import SwiftUI

struct ToastView: View {
    let message: String
    
    var body: some View {
        Text(message)
            .padding()
            .background(Color(.systemBackground))
            .foregroundColor(.primary)
            .cornerRadius(10)
            .shadow(radius: 5)
            .padding(.horizontal)
    }
} 