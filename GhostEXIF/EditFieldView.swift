import SwiftUI

struct EditFieldView: View {
    let field: MetadataField
    let onCommit: (String) -> Void
    @State private var value: String
    @Environment(\.dismiss) private var dismiss

    init(field: MetadataField, onCommit: @escaping (String) -> Void) {
        self.field = field
        self.onCommit = onCommit
        _value = State(initialValue: field.value)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("MODIFYING_NODE: \(field.name.uppercased())")
                        .matrixText(size: 14, color: Theme.terminalCyan)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TextField("", text: $value)
                        .matrixText(size: 18)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.matrixGreen.opacity(0.5), lineWidth: 1)
                        )

                    Spacer()

                    Button(action: {
                        onCommit(value)
                        dismiss()
                    }) {
                        Text("COMMIT_CHANGES")
                            .matrixText(size: 18)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.matrixGreen.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Theme.matrixGreen.opacity(0.5), lineWidth: 2)
                            )
                    }
                }
                .padding()
            }
            .navigationTitle("DATA_ENTRY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CANCEL") { dismiss() }
                        .matrixText(size: 14, color: Theme.alertAmber)
                }
            }
        }
    }
}
