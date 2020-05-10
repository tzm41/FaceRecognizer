//
//  ViewController.swift
//  FaceRecognizer
//
//  Created by Colin Tan on 5/9/20.
//  Copyright © 2020 Colin Tan. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision
import ImageIO
import VideoToolbox

class ViewController: UIViewController {

    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var classLabel: UILabel!
    @IBOutlet weak var confidenceLabel: UILabel!

    private var videoImageView: UIImageView = UIImageView()
    private var drawings: [CAShapeLayer] = []

    private let videoCapture = VideoCapture()
    private var currentFrame: CGImage?

    private var captureResolution: CGSize {
        return videoCapture.resoltion
    }

    /// - Tag: MLModelSetup
    lazy var classificationRequest: VNCoreMLRequest = {
        do {
            let model = try VNCoreMLModel(for: MaskClassifier().model)

            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassification(for: request, error: error)
            })
            request.imageCropAndScaleOption = .centerCrop
            return request
        } catch {
            fatalError("Failed to load CoreML model: \(String(describing: error)).")
        }
    }()

    lazy var detectionRequest: VNDetectFaceRectanglesRequest = {
        let request = VNDetectFaceRectanglesRequest(completionHandler: { [weak self] request, error in
            self?.processDetection(for: request, error: error)
        })
        return request
    }()

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
            if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    if !granted {
                        self?.presentCameraAccessPopup()
                    }
                }
            } else {
                presentCameraAccessPopup()
            }
        }

        setupLivePreview()
        setupAndBeginCapturingVideoFrames()
    }

    private func setupAndBeginCapturingVideoFrames() {
        videoCapture.setUpAVCapture { error in
            if let error = error {
                print("Failed to setup camera with error \(error)")
                return
            }

            self.videoCapture.delegate = self
            self.videoCapture.startCapturing()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        videoCapture.stopCapturing {
            super.viewWillDisappear(animated)
        }
    }

    func presentCameraAccessPopup() {
        let alert = UIAlertController(title: "Needs Camera Access", message: "Please allow camera access in Settings", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alert, animated: true)
    }

    func setupLivePreview() {
        videoView.addSubview(videoImageView)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.videoImageView.frame = self.videoView.bounds
        }
    }

    // MARK: - Perform Requests

    func updateDetectionAndClassification(for image: CGImage) {
        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: image)
            do {
                try handler.perform([self.detectionRequest, self.classificationRequest])
            } catch {
                print("Failed to perform classification: \(String(describing: error)).")
            }
        }
    }

    private func processDetection(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            defer {
                self.currentFrame = nil
            }

            guard let currentFrame = self.currentFrame else { return }

            self.videoImageView.image = UIImage(cgImage: currentFrame)
            self.clearDrawings()

            guard let results = request.results, let observations = results as? [VNFaceObservation] else { return }
            
            for observation in observations {
                self.drawDetectedFace(observation)
            }
            self.updateDetectionUI(faceDetected: !observations.isEmpty)
        }
    }

    private func processClassification(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            guard let results = request.results, let classifications = results as? [VNClassificationObservation] else {
                self.classLabel?.text = "Unable to classify image: \(String(describing: error))."
                return
            }

            self.updateClassificationUI(with: classifications)
        }
    }

    private func updateDetectionUI(faceDetected: Bool) {
        classLabel.isHidden = !faceDetected
        confidenceLabel.isHidden = !faceDetected
    }

    private func updateClassificationUI(with classifications: [VNClassificationObservation]) {
        if classifications.isEmpty {
            classLabel.text = "Nothing recognized."
        } else {
            guard let topClassification = classifications.first else { return }
            let classString = topClassification.identifier == "0" ? "Unmasked" : "Masked"
            classLabel.text = "Classification: " + classString
            confidenceLabel.text = String(format: "Confidence: %.3f", topClassification.confidence)
        }
    }

    private func clearDrawings() {
        drawings.forEach { drawing in drawing.removeFromSuperlayer() }
        drawings.removeAll()
    }

    private func drawDetectedFace(_ observation: VNFaceObservation) {
        guard let currentFrame = currentFrame else { return }

        let faceBounds = VNImageRectForNormalizedRect(observation.boundingBox, currentFrame.width, currentFrame.height)
        var transform = CGAffineTransform(translationX: 0, y: CGFloat(currentFrame.height))
        transform = transform.scaledBy(x: 1, y: -1)
        let faceBoundingBoxPath = CGPath(rect: faceBounds.applying(transform), transform: nil)
        let faceBoundingBoxShape = CAShapeLayer()
        faceBoundingBoxShape.path = faceBoundingBoxPath
        faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
        faceBoundingBoxShape.strokeColor = UIColor.green.cgColor

        self.videoImageView.layer.addSublayer(faceBoundingBoxShape)
        self.drawings.append(faceBoundingBoxShape)
    }
}

// MARK: - VideoCaptureDelegate

extension ViewController: VideoCaptureDelegate {
    func videoCapture(_ videoCapture: VideoCapture, didCaptureFrame capturedImage: CGImage?) {
        guard currentFrame == nil else {
            return
        }
        guard let image = capturedImage else {
            fatalError("Captured image is null")
        }

        currentFrame = image
        updateDetectionAndClassification(for: image)
    }
}

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
            case .up: self = .up
            case .upMirrored: self = .upMirrored
            case .down: self = .down
            case .downMirrored: self = .downMirrored
            case .left: self = .left
            case .leftMirrored: self = .leftMirrored
            case .right: self = .right
            case .rightMirrored: self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}
