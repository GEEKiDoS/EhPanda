//
//  WatchedReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct WatchedReducer: Reducer {
    enum Route: Equatable {
        case filters
        case quickSearch
        case detail(String)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var keyword = ""

        var galleries = [Gallery]()
        var pageNumber = PageNumber()
        var loadingState: LoadingState = .idle
        var footerLoadingState: LoadingState = .idle

        var filtersState = FiltersReducer.State()
        var quickSearchState = QuickSearchReducer.State()
        @Heap var detailState: DetailReducer.State!

        init() {
            _detailState = .init(.init())
        }

        mutating func insertGalleries(_ galleries: [Gallery]) {
            galleries.forEach { gallery in
                if !self.galleries.contains(gallery) {
                    self.galleries.append(gallery)
                }
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates
        case onNotLoginViewButtonTapped

        case teardown
        case fetchGalleries(String? = nil)
        case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)

        case filters(FiltersReducer.Action)
        case detail(DetailReducer.Action)
        case quickSearch(QuickSearchReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

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
                state.detailState = .init()
                state.filtersState = .init()
                state.quickSearchState = .init()
                return .merge(
                    .send(.detail(.teardown)),
                    .send(.quickSearch(.teardown))
                )

            case .onNotLoginViewButtonTapped:
                return .none

            case .teardown:
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchGalleries(let keyword):
                guard state.loadingState != .loading else { return .none }
                if let keyword = keyword {
                    state.keyword = keyword
                }
                state.loadingState = .loading
                state.pageNumber.resetPages()
                let filter = databaseClient.fetchFilterSynchronously(range: .watched)
                return .run { [keyword = state.keyword] send in
                    let response = await WatchedGalleriesRequest(filter: filter, keyword: keyword).response()
                    await send(.fetchGalleriesDone(response))
                }
                .cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.pageNumber = pageNumber
                    state.galleries = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                let pageNumber = state.pageNumber
                guard pageNumber.hasNextPage(),
                      state.footerLoadingState != .loading,
                      let lastID = state.galleries.last?.id
                else { return .none }
                state.footerLoadingState = .loading
                let filter = databaseClient.fetchFilterSynchronously(range: .watched)
                return .run { [keyword = state.keyword] send in
                    let response = await MoreWatchedGalleriesRequest(
                        filter: filter, lastID: lastID, keyword: keyword
                    )
                    .response()
                    await send(.fetchMoreGalleriesDone(response))
                }
                .cancellable(id: CancelID.fetchMoreGalleries)

            case .fetchMoreGalleriesDone(let result):
                state.footerLoadingState = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    state.pageNumber = pageNumber
                    state.insertGalleries(galleries)

                    var effects: [Effect<Action>] = [
                        .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                    ]
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.send(.fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.loadingState = .idle
                    }
                    return .merge(effects)

                case .failure(let error):
                    state.footerLoadingState = .failed(error)
                }
                return .none

            case .quickSearch:
                return .none

            case .filters:
                return .none

            case .detail:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: /Route.quickSearch,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.filters,
            hapticsClient: hapticsClient
        )

        Scope(state: \.filtersState, action: /Action.filters, child: FiltersReducer.init)
        Scope(state: \.quickSearchState, action: /Action.quickSearch, child: QuickSearchReducer.init)
        Scope(state: \.detailState, action: /Action.detail, child: DetailReducer.init)
    }
}
