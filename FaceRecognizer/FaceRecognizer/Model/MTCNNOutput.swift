//
//  MTCNNOutput.swift
//  FaceRecognizer
//
//  Created by Colin Tan on 5/9/20.
//  Copyright © 2020 Colin Tan. All rights reserved.
//

import CoreML
import Vision

struct MTCNNOutput {
    enum Feature: String {
        case conv1 = "conv6-2"
        case conv2 = "conv6-3"
        case confidence = "prob1"
    }

    struct BoundingBox {
        let x: Int
        let y: Int
        let w: Int
        let h: Int

        init(_ x: Int, _ y: Int, _ w: Int, _ h: Int) {
            self.x = x
            self.y = y
            self.w = w
            self.h = h
        }

        static var zero: BoundingBox {
            return BoundingBox(0, 0, 0, 0)
        }
    }

    let confidence: MLMultiArray
    let conv1: MLMultiArray
    let conv2: MLMultiArray

    let modelInputSize: CGSize

    init(prediction: MLFeatureProvider, modelInputSize: CGSize) {
        guard let conv1 = prediction.multiArrayValue(for: .conv1) else {
            fatalError("Failed to get the conv1 MLMultiArray")
        }
        guard let conv2 = prediction.multiArrayValue(for: .conv2) else {
            fatalError("Failed to get the conv2 MLMultiArray")
        }
        guard let confidence = prediction.multiArrayValue(for: .confidence) else {
            fatalError("Failed to get the confidence MLMultiArray")
        }

        self.conv1 = conv1
        self.conv2 = conv2
        self.confidence = confidence

        self.modelInputSize = modelInputSize
    }
}

// MARK: - MLFeatureProvider extension

extension MLFeatureProvider {
    func multiArrayValue(for feature: MTCNNOutput.Feature) -> MLMultiArray? {
        return featureValue(for: feature.rawValue)?.multiArrayValue
    }
}

// MARK: - MLMultiArray extension

extension MLMultiArray {
    subscript(index: [Int]) -> NSNumber {
        return self[index.map { NSNumber(value: $0) } ]
    }
}

