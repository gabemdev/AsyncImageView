//
//  Renderer.swift
//  AsyncImageView
//
//  Created by Nacho Soto on 11/22/15.
//  Copyright © 2015 Nacho Soto. All rights reserved.
//

import UIKit
import ReactiveCocoa

/// Information required to produce an image
public protocol RenderDataType: Hashable {
	var size: CGSize { get }
}

public protocol RenderResultType {
	var image: UIImage { get }
	var cacheHit: Bool { get }
}

public struct ImageResult: RenderResultType {
	public let image: UIImage
	public let cacheHit: Bool

	public init(image: UIImage, cacheHit: Bool) {
		self.image = image
		self.cacheHit = cacheHit
	}
}

extension UIImage: RenderResultType {
	public var image: UIImage {
		return self
	}

	public var cacheHit: Bool {
		// A raw UIImage created by a `RendererType` is implicitly not cached.
		return false
	}
}

public protocol RendererType {
	typealias Data: RenderDataType

	typealias RenderResult: RenderResultType
	typealias Error: ErrorType

	func renderImageWithData(data: Data) -> SignalProducer<RenderResult, Error>
}

public protocol SynchronousRendererType {
	typealias Data: RenderDataType

	func renderImageWithData(data: Data) -> UIImage
}
