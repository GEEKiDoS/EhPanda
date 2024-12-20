//
//  QuickSearchReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/20.
//

import SwiftUI
import ComposableArchitecture

struct QuickSearchReducer: Reducer {
    enum Route: Equatable {
        case newWord
        case editWord
        case deleteWord(QuickSearchWord)
    }

    enum FocusField {
        case name
        case content
    }

    private enum CancelID {
        case fetchQuickSearchWords
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var focusedField: FocusField?
        @BindingState var editingWord: QuickSearchWord = .empty
        @BindingState var listEditMode: EditMode = .inactive
        var isListEditing: Bool {
            get { listEditMode == .active }
            set { listEditMode = newValue ? .active : .inactive }
        }

        var loadingState: LoadingState = .idle
        var quickSearchWords = [QuickSearchWord]()
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates

        case syncQuickSearchWords

        case toggleListEditing
        case setEditingWord(QuickSearchWord)

        case appendWord
        case editWord
        case deleteWord(QuickSearchWord)
        case deleteWordWithOffsets(IndexSet)
        case moveWord(IndexSet, Int)

        case teardown
        case fetchQuickSearchWords
        case fetchQuickSearchWordsDone([QuickSearchWord])
    }

    @Dependency(\.databaseClient) private var databaseClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.$route):
                return state.route == nil ? .send(.clearSubStates) : .none

            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.focusedField = nil
                state.editingWord = .empty
                return .none

            case .syncQuickSearchWords:
                return .run { [state] _ in
                    await databaseClient.updateQuickSearchWords(state.quickSearchWords)
                }

            case .toggleListEditing:
                state.isListEditing.toggle()
                return .none

            case .setEditingWord(let word):
                state.editingWord = word
                return .none

            case .appendWord:
                state.quickSearchWords.append(state.editingWord)
                return .send(.syncQuickSearchWords)

            case .editWord:
                if let index = state.quickSearchWords.firstIndex(where: { $0.id == state.editingWord.id }) {
                    state.quickSearchWords[index] = state.editingWord
                    return .send(.syncQuickSearchWords)
                }
                return .none

            case .deleteWord(let word):
                state.quickSearchWords = state.quickSearchWords.filter({ $0 != word })
                return .send(.syncQuickSearchWords)

            case .deleteWordWithOffsets(let offsets):
                state.quickSearchWords.remove(atOffsets: offsets)
                return .send(.syncQuickSearchWords)

            case .moveWord(let source, let destination):
                state.quickSearchWords.move(fromOffsets: source, toOffset: destination)
                return .send(.syncQuickSearchWords)

            case .teardown:
                return .cancel(id: CancelID.fetchQuickSearchWords)

            case .fetchQuickSearchWords:
                state.loadingState = .loading
                return .run { send in
                    let quickSearchWords = await databaseClient.fetchQuickSearchWords()
                    await send(.fetchQuickSearchWordsDone(quickSearchWords))
                }
                .cancellable(id: CancelID.fetchQuickSearchWords)

            case .fetchQuickSearchWordsDone(let words):
                state.loadingState = .idle
                state.quickSearchWords = words
                return .none
            }
        }
    }
}
