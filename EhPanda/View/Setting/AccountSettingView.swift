//
//  AccountSettingView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/12.
//

import SwiftUI
import TTProgressHUD

struct AccountSettingView: View {
    @EnvironmentObject private var store: Store
    @State private var inEditMode = false

    @State private var hudVisible = false
    @State private var hudConfig = TTProgressHUDConfig()

    private let ehURL = Defaults.URL.ehentai.safeURL()
    private let exURL = Defaults.URL.exhentai.safeURL()
    private let igneousKey = Defaults.Cookie.igneous
    private let memberIDKey = Defaults.Cookie.ipbMemberId
    private let passHashKey = Defaults.Cookie.ipbPassHash

    // MARK: AccountSettingView
    var body: some View {
        ZStack {
            Form {
                if let settingBinding = settingBinding {
                    Section {
                        Picker(
                            selection: settingBinding.galleryType,
                            label: Text("Gallery"),
                            content: {
                                let galleryTypes: [GalleryType] = [.ehentai, .exhentai]
                                ForEach(galleryTypes, id: \.self) {
                                    Text($0.rawValue.localized())
                                }
                            })
                            .pickerStyle(.segmented)
                        if !didLogin {
                            Button("Login", action: toggleWebViewLogin).withArrow()
                        } else {
                            Button("Logout", action: toggleLogout).foregroundStyle(.red)
                        }
                        if didLogin {
                            Group {
                                Button("Account configuration", action: toggleWebViewConfig).withArrow()
                                Button("Manage tags subscription", action: toggleWebViewMyTags).withArrow()
                                Toggle(
                                    "Show new dawn greeting",
                                    isOn: settingBinding.showNewDawnGreeting
                                )
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                Section(header: Text("E-Hentai")) {
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: memberIDKey,
                        value: ehMemberID,
                        commitAction: onEhEditingChange
                    )
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: passHashKey,
                        value: ehPassHash,
                        commitAction: onEhEditingChange
                    )
                    Button("Copy cookies", action: copyEhCookies)
                }
                Section(header: Text("ExHentai")) {
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: igneousKey,
                        value: igneous,
                        commitAction: onExEditingChange
                    )
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: memberIDKey,
                        value: exMemberID,
                        commitAction: onExEditingChange
                    )
                    CookieRow(
                        inEditMode: $inEditMode,
                        key: passHashKey,
                        value: exPassHash,
                        commitAction: onExEditingChange
                    )
                    Button("Copy cookies", action: copyExCookies)
                }
            }
            TTProgressHUD($hudVisible, config: hudConfig)
        }
        .navigationBarTitle("Account")
        .navigationBarItems(trailing:
            Button(
                inEditMode ? "Finish" : "Edit",
                action: { inEditMode.toggle() }
            )
        )
    }
}

private extension AccountSettingView {
    var settingBinding: Binding<Setting>? {
        Binding($store.appState.settings.setting)
    }

    // MARK: Cookies Methods
    var igneous: CookieValue {
        getCookieValue(url: exURL, key: igneousKey)
    }
    var ehMemberID: CookieValue {
        getCookieValue(url: ehURL, key: memberIDKey)
    }
    var exMemberID: CookieValue {
        getCookieValue(url: exURL, key: memberIDKey)
    }
    var ehPassHash: CookieValue {
        getCookieValue(url: ehURL, key: passHashKey)
    }
    var exPassHash: CookieValue {
        getCookieValue(url: exURL, key: passHashKey)
    }
    func onEhEditingChange(key: String, value: String) {
        setCookieValue(url: ehURL, key: key, value: value)
    }
    func onExEditingChange(key: String, value: String) {
        setCookieValue(url: exURL, key: key, value: value)
    }
    func setCookieValue(url: URL, key: String, value: String) {
        if checkExistence(url: url, key: key) {
            editCookie(url: url, key: key, value: value)
        } else {
            setCookie(url: url, key: key, value: value)
        }
    }
    func copyEhCookies() {
        let cookies = "\(memberIDKey): \(ehMemberID.rawValue)"
            + "\n\(passHashKey): \(ehPassHash.rawValue)"
        saveToPasteboard(value: cookies)
        showCopiedHUD()
    }
    func copyExCookies() {
        let cookies = "\(igneousKey): \(igneous.rawValue)"
            + "\n\(memberIDKey): \(exMemberID.rawValue)"
            + "\n\(passHashKey): \(exPassHash.rawValue)"
        saveToPasteboard(value: cookies)
        showCopiedHUD()
    }
    func showCopiedHUD() {
        hudConfig = TTProgressHUDConfig(
            type: .success,
            title: "Success".localized(),
            caption: "Copied to clipboard".localized(),
            shouldAutoHide: true,
            autoHideInterval: 2
        )
        hudVisible.toggle()
    }

    // MARK: Dispatch Methods
    func toggleWebViewLogin() {
        store.dispatch(.toggleSettingViewSheetState(state: .webviewLogin))
    }
    func toggleWebViewConfig() {
        store.dispatch(.toggleSettingViewSheetState(state: .webviewConfig))
    }
    func toggleWebViewMyTags() {
        store.dispatch(.toggleSettingViewSheetState(state: .webviewMyTags))
    }
    func toggleLogout() {
        store.dispatch(.toggleSettingViewActionSheetState(state: .logout))
    }
}

// MARK: CookieRow
private struct CookieRow: View {
    @Binding private var inEditMode: Bool
    @State private var content: String

    private let key: String
    private let value: String
    private let cookieValue: CookieValue
    private let commitAction: (String, String) -> Void
    private var notVerified: Bool {
        !cookieValue.localizedString.isEmpty
            && !cookieValue.rawValue.isEmpty
    }

    init(
        inEditMode: Binding<Bool>,
        key: String,
        value: CookieValue,
        commitAction: @escaping (String, String) -> Void
    ) {
        _inEditMode = inEditMode
        _content = State(initialValue: value.rawValue)

        self.key = key
        self.value = value.localizedString.isEmpty
            ? value.rawValue : value.localizedString
        self.cookieValue = value
        self.commitAction = commitAction
    }

    var body: some View {
        HStack {
            Text(key)
            Spacer()
            ZStack {
                TextField(
                    value, text: $content,
                    onCommit: onTextFieldCommit
                )
                .disabled(!inEditMode)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .multilineTextAlignment(.trailing)
            }
            ZStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
                    .opacity(notVerified ? 0 : 1)
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
                    .opacity(notVerified ? 1 : 0)
            }
        }
        .onChange(of: inEditMode, perform: onEditModeChange)
    }

    private func onEditModeChange(value: Bool) {
        if value == false {
            onTextFieldCommit()
        }
    }
    private func onTextFieldCommit() {
        commitAction(key, content)
    }
}

// MARK: Definition
struct CookieValue {
    let rawValue: String
    let localizedString: String
}
