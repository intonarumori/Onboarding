//
//  OnboardingViewController.swift
//  OnboardingViewController
//
//  Created by Daniel Langh on 12/12/15.
//  Copyright © 2015 rumori. All rights reserved.
//

import UIKit

// MARK: - UIViewController extension

public extension UIViewController {
    
    /**
     Returns the parent `OnboardingController` if the view controller is part of an onboarding flow.
     (usage is similar to accessing `UINavigationController` from any `UIViewController`)
     
     - returns: the parent `OnboardingController` if the view controller is part of an onboarding flow
     */
    var onboardingController:OnboardingController? {
        get {
            var parentViewController = self.parent
            while let validParentViewController = parentViewController {
                
                if let onboardingViewController = validParentViewController as? OnboardingController {
                    return onboardingViewController
                } else {
                    parentViewController = validParentViewController.parent
                }
            }
            return nil
        }
    }
}

// MARK: - OnboardingController progress view protocol

public protocol OnboardingProgressViewProtocol: class {
    
    func setNumberOfViewControllersInOnboarding(_ numberOfViewControllers:Int)
    func setOnboardingCompletionPercent(_ percent:CGFloat)
}

extension OnboardingProgressViewProtocol where Self: UIResponder {

    var onboardingController:OnboardingController? {
        get {
            var currentResponder:UIResponder? = self.next
            while let validResponder = currentResponder {
                
                if let onboardingController = validResponder as? OnboardingController {
                    return onboardingController
                }
                currentResponder = validResponder.next
            }
            return nil
        }
    }
}

// MARK: - OnboardingController background view protocol

public protocol OnboardingAnimatedBackgroundContentView {
    
    func setOnboardingCompletionPercent(_ percent:CGFloat)
}

// MARK: - protocol for animated content viewcontrollers

public protocol OnboardingContentViewController {

    /**
     Returns the parent OnboardingController if the viewcontroller is part of an onboarding flow.
     (usage is similar to accessing UINavigationController from any UIViewController)
     
     - parameter percent: the value of visilibity percentage. Valid values are in the [0.0, 2.0] range. Value of 0.0 means the viewcontroller is not yet visible and will come from the right, 1.0 means the viewcontroller is in the center and fully visible, while 2.0 means the viewcontroller is not visible any more and has been scrolled out of visibility and is located on the left.
     */
    func setVisibilityPercent(_ percent:CGFloat)
}

// MARK: - OnboardingController delegate protocol

public protocol OnboardingControllerDelegate : class {
    func onboardingController(_ onboardingController:OnboardingController, didScrollToViewController viewController:UIViewController)
    func onboardingControllerDidFinish(_ onboardingController:OnboardingController)
}

// MARK: -

open class OnboardingController: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, UIScrollViewDelegate {

    open weak var delegate:OnboardingControllerDelegate?
    
    open fileprivate(set) var progressView:UIView?
    open fileprivate(set) var backgroundContentView:UIView?
    open fileprivate(set) var viewControllers:Array<UIViewController> = []
    
    fileprivate weak var currentViewController:UIViewController?
    
    fileprivate var scrollViewUpdatesEnabled:Bool = true
    open fileprivate(set) var pageViewController:UIPageViewController?
    
    public init(viewControllers:Array<UIViewController>, backgroundContentView:UIView? = nil, progressView:UIView? = nil) {
        super.init(nibName: nil, bundle: nil)
        self.backgroundContentView = backgroundContentView
        self.progressView = progressView
        self.viewControllers = viewControllers
        self.automaticallyAdjustsScrollViewInsets = false
    }
    
    public convenience required init?(coder aDecoder: NSCoder) {
        self.init(viewControllers:[])
    }
    
    open override func loadView() {
        let defaultSize = CGSize(width: 400, height: 600)
        let view = UIView(frame: CGRect(x: 0, y: 0, width: defaultSize.width, height: defaultSize.height))
        view.backgroundColor = UIColor.white
        self.view = view
        
        let pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)
        pageViewController.willMove(toParentViewController: self)
        self.addChildViewController(pageViewController)
        pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(pageViewController.view)
        self.pageViewController = pageViewController
        
        self.view.addConstraints([
            NSLayoutConstraint(
                item: pageViewController.view, attribute: .top,
                relatedBy: .equal,
                toItem: self.view, attribute: .top,
                multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(
                item: pageViewController.view, attribute: .bottom,
                relatedBy: .equal,
                toItem: self.view, attribute: .bottom,
                multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(
                item: pageViewController.view, attribute: .leading,
                relatedBy: .equal,
                toItem: self.view, attribute: .leading,
                multiplier: 1.0, constant: 0.0),
            NSLayoutConstraint(
                item: pageViewController.view, attribute: .trailing,
                relatedBy: .equal,
                toItem: self.view, attribute: .trailing,
                multiplier: 1.0, constant: 0.0)
        ])
        
        pageViewController.didMove(toParentViewController: self)
        pageViewController.view.backgroundColor = UIColor.clear
        
        pageViewController.delegate = self
        pageViewController.dataSource = self

        if let progressView = self.progressView {
            let progressViewHeight = progressView.frame.size.height
            progressView.frame = CGRect(x: 0, y: self.view.bounds.size.height-progressViewHeight, width: self.view.bounds.size.width, height: progressViewHeight)
            progressView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
            self.view.addSubview(progressView)
        }
        
        if let backgroundContentView = self.backgroundContentView {
            backgroundContentView.translatesAutoresizingMaskIntoConstraints = false
            self.view.insertSubview(backgroundContentView, at: 0)
            
            self.view.addConstraints([
                NSLayoutConstraint(item: backgroundContentView, attribute: .top, relatedBy: .equal,
                    toItem: self.view, attribute: .top, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: backgroundContentView, attribute: .bottom, relatedBy: .equal,
                    toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: backgroundContentView, attribute: .leading, relatedBy: .equal,
                    toItem: self.view, attribute: .leading, multiplier: 1.0, constant: 0.0),
                NSLayoutConstraint(item: backgroundContentView, attribute: .trailing, relatedBy: .equal,
                    toItem: self.view, attribute: .trailing, multiplier: 1.0, constant: 0.0),
                ])
            
        }
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        if let firstViewController = self.viewControllers.first {
            self.pageViewController?.setViewControllers([firstViewController],
                direction: .forward,
                animated: false,
                completion: nil)
        }
        
        if let animatedProgressView = self.progressView as? OnboardingProgressViewProtocol {
            animatedProgressView.setNumberOfViewControllersInOnboarding(self.viewControllers.count)
        }
        
        self.installScrollViewDelegate()
        
        if let scrollView = self.pageViewControllerScrollView() {
            self.updatePercentagesWithScrollView(scrollView, animated: false)
        }
    }
    
    // MARK: -
    
    fileprivate func installScrollViewDelegate() {
        self.pageViewControllerScrollView()?.delegate = self
    }
    
    fileprivate func pageViewControllerScrollView() -> UIScrollView? {
        
        guard let pageViewController = self.pageViewController else {
            return nil
        }
        
        for subview in pageViewController.view.subviews {
            if let scrollView = subview as? UIScrollView {
                return scrollView
            }
        }
        return nil
    }
    
    // MARK: -
    
    open func moveToNext(_ animated:Bool = false) {

        guard let pageViewController = self.pageViewController else {
            return
        }

        if let currentViewController = self.currentViewController {
            if let nextViewController = self.viewControllerAfterViewController(currentViewController) {
                pageViewController.setViewControllers([nextViewController],
                    direction: .forward,
                    animated: animated,
                    completion:{ (finished) -> Void in
                        if finished {
                            self.sendDidScrollToViewControllerNotification()
                        }
                })
            } else {
                if let delegate = self.delegate {
                    delegate.onboardingControllerDidFinish(self)
                }
            }
        }
    }
    
    open func moveToPrevious(_ animated:Bool = false) {

        guard let pageViewController = self.pageViewController else {
            return
        }
        
        if let currentViewController = currentViewController {
            if let previousViewController = self.viewControllerBeforeViewController(currentViewController) {
                pageViewController.setViewControllers([previousViewController],
                    direction: .reverse,
                    animated: animated,
                    completion:{ (finished) -> Void in
                        if finished {
                            self.sendDidScrollToViewControllerNotification()
                        }
                })
            }
        }
    }
    
    // MARK: -
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {

        guard scrollViewUpdatesEnabled else {
            return
        }
        self.updatePercentagesWithScrollView(scrollView, animated: true)
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.scrollFinished(scrollView)
    }
    
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.scrollFinished(scrollView)
        } else {
            /*
            UIView.animateWithDuration(0.2) { () -> Void in
                self.setNeedsStatusBarAppearanceUpdate()
            }*/
        }
    }
    
    fileprivate func scrollFinished(_ scrollView:UIScrollView) {
        self.sendDidScrollToViewControllerNotification()
    }
    
    fileprivate func sendDidScrollToViewControllerNotification() {
        if let currentViewController = currentViewController {
            delegate?.onboardingController(self, didScrollToViewController: currentViewController)
        }
    }
    
    fileprivate func updatePercentagesWithScrollView(_ scrollView:UIScrollView, animated:Bool)
    {
        // update viewcontrollers
        
        var currentlyFocusedViewController:UIViewController? = nil
        
        for viewController in self.viewControllers {
            if let visibilityPercent = self.visibilityPercentForViewController(scrollView, viewController: viewController) {
                if let animatedContentViewController = viewController as? OnboardingContentViewController {
                    animatedContentViewController.setVisibilityPercent(visibilityPercent)
                }
                
                if visibilityPercent >= 0.5 && visibilityPercent < 1.5 {
                    currentlyFocusedViewController = viewController
                }
            }
        }
        
        if currentViewController != currentlyFocusedViewController {
            currentViewController = currentlyFocusedViewController
            
            if animated {
                UIView.animate(withDuration: 0.2, animations: { () -> Void in
                    self.setNeedsStatusBarAppearanceUpdate()
                })
            } else {
                setNeedsStatusBarAppearanceUpdate()
            }
        }

        // update background, progress
        if let onboardingProgressPercent = self.onboardingProgressPercent(scrollView) {
            if let animatedBackgroundContentView = self.backgroundContentView as? OnboardingAnimatedBackgroundContentView {
                animatedBackgroundContentView.setOnboardingCompletionPercent(onboardingProgressPercent)
            }
            if let animatedProgressView = self.progressView as? OnboardingProgressViewProtocol {
                animatedProgressView.setOnboardingCompletionPercent(onboardingProgressPercent)
            }
        }
    }
    
    // MARK: -
    
    fileprivate func onboardingProgressPercent(_ scrollView:UIScrollView) -> CGFloat? {
        if let currentViewController = currentViewController {
            if let visibilityPercent = visibilityPercentForViewController(scrollView, viewController: currentViewController) {
                if let index = self.indexForViewController(currentViewController) {
                    let numberOfViewControllers = self.numberOfViewControllers()
                    
                    //print("current \(currentViewController.title) \(visibilityPercent) \(index)")
                    
                    let onboardingCompletionPercent = (1.0 / CGFloat(numberOfViewControllers-1)) * (CGFloat(index) + CGFloat(visibilityPercent) - 1.0)
                    return onboardingCompletionPercent
                }
            }
        }
        return nil
    }
    
    
    fileprivate func visibilityPercentForViewController(_ scrollView:UIScrollView, viewController:UIViewController) -> CGFloat? {

        if viewController.isViewLoaded {

            let scrollViewOffsetX = scrollView.contentOffset.x
            let scrollViewWidth = scrollView.frame.size.width
            
            let view = viewController.view!
            
            if(view.superview != nil) {
                let viewOffset = view.convert(CGPoint.zero, to: scrollView)
                
                let percent = (scrollViewOffsetX - viewOffset.x) / scrollViewWidth
                let visibilityPercent = percent + 1.0
                
                return visibilityPercent
            }
            
            return nil
        }
        return nil
    }
    
    // MARK: - pageviewcontroller delegate
    
    open func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        print("pageViewController didFinishAnimating")
    }
    
    open func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        print("pageViewController willTransitionToViewControllers", pendingViewControllers)
    }
    
    // MARK: - pageviewcontroller datasource
    
    open func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        return self.viewControllerAfterViewController(viewController)
    }
    
    open func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        return self.viewControllerBeforeViewController(viewController)
    }
    
    // MARK: - rotation
    
    open override func willRotate(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
        self.scrollViewUpdatesEnabled = false
    }
    
    open override func didRotate(from fromInterfaceOrientation: UIInterfaceOrientation) {
        self.scrollViewUpdatesEnabled = true
        if let scrollView = self.pageViewControllerScrollView() {
            self.updatePercentagesWithScrollView(scrollView, animated: false)
        }
    }
    
    // MARK: - ViewController access by index
    
    fileprivate func numberOfViewControllers() -> Int {
        return self.viewControllers.count
    }
    
    fileprivate func indexForViewController(_ viewController:UIViewController) -> Int? {
        return self.viewControllers.index(of: viewController)
    }
    
    fileprivate func viewControllerBeforeViewController(_ viewController:UIViewController) -> UIViewController? {
        if let index = self.viewControllers.index(of: viewController) {
            let previousIndex = index - 1
            if previousIndex >= 0 {
                return self.viewControllers[previousIndex]
            }
        }
        return nil
    }
    
    fileprivate func viewControllerAfterViewController(_ viewController:UIViewController) -> UIViewController? {
        if let index = self.viewControllers.index(of: viewController) {
            let nextIndex = index + 1
            if nextIndex < self.viewControllers.count {
                return self.viewControllers[nextIndex]
            }
        }
        return nil
    }
    
    // Status bar handling
    
    override open var childViewControllerForStatusBarHidden : UIViewController? {
        return currentViewController
    }
    override open var childViewControllerForStatusBarStyle : UIViewController? {
        return currentViewController
    }
}
