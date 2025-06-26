//
//  ContentView.swift
//  ConferenceCameraSwitch
//
//  Created by Ahmad Shaheer on 25/06/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var textInput: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Add your text below:")
                .foregroundStyle(.secondary)
            TextEditor(text: $textInput)
                .padding(.vertical, 4)
                .scrollContentBackground(.hidden)
                .background(.thinMaterial)
            Button(
                "Copy uppercased result",
                systemImage: "square.on.square"
            ) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(
                    textInput.uppercased(),
                    forType: .string
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .bold()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
