//
//  MangaStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/11.
//

import Combine
import Foundation

class PopularItemsStore: ObservableObject {
    @Published var popularItems = [Manga]()
    
    func fetchPopularItems() {
        executeAsyncally {
            let items = RequestManager.shared.requestPopularItems()
            executeMainAsyncally { [weak self] in
                self?.popularItems = items
            }
        }
    }
}

class DetailItemsStore: ObservableObject {
    @Published var detailItem: MangaDetail?
    @Published var previewItems = [MangaContent]()
    
    func fetchDetailItem(url: String) {
        executeAsyncally {
            let item = RequestManager.shared.requestDetailItem(url: url)
            executeMainAsyncally { [weak self] in
                self?.detailItem = item
            }
        }
    }
    
    func fetchPreviewItems(url: String) {
        executeAsyncally {
            let items = RequestManager.shared.requestPreviewItems(url: url)
            executeMainAsyncally { [weak self] in
                self?.previewItems.append(contentsOf: items)
            }
        }
    }
    
    func removeTmpPreviewItems() {
        RequestManager.shared.tmpPreviewItems.removeAll()
    }
}

class ContentItemsStore: ObservableObject {
    @Published var contentItems = [MangaContent]()
    
    func fetchContentItems(url: String, pages: Int) {
        let pageCount = Int(ceil(Double(pages)/10))
        for index in 0..<pageCount {
            executeAsyncally {
                let items = RequestManager.shared.requestContentItems(url: url, pageIndex: index)
                
                executeMainAsyncally { [weak self] in
                    self?.contentItems.append(contentsOf: items)
                    self?.contentItems.sort(by: { (a, b) -> Bool in
                        a.tag < b.tag
                    })
                }
            }
        }
    }
}
