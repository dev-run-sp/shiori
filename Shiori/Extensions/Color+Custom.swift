import SwiftUI

extension Color {
    static let customBackground = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 36/255, green: 36/255, blue: 36/255, alpha: 1)
        default:
            return .systemBackground
        }
    })
    
    static let textFieldBackground = Color(UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 46/255, green: 46/255, blue: 46/255, alpha: 1)
        default:
            return .systemBackground
        }
    })
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(10)
            .background(Color.textFieldBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}
