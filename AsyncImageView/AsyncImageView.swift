//
//  AsyncImageView.swift
//  AsyncImageView
//
//  Created by Nacho Soto on 9/17/15.
//  Copyright © 2015 Nacho Soto. All rights reserved.
//

import UIKit

import ReactiveCocoa
import Result

public protocol ImageViewDataType {
	typealias RenderData: RenderDataType

	func renderDataWithSize(size: CGSize) -> RenderData
}

/// A `UIImageView` that can render asynchronously.
public final class AsyncImageView<
	Data: RenderDataType,
	ImageViewData: ImageViewDataType,
	Renderer: RendererType,
	PlaceholderRenderer: RendererType
	where
	ImageViewData.RenderData == Data,
	Renderer.Data == Data,
	Renderer.Error == NoError,
	PlaceholderRenderer.Data == Data,
	PlaceholderRenderer.Error == NoError,
	Renderer.RenderResult == PlaceholderRenderer.RenderResult
>: UIImageView {
	private let requestsSignal: Signal<Data?, NoError>
	private let requestsObserver: Signal<Data?, NoError>.Observer

	private let imageCreationScheduler: SchedulerType

	public init(
		initialFrame: CGRect,
		renderer: Renderer,
		placeholderRenderer: PlaceholderRenderer? = nil,
		uiScheduler: SchedulerType = UIScheduler(),
		imageCreationScheduler: SchedulerType = QueueScheduler())
	{
		(self.requestsSignal, self.requestsObserver) = Signal.pipe()
		self.imageCreationScheduler = imageCreationScheduler

		super.init(frame: initialFrame)

		self.backgroundColor = nil

		self.requestsSignal
			.skipRepeats(==)
			.observeOn(uiScheduler)
			.on(next: { [weak self] in
				if let strongSelf = self
					where placeholderRenderer == nil || $0 == nil {
						strongSelf.resetImage()
				}
			})
			.observeOn(self.imageCreationScheduler)
			.flatMap(.Latest) { data -> SignalProducer<Renderer.RenderResult, NoError> in
				if let data = data {
					if let placeholderRenderer = placeholderRenderer {
						return placeholderRenderer
							.renderImageWithData(data)
							.takeUntilReplacement(renderer.renderImageWithData(data))
					} else {
						return renderer.renderImageWithData(data)
					}
				} else {
					return .empty
				}
			}
			.observeOn(uiScheduler)
			.observeNext { [weak self] in self?.updateImage($0) }
	}

	public required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		requestsObserver.sendCompleted()
	}

	public override var frame: CGRect {
		didSet {
			self.requestNewImageIfReady()
		}
	}

	public var data: ImageViewData? {
		didSet {
			self.requestNewImageIfReady()
		}
	}

	// MARK: -

	private func resetImage() {
		// Avoid displaying a stale image.
		self.image = nil
	}

	private func requestNewImageIfReady() {
		if self.bounds.size.width > 0 && self.bounds.size.height > 0 {
			self.requestNewImage(self.bounds.size, data: self.data)
		}
	}

	private func requestNewImage(size: CGSize, data: ImageViewData?) {
		self.imageCreationScheduler.schedule { [weak instance = self, observer = self.requestsObserver] in
			if instance != nil {
				observer.sendNext(data?.renderDataWithSize(size))
			}
		}
	}

	// MARK: -

	private func updateImage(result: Renderer.RenderResult) {
		if result.cacheHit {
			self.image = result.image
		} else {
			UIView.transitionWithView(
				self,
				duration: fadeAnimationDuration,
				options: [.CurveEaseOut, .TransitionCrossDissolve],
				animations: { self.image = result.image },
				completion: nil
			)
		}
	}
}

// MARK: - Constants

private let fadeAnimationDuration: NSTimeInterval = 0.4
