//
//  BoringExtrasMenu.swift
//  boringNotch
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import Defaults
import SwiftUI

struct BoringLargeButtons: View {
    var action: () -> Void
    var icon: Image
    var title: String
    @Default(.notchTheme) private var notchTheme

    var body: some View {
        Button (
            action:action,
            label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 12.0)
                        .fill(notchTheme.buttonBackground)
                        .frame(width: 70, height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12.0)
                                .stroke(notchTheme.secondaryForeground.opacity(0.16), lineWidth: 1)
                        )
                    VStack(spacing: 8) {
                        icon.resizable()
                            .aspectRatio(contentMode: .fit).frame(width:20)
                        Text(title).font(.body)
                    }
                    .foregroundStyle(notchTheme.primaryForeground)
                }
            }).buttonStyle(PlainButtonStyle()).shadow(color: notchTheme.shadow, radius: 10)
    }
}

struct BoringExtrasMenu : View {
    @ObservedObject var vm: BoringViewModel
    @Default(.notchTheme) private var notchTheme
    
    var body: some View {
        VStack{
            HStack(spacing: 20)  {
                hide
                settings
                close
            }
        }
    }
    
    var github: some View {
        BoringLargeButtons(
            action: {
                NSWorkspace.shared.open(MinitapBrand.websiteURL)
            },
            icon: Image("logo2"),
            title: "Website"
        )
    }
    
    var settings: some View {
        Button(action: {
            DispatchQueue.main.async {
                SettingsWindowController.shared.showWindow()
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12.0)
                    .fill(notchTheme.buttonBackground)
                    .frame(width: 70, height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12.0)
                            .stroke(notchTheme.secondaryForeground.opacity(0.16), lineWidth: 1)
                    )
                VStack(spacing: 8) {
                    Image(systemName: "gear").resizable()
                        .aspectRatio(contentMode: .fit).frame(width:20)
                    Text("Settings").font(.body)
                }
                .foregroundStyle(notchTheme.primaryForeground)
            }
        }
        .buttonStyle(PlainButtonStyle()).shadow(color: notchTheme.shadow, radius: 10)
    }
    
    var hide: some View {
        BoringLargeButtons(
            action: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    //vm.openMusic()
                }
            },
            icon: Image(systemName: "arrow.down.forward.and.arrow.up.backward"),
            title: "Hide"
        )
    }
    
    var close: some View {
        BoringLargeButtons(
            action: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        NSApp.terminate(nil)
                    }
                }
            },
            icon: Image(systemName: "xmark"),
            title: "Exit"
        )
    }
}


#Preview {
    BoringExtrasMenu(vm: .init())
}
