//
//  LoopScrollView.swift
//  LRLoopScrollView
//
//  Created by Ainiei on 2019/4/17.
//  Copyright © 2019 LR. All rights reserved.
//


import ReactorKit
import RxSwift
import RxCocoa
import RxDataSources
import Kingfisher

fileprivate class CycleScrollBannerViewCell: UICollectionViewCell, ReactorKit.View {
    
    var disposeBag: DisposeBag = DisposeBag()
    
    var imageView: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView = UIImageView.init(frame: CGRect.init(origin: .zero, size: frame.size))
        imageView.contentMode = .scaleAspectFit
        self.contentView.addSubview(imageView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func bind(reactor: CycleScrollBannerViewCellReactor) {
        self.imageView.kf.setImage(with: URL.init(string: reactor.currentState.url),
                                   placeholder: UIImage.init(named: reactor.currentState.placeHoldImageName))
    }
}

fileprivate class CycleScrollBannerViewCellReactor: Reactor {
    
    typealias Action = NoAction
    
    var initialState: NodeModel
    
    init(model: NodeModel) {
        self.initialState = model
    }
}




// MARK: # View
public class CycleScrollBannerView: UIView, ReactorKit.View {
    
    private var collectionView: UICollectionView!
    
    public var disposeBag: DisposeBag = DisposeBag()
    
    private let currentPageX = UIScreen.main.bounds.width
    
    public var service: CycleScrollBannerService? {
        didSet { self.reactor = service?.reactor }
    }
    
    public var itemSelected: ControlEvent<NodeModel> {
        let event = collectionView.rx.itemSelected.map { [unowned self] _ in
            return self.service?.currentPage
            }.filter{$0 != nil}.map {$0!}
        
        return ControlEvent.init(events: event)
    }
    
    public func bind(reactor: CycleScrollBannerReactor) {
        let source = RxCollectionViewSectionedReloadDataSource<SectionModel<Void, Void>> (
            configureCell: { (dateSource, collectionView, indexpath, _) -> UICollectionViewCell in
                
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexpath) as! CycleScrollBannerViewCell
            switch indexpath.row {
            case 0:
                if let pre = reactor.service?.currentPage?.pre {
                    cell.reactor = CycleScrollBannerViewCellReactor.init(model: pre) }
            case 1:
                if let current = reactor.service?.currentPage {
                    cell.reactor = CycleScrollBannerViewCellReactor.init(model: current)}
            case 2:
                if let next = reactor.service?.currentPage?.next {
                    cell.reactor = CycleScrollBannerViewCellReactor.init(model: next) }
            default:
                break
            }
            
            return cell
        })
        
        self.service?.source = source
        
        Observable.just(reactor.currentState.dataSource)
            .bind(to: self.collectionView.rx.items(dataSource: source))
            .disposed(by: disposeBag)
        
        self.collectionView.rx.contentOffset.skip(3).map { (offset) -> CycleScrollBannerReactor.Action in
            if offset.x <= 0 {
                return CycleScrollBannerReactor.Action.prePage
            } else if offset.x >= self.currentPageX * 2 {
                return CycleScrollBannerReactor.Action.nextPage
            } else {
                return CycleScrollBannerReactor.Action.none
            }
            }.distinctUntilChanged().bind(to: reactor.action).disposed(by: disposeBag)
        
        reactor.state.map {
            $0.event
            }.subscribe { [weak self] (event) in
                if let element = event.element, let self = self {
                    switch element {
                    case .autoScroll:
                        self.collectionView.scrollToItem(at: IndexPath.init(row: 2, section: 0), at: .right, animated: true)
                    case .none:
                        break
                    default:
                        UIView.performWithoutAnimation {
                            self.collectionView.reloadData()
                        }
                    }
                }
            }.disposed(by: disposeBag)
        
        self.collectionView.rx.setDelegate(self).disposed(by: disposeBag)
        
        self.collectionView.rx.willBeginDragging.map {_ in
            return CycleScrollBannerReactor.Action.beginDrag
            }.bind(to: reactor.action).disposed(by: disposeBag)
        
        self.collectionView.rx.didEndDragging.map { _ in
            return CycleScrollBannerReactor.Action.endDrag
            }.bind(to: reactor.action).disposed(by: disposeBag)
        
        self.collectionView.setContentOffset(CGPoint.init(x: self.currentPageX, y: 0), animated: false)
        
        self.collectionView.reloadData()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.itemSize = frame.size
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumLineSpacing = 0
        flowLayout.minimumInteritemSpacing = 0
        self.collectionView = UICollectionView.init(frame: self.bounds, collectionViewLayout: flowLayout)
        self.addSubview(collectionView)
        self.collectionView.backgroundColor = .white
        self.backgroundColor = .white
        self.collectionView.isPagingEnabled = true
        self.collectionView.register(CycleScrollBannerViewCell.self, forCellWithReuseIdentifier: "Cell")
        self.collectionView.showsVerticalScrollIndicator = false
        self.collectionView.showsHorizontalScrollIndicator = false
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension  CycleScrollBannerView: UIScrollViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offset = scrollView.contentOffset
        if offset.x <= 0 {
            self.collectionView.setContentOffset(CGPoint.init(x: self.currentPageX, y: 0), animated: false)
        } else if offset.x >= self.currentPageX * 2 {
            self.collectionView.setContentOffset(CGPoint.init(x: self.currentPageX, y: 0), animated: false)
        }
    }
}


// MARK: # Reactor
public class CycleScrollBannerReactor: Reactor {
    public enum Action {
        case nextPage
        case prePage
        case beginDrag
        case endDrag
        case load
        case none
        case autoScroll
    }
    
    public enum Mutaion {
        case showNextPage
        case showPrePage
        case beginDrag
        case endDrag
        case load
        case autoScroll
        case none
    }
    
    public struct State {
        var dataSource: [SectionModel<Void, Void>]
        
        var event = Action.load
        
        var timer: DispatchSourceTimer?
        
        init(dataSource: [SectionModel<Void, Void>]) {
            self.dataSource = dataSource
        }
    }
    
    public var initialState: State
    
    weak var service: CycleScrollBannerService?
    
    init(isAuto: Bool, repeatInterval: TimeInterval) {
        var state = State.init(dataSource: [SectionModel<Void, Void>.init(model: Void(), items: [Void(), Void(), Void()])])
        if isAuto {
            let timer = DispatchSource.makeTimerSource( queue: .main)
            timer.schedule(deadline: .now(), repeating: repeatInterval)
            timer.resume()
            state.timer = timer
        }
        initialState = state
    }
    
    public func mutate(action: Action) -> Observable<Mutaion> {
        switch action {
        case .load:
            return Observable.just(Mutaion.load)
            
        case .nextPage:
            self.service?.currentPage = self.service?.currentPage?.next
            return Observable.just(Mutaion.showNextPage)
            
        case .prePage:
            self.service?.currentPage = self.service?.currentPage?.pre
            return Observable.just(Mutaion.showPrePage)
            
        case .beginDrag:
            return Observable.just(Mutaion.beginDrag)
            
        case .endDrag:
            return Observable.just(Mutaion.endDrag)
            
        case .autoScroll:
            return Observable.just(Mutaion.autoScroll)
            
        case .none:
            return Observable.just(Mutaion.none)
            
        }
    }
    
    public func reduce(state: State, mutation: Mutaion) -> State {
        var state = state
        switch mutation {
        case .showNextPage:
            state.event = .nextPage
            
        case .showPrePage:
            state.event = .prePage
            
        case .load:
            state.event = .load
            
        case .beginDrag:
            if let timer = state.timer { timer.suspend() }
            
        case .endDrag:
            if let timer = state.timer { timer.resume()  }
            
        case .autoScroll:
            state.event = .autoScroll
            
        case .none:
            state.event = .none
        }
        return state
    }
    
    public func transform(action: Observable<Action>) -> Observable<Action> {
        guard let timer = currentState.timer else  { return action }
        let actionObservable = PublishSubject<Action>()
        timer.setEventHandler {
            actionObservable.onNext(.autoScroll)
        }
        return Observable.merge([action, actionObservable.skip(1)])
    }
}

public class NodeModel {
    var url: String
    
    var placeHoldImageName: String
    
    var index: Int = 0
    
    var pre: NodeModel?
    
    var next: NodeModel?
    
    init(url: String, placeHoldImageName: String) {
        self.url = url
        self.placeHoldImageName = placeHoldImageName
    }
}


//MARK: # Service
public class CycleScrollBannerService {
    
    fileprivate var reactor: CycleScrollBannerReactor?
    
    fileprivate var currentPage: NodeModel?
    
    fileprivate var source: RxCollectionViewSectionedReloadDataSource<SectionModel<Void, Void>>?
    
    private var models = [NodeModel]()
    
    public init(urlArr: [String], placeHoldImageName: String = "", isAuto: Bool = true, repeatInterval: TimeInterval = 3.0) {
        models = generateChainArr(arr: urlArr, placeHoldImageName: placeHoldImageName)
        currentPage = models.first
        reactor = CycleScrollBannerReactor.init(isAuto: isAuto, repeatInterval: repeatInterval)
        reactor?.service = self
    }
    
    private func generateChainArr(arr: [String], placeHoldImageName: String) -> [NodeModel] {
        var models = [NodeModel]()
        var pre: NodeModel?
        arr.enumerated().forEach { (index, tempStr) in
            let model = NodeModel.init(url: tempStr, placeHoldImageName: placeHoldImageName)
            model.pre = pre
            pre?.next = model
            pre?.index = index
            pre = model
            models.append(model)
        }
        
        models.last?.next = models.first
        models.first?.pre = models.last
        return models
    }
}



