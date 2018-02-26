/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
View controller for camera interface.
*/

import UIKit
import AVFoundation
import Photos
import CoreMotion

class CameraViewController: UIViewController, UIDocumentPickerDelegate {

	// MARK: View Controller Life Cycle
	
    override func viewDidLoad() {
		super.viewDidLoad()
		
		// Disable UI. The UI is enabled if and only if the session starts running.
		photoButton.isEnabled = false
		
		// Set up the video preview view.
		previewView.session = session
		
		/*
			Check video authorization status. Video access is required and audio
			access is optional. If audio access is denied, audio is not recorded
			during movie recording.
		*/
		switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
				// The user has previously granted access to the camera.
				break
			
			case .notDetermined:
				/*
					The user has not yet been presented with the option to grant
					video access. We suspend the session queue to delay session
					setup until the access request has completed.
				
					Note that audio access will be implicitly requested when we
					create an AVCaptureDeviceInput for audio during session setup.
				*/
				sessionQueue.suspend()
				AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
					if !granted {
						self.setupResult = .notAuthorized
					}
					self.sessionQueue.resume()
				})
			
			default:
				// The user has previously denied access.
				setupResult = .notAuthorized
		}
		
		/*
			Setup the capture session.
			In general it is not safe to mutate an AVCaptureSession or any of its
			inputs, outputs, or connections from multiple threads at the same time.
		
			Why not do all of this on the main queue?
			Because AVCaptureSession.startRunning() is a blocking call which can
			take a long time. We dispatch session setup to the sessionQueue so
			that the main queue isn't blocked, which keeps the UI responsive.
		*/
		sessionQueue.async {
			self.configureSession()
		}
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		sessionQueue.async {
			switch self.setupResult {
                case .success:
				    // Only setup observers and start the session running if setup succeeded.
                    self.addObservers()
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
				
                case .notAuthorized:
                    DispatchQueue.main.async {
                        let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                        let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                        let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                        
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                                style: .cancel,
                                                                handler: nil))
                        
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                                style: .`default`,
                                                                handler: { _ in
                            UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!, options: [:], completionHandler: nil)
                        }))
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
				
                case .configurationFailed:
                    DispatchQueue.main.async {
                        let alertMsg = "Alert message when something goes wrong during capture session configuration"
                        let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                        let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                        
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                                style: .cancel,
                                                                handler: nil))
                        
                        self.present(alertController, animated: true, completion: nil)
                    }
			}
		}
        startGyros()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		sessionQueue.async {
			if self.setupResult == .success {
				self.session.stopRunning()
				self.isSessionRunning = self.session.isRunning
				self.removeObservers()
			}
		}
		
		super.viewWillDisappear(animated)
	}
	
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .all
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		
		if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
			let deviceOrientation = UIDevice.current.orientation
			guard let newVideoOrientation = AVCaptureVideoOrientation(deviceOrientation: deviceOrientation),
				deviceOrientation.isPortrait || deviceOrientation.isLandscape else {
				return
			}
			
			videoPreviewLayerConnection.videoOrientation = newVideoOrientation
		}
	}

	// MARK: Session Management
	
	private enum SessionSetupResult {
		case success
		case notAuthorized
		case configurationFailed
	}
	
	private let session = AVCaptureSession()
	
	private var isSessionRunning = false
	
	private let sessionQueue = DispatchQueue(label: "session queue") // Communicate with the session and other session objects on this queue.
	
	private var setupResult: SessionSetupResult = .success
	
	var videoDeviceInput: AVCaptureDeviceInput!
	
	@IBOutlet private weak var previewView: PreviewView!
	
	// Call this on the session queue.
	private func configureSession() {
		if setupResult != .success {
			return
		}
		
		session.beginConfiguration()
		
		/*
			We do not create an AVCaptureMovieFileOutput when setting up the session because the
			AVCaptureMovieFileOutput does not support movie recording with AVCaptureSession.Preset.Photo.
		*/
		session.sessionPreset = .photo
		
		// Add video input.
		do {
			var defaultVideoDevice: AVCaptureDevice?
			
			// Choose the back dual camera if available, otherwise default to a wide angle camera.
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
				defaultVideoDevice = dualCameraDevice
            } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
				// If the back dual camera is not available, default to the back wide angle camera.
				defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
				/*
                   In some cases where users break their phones, the back wide angle camera is not available.
                   In this case, we should default to the front wide angle camera.
                */
				defaultVideoDevice = frontCameraDevice
			}
			
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
			
			if session.canAddInput(videoDeviceInput) {
				session.addInput(videoDeviceInput)
				self.videoDeviceInput = videoDeviceInput
				
				DispatchQueue.main.async {
					/*
						Why are we dispatching this to the main queue?
						Because AVCaptureVideoPreviewLayer is the backing layer for PreviewView and UIView
						can only be manipulated on the main thread.
						Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
						on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
					
						Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
						handled by CameraViewController.viewWillTransition(to:with:).
					*/
					let statusBarOrientation = UIApplication.shared.statusBarOrientation
					var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
					if statusBarOrientation != .unknown {
						if let videoOrientation = AVCaptureVideoOrientation(interfaceOrientation: statusBarOrientation) {
							initialVideoOrientation = videoOrientation
						}
					}
					
                    self.previewView.videoPreviewLayer.connection?.videoOrientation = initialVideoOrientation
                    self.previewView.videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
				}
			} else {
				print("Could not add video device input to the session")
				setupResult = .configurationFailed
				session.commitConfiguration()
				return
			}
		} catch {
			print("Could not create video device input: \(error)")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}
		
		// Add photo output.
		if session.canAddOutput(photoOutput) {
			session.addOutput(photoOutput)
			
			photoOutput.isHighResolutionCaptureEnabled = true
			photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
            photoOutput.isDepthDataDeliveryEnabled = photoOutput.isDepthDataDeliverySupported
            
		} else {
			print("Could not add photo output to the session")
			setupResult = .configurationFailed
			session.commitConfiguration()
			return
		}
		
		session.commitConfiguration()
	}
	
	@IBAction private func resumeInterruptedSession(_ resumeButton: UIButton) {
		sessionQueue.async {
			/*
				The session might fail to start running, e.g., if a phone or FaceTime call is still
				using audio or video. A failure to start the session running will be communicated via
				a session runtime error notification. To avoid repeatedly failing to start the session
				running, we only try to restart the session running in the session runtime error handler
				if we aren't trying to resume the session running.
			*/
			self.session.startRunning()
			self.isSessionRunning = self.session.isRunning
			if !self.session.isRunning {
				DispatchQueue.main.async {
					let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
					let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
					let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
					alertController.addAction(cancelAction)
					self.present(alertController, animated: true, completion: nil)
				}
			} else {
				DispatchQueue.main.async {
					
				}
			}
		}
	}
	
	// MARK: Device Configuration
	
	@IBOutlet private weak var cameraUnavailableLabel: UILabel!
	private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera],
                                                                               mediaType: .video, position: .unspecified)

	
	@IBAction private func focusAndExposeTap(_ gestureRecognizer: UITapGestureRecognizer) {
        let devicePoint = previewView.videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: gestureRecognizer.location(in: gestureRecognizer.view))
		focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint, monitorSubjectAreaChange: true)
	}
	
    private func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                
                /*
					Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
					Call set(Focus/Exposure)Mode() to apply the new point of interest.
				*/
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
	
	// MARK: Capturing Photos

	private let photoOutput = AVCapturePhotoOutput()
	
	private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
	
	@IBOutlet private weak var photoButton: UIButton!
	@IBAction private func capturePhoto(_ photoButton: UIButton) {
		
		sessionQueue.async {
			// Update the photo output's connection to match the video orientation of the video preview layer.
            if let photoOutputConnection = self.photoOutput.connection(with: .video) {
                photoOutputConnection.videoOrientation = self.currentOrientation
			}
			
            var photoSettings = AVCapturePhotoSettings()
            // Capture HEIF photo when supported, with flash set to auto and high resolution photo enabled.
            if  self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])

            }
            
            photoSettings.flashMode = .off
            
			photoSettings.isHighResolutionPhotoEnabled = true
			if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
				photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!]
			}
			
			// Use a separate object for the photo capture delegate to isolate each capture life cycle.
			let photoCaptureProcessor = PhotoCaptureProcessor(with: photoSettings, willCapturePhotoAnimation: {
					DispatchQueue.main.async {
						self.previewView.videoPreviewLayer.opacity = 0
						UIView.animate(withDuration: 0.25) {
							self.previewView.videoPreviewLayer.opacity = 1
						}
					}
				}, livePhotoCaptureHandler: { capturing in
					self.sessionQueue.async {
						
					}
				}, completionHandler: { photoCaptureProcessor in
					// When the capture is complete, remove a reference to the photo capture delegate so it can be deallocated.
					self.sessionQueue.async {
						self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = nil
					}
				}
			)
			
			/*
				The Photo Output keeps a weak reference to the photo capture delegate so
				we store it in an array to maintain a strong reference to this object
				until the capture is completed.
			*/
			self.inProgressPhotoCaptureDelegates[photoCaptureProcessor.requestedPhotoSettings.uniqueID] = photoCaptureProcessor
			self.photoOutput.capturePhoto(with: photoSettings, delegate: photoCaptureProcessor)
		}
	}
	
	// MARK: Recording Movies
	
	private var backgroundRecordingID: UIBackgroundTaskIdentifier?
	
	// MARK: KVO and Notifications
	
	private var keyValueObservations = [NSKeyValueObservation]()
	
	private func addObservers() {
		let keyValueObservation = session.observe(\.isRunning, options: .new) { _, change in
			guard let isSessionRunning = change.newValue else { return }
			
			DispatchQueue.main.async {
				// Only enable the ability to change camera if the device has more than one camera.
				self.photoButton.isEnabled = isSessionRunning
			}
		}
		keyValueObservations.append(keyValueObservation)
		
		NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaDidChange), name: .AVCaptureDeviceSubjectAreaDidChange, object: videoDeviceInput.device)
		NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)
		
		/*
			A session can only run when the app is full screen. It will be interrupted
			in a multi-app layout, introduced in iOS 9, see also the documentation of
			AVCaptureSessionInterruptionReason. Add observers to handle these session
			interruptions and show a preview is paused message. See the documentation
			of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
		*/
		NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: .AVCaptureSessionWasInterrupted, object: session)
		NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: session)
	}
	
	private func removeObservers() {
		NotificationCenter.default.removeObserver(self)
		
		for keyValueObservation in keyValueObservations {
			keyValueObservation.invalidate()
		}
		keyValueObservations.removeAll()
	}
	
	@objc
	func subjectAreaDidChange(notification: NSNotification) {
		let devicePoint = CGPoint(x: 0.5, y: 0.5)
		focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
	}
	
	@objc
	func sessionRuntimeError(notification: NSNotification) {
		guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
		
		print("Capture session runtime error: \(error)")
		
		/*
			Automatically try to restart the session running if media services were
			reset and the last start running succeeded. Otherwise, enable the user
			to try to resume the session running.
		*/
		if error.code == .mediaServicesWereReset {
			sessionQueue.async {
				if self.isSessionRunning {
					self.session.startRunning()
					self.isSessionRunning = self.session.isRunning
				} else {
					DispatchQueue.main.async {
					}
				}
			}
		}
	}
	
	@objc
	func sessionWasInterrupted(notification: NSNotification) {
		/*
			In some scenarios we want to enable the user to resume the session running.
			For example, if music playback is initiated via control center while
			using AVCam, then the user can let AVCam resume
			the session running, which will stop music playback. Note that stopping
			music playback in control center will not automatically resume the session
			running. Also note that it is not always possible to resume, see `resumeInterruptedSession(_:)`.
		*/
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
			let reasonIntegerValue = userInfoValue.integerValue,
			let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
			print("Capture session was interrupted with reason \(reason)")
			
			if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
				// Simply fade-in a label to inform the user that the camera is unavailable.
				cameraUnavailableLabel.alpha = 0
				cameraUnavailableLabel.isHidden = false
				UIView.animate(withDuration: 0.25) {
					self.cameraUnavailableLabel.alpha = 1
				}
			}
		}
	}
	
	@objc
	func sessionInterruptionEnded(notification: NSNotification) {
		print("Capture session interruption ended")

		if !cameraUnavailableLabel.isHidden {
			UIView.animate(withDuration: 0.25,
			    animations: {
					self.cameraUnavailableLabel.alpha = 0
				}, completion: { _ in
					self.cameraUnavailableLabel.isHidden = true
				}
			)
		}
	}
    
    @IBOutlet weak var alphaSlider: UISlider!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var fileNameLabel: UILabel!
    @IBOutlet weak var imagePageControl: UIPageControl!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var selectButton: UIButton!
    @IBOutlet weak var zoomLabel: UILabel!
    
    struct File {
        var name : String
        var url : URL
    }
    
    let minimumZoom = CGFloat(1.0)
    let maximumZoom = CGFloat(5.0)
    var actualZoom = CGFloat(1.0)
    
    var files = [File]()
    
    func fixAll(){
        imagePageControl.numberOfPages = files.count
        alphaSlider.isHidden = imagePageControl.numberOfPages > 0 ? false : true
        if imagePageControl.numberOfPages < 1 {
            imageView.image = nil
            fileNameLabel.text = ""
        }
    }
    
    @IBAction func selectClicked(_ sender: Any) {
        let types = ["public.image"]
        //Create a object of document picker view and set the mode to Import
        let docPicker = UIDocumentPickerViewController(documentTypes: types, in: UIDocumentPickerMode.open)
        docPicker.allowsMultipleSelection = true
        docPicker.delegate = self
        //present the document picker
        present(docPicker, animated: true, completion: nil)
        //presentViewController:docPicker animated:YES completion:nil];
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL])
    {
        if (controller.documentPickerMode == UIDocumentPickerMode.open && urls.count > 0)
        {
            files.removeAll()
            for url in urls{
                files.append(File(name: url.lastPathComponent, url: url))
            }
            if files.count > 1 {
                files.sort(by: { $0.name < $1.name })
            }
            changeImage(toIndex: 0)
        }
    }
    
    @IBAction func alphaChanged(_ sender: Any) {
        if alphaSlider.value < 1{
            if imageView.image != nil{
                imageView.alpha = CGFloat(alphaSlider.value)
            }
            
            if (!session.isRunning){
                session.startRunning()
            }
        } else {
            session.stopRunning()
        }
    }
    
    @IBAction func clearClicked(_ sender: Any) {
        files.removeAll()
        fixAll()
    }
    
    func changeImage(toIndex: Int){
        if files[toIndex].url.startAccessingSecurityScopedResource() {
            let image = UIImage(contentsOfFile: files[toIndex].url.path)!
            imageView.image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: self.orientationMap[self.currentOrientation]!)
            fileNameLabel.text = files[toIndex].name
            fixAll()
            files[toIndex].url.stopAccessingSecurityScopedResource()
        } else {
            print("Can't access security scoped resourse")
        }
    }
    
    @IBAction func imagePageChanged(_ sender: Any) {
        changeImage(toIndex: imagePageControl.currentPage)
    }
    
    @IBAction func leftSwipe(_ sender: Any) {
        if imagePageControl.currentPage < imagePageControl.numberOfPages-1 {
            imagePageControl.currentPage += 1
            changeImage(toIndex: imagePageControl.currentPage)
        }
    }
    
    @IBAction func rightSwipe(_ sender: Any) {
        if imagePageControl.currentPage > 0 {
            imagePageControl.currentPage -= 1
            changeImage(toIndex: imagePageControl.currentPage)
        }
    }
    
    @IBAction func zoomChanged(_ sender: UIPinchGestureRecognizer) {
        let device = videoDeviceInput.device
        actualZoom = min(min(max(actualZoom + sender.velocity/25, minimumZoom), maximumZoom), device.activeFormat.videoMaxZoomFactor)
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = actualZoom
            zoomLabel.text = "\(round(actualZoom*100)/100)x"
            device.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
        }
        
        UIView.animate(withDuration: 0.1) {
            self.zoomLabel.alpha = 1
        }
        UIView.animate(withDuration: 0.25) {
            self.zoomLabel.alpha = 0
        }
    }
    
    let motion = CMMotionManager()
    var timer : Timer?
    
    var currentOrientation : AVCaptureVideoOrientation = .portrait
    
    var orientationMap: [AVCaptureVideoOrientation : UIImageOrientation] = [
        .portrait : .up,
        .landscapeLeft : .left,
        .landscapeRight : .right,
        .portraitUpsideDown : .down
    ]
    
    func startGyros() {
        if motion.isDeviceMotionAvailable {
            self.motion.deviceMotionUpdateInterval = 1.0 / 5.0
            self.motion.showsDeviceMovementDisplay = true
            self.motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            
            self.timer = Timer(fire: Date(), interval: (1.0/5.0), repeats: true,
                               block: { (timer) in
                                if let data = self.motion.deviceMotion {
                                    
                                    let x = data.attitude.pitch
                                    let y = data.attitude.roll
                                    
                                    if x > 0.75 {
                                        self.currentOrientation = .portrait
                                    } else if x < 0.75 && x > -0.75 {
                                        if y > 0.75 {
                                            self.currentOrientation = .landscapeLeft
                                        } else if y < -0.75 {
                                            self.currentOrientation = .landscapeRight
                                        }
                                    } else if x < -0.75 {
                                        self.currentOrientation = .portraitUpsideDown
                                    }
                                    
                                    if self.imageView.image != nil && self.imageView.image?.imageOrientation != self.orientationMap[self.currentOrientation] {
                                        let image = self.imageView.image!
                                        self.imageView.image = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: self.orientationMap[self.currentOrientation]!)
                                    }
                                }
            })
            
            RunLoop.current.add(self.timer!, forMode: .defaultRunLoopMode)
        }
    }
}

extension AVCaptureVideoOrientation {
	init?(deviceOrientation: UIDeviceOrientation) {
		switch deviceOrientation {
			case .portrait: self = .portrait
			case .portraitUpsideDown: self = .portraitUpsideDown
			case .landscapeLeft: self = .landscapeRight
			case .landscapeRight: self = .landscapeLeft
			default: return nil
		}
	}
	
	init?(interfaceOrientation: UIInterfaceOrientation) {
		switch interfaceOrientation {
			case .portrait: self = .portrait
			case .portraitUpsideDown: self = .portraitUpsideDown
			case .landscapeLeft: self = .landscapeLeft
			case .landscapeRight: self = .landscapeRight
			default: return nil
		}
	}
}

extension AVCaptureDevice.DiscoverySession {
	var uniqueDevicePositionsCount: Int {
        var uniqueDevicePositions: [AVCaptureDevice.Position] = []
        
        for device in devices {
            if !uniqueDevicePositions.contains(device.position) {
                uniqueDevicePositions.append(device.position)
            }
        }
        
        return uniqueDevicePositions.count
    }
}
