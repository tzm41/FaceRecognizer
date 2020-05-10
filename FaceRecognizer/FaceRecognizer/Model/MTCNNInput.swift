//
//  MTCNNInput.swift
//  FaceRecognizer
//
//  Created by Colin Tan on 5/9/20.
//  Copyright © 2020 Colin Tan. All rights reserved.
//

import CoreML
import Vision

class MTCNNInput: MLFeatureProvider {
    private static let imageFeatureName = "data"

    var imageFeature: CGImage
    let imageFeatureSize: CGSize

    var featureNames: Set<String> {
        return [MTCNNInput.imageFeatureName]
    }

    init(image: CGImage, size: CGSize) {
        imageFeature = image
        imageFeatureSize = size
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        guard featureName == MTCNNInput.imageFeatureName else {
            return nil
        }

        let options: [MLFeatureValue.ImageOption: Any] = [
            .cropAndScale: VNImageCropAndScaleOption.scaleFill.rawValue
        ]

        return try? MLFeatureValue(cgImage: imageFeature,
                                   pixelsWide: Int(imageFeatureSize.width),
                                   pixelsHigh: Int(imageFeatureSize.height),
                                   pixelFormatType: imageFeature.pixelFormatInfo.rawValue,
                                   options: options)
    }
}

