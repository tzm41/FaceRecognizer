//
//  PNet.swift
//  FaceRecognizer
//
//  Created by Colin Tan on 5/9/20.
//  Copyright © 2020 Colin Tan. All rights reserved.
//

import CoreML
import Vision

protocol MTCNNDelegate: AnyObject {
    func mtcnn(_ mtcnn: MTCNN, didPredict predictions: MTCNNOutput)
}

class MTCNN {
    weak var delegate: MTCNNDelegate?

    private let pNetMLModel = _12net().model
    private let rNetMLModel = _24net().model
    private let oNetMLModel = _48net().model

    private let stepsThreshold: [Float] = [0.6, 0.7, 0.7]
    private let minFaceSize: Int = 20
    private let scaleFactor: Float = 0.709

    let pNetInputSize = CGSize(width: 12, height: 12)

    private func computeScalePyramid(minLayer: Int) -> [Float] {
        let m = 12.0 / Float(minFaceSize)
        var scales: [Float] = []
        var factorCount = 0
        var layer: Float = Float(minLayer)

        while minLayer >= 12 {
            scales.append(m * pow(scaleFactor, Float(factorCount)))
            layer = layer * scaleFactor
            factorCount += 1
        }

        return scales
    }

    func process(_ image: CGImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            let input = MTCNNInput(image: image, size: self.pNetInputSize)

            guard let prediction = try? self.pNetMLModel.prediction(from: input) else {
                return
            }

            let mtcnnOutput = MTCNNOutput(prediction: prediction, modelInputSize: self.pNetInputSize)

            DispatchQueue.main.async {
                self.delegate?.mtcnn(self, didPredict: mtcnnOutput)
            }
        }
    }
}
