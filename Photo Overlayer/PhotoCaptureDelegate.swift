/*
See LICENSE.txt for this sample’s licensing information.

Abstract:
Photo capture delegate.
*/

import AVFoundation
import Photos

class PhotoCaptureProcessor: NSObject {
	private(set) var requestedPhotoSettings: AVCapturePhotoSettings
	
	private let willCapturePhotoAnimation: () -> Void
	
	private let livePhotoCaptureHandler: (Bool) -> Void
	
	private let completionHandler: (PhotoCaptureProcessor) -> Void
	
	private var photoData: Data?
	
	private var livePhotoCompanionMovieURL: URL?
    
    var actualQueueItem : CameraViewController.queueItem?
    
    var actualFile : CameraViewController.File?
    
    var zoomValue = CGFloat(1.0)
    var fovValue = Float(1.0)

	init(with requestedPhotoSettings: AVCapturePhotoSettings,
	     willCapturePhotoAnimation: @escaping () -> Void,
	     livePhotoCaptureHandler: @escaping (Bool) -> Void,
	     completionHandler: @escaping (PhotoCaptureProcessor) -> Void) {
        if CameraViewController.filesQueue.count > 0{
            actualQueueItem = CameraViewController.filesQueue.first!
            CameraViewController.filesQueue.remove(at: 0)
            actualFile = actualQueueItem!.file
            zoomValue = actualQueueItem!.zoom
            fovValue = actualQueueItem!.fov
        }
		self.requestedPhotoSettings = requestedPhotoSettings
		self.willCapturePhotoAnimation = willCapturePhotoAnimation
		self.livePhotoCaptureHandler = livePhotoCaptureHandler
		self.completionHandler = completionHandler
	}
	
	private func didFinish() {
		if let livePhotoCompanionMoviePath = livePhotoCompanionMovieURL?.path {
			if FileManager.default.fileExists(atPath: livePhotoCompanionMoviePath) {
				do {
					try FileManager.default.removeItem(atPath: livePhotoCompanionMoviePath)
				} catch {
					print("Could not remove file at url: \(livePhotoCompanionMoviePath)")
				}
			}
		}
		
		completionHandler(self)
	}
    
}

extension PhotoCaptureProcessor: AVCapturePhotoCaptureDelegate {
    /*
     This extension includes all the delegate callbacks for AVCapturePhotoCaptureDelegate protocol
    */
    
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if resolvedSettings.livePhotoMovieDimensions.width > 0 && resolvedSettings.livePhotoMovieDimensions.height > 0 {
            livePhotoCaptureHandler(true)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        willCapturePhotoAnimation()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error {
            print("Error capturing photo: \(error)")
        } else {
            photoData = photo.fileDataRepresentation()
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        livePhotoCaptureHandler(false)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if error != nil {
            print("Error processing live photo companion movie: \(String(describing: error))")
            return
        }
        livePhotoCompanionMovieURL = outputFileURL
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            didFinish()
            return
        }
        
        guard let photoData = photoData else {
            print("No photo data resource")
            didFinish()
            return
        }
        
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    
                    let image = UIImage(data:photoData,scale:1.0)
                    
                    let dX: CGFloat = 0
                    let dY = (image!.size.height - ((image!.size.width/16)*9))/2
                    let dW = image!.size.width
                    let dH = (image!.size.width/16)*9
                    
                    let rect = CGRect(x: dX, y: dY, width: dW, height: dH)
                    
                    let imageRef = image?.cgImage?.cropping(to: rect)
                    
                    let croppedImage = UIImage(cgImage: imageRef!, scale: image!.scale, orientation: image!.imageOrientation)
                    if var data = croppedImage.jpegData(compressionQuality: 1.0){
                        data = self.addDataToExif(imageData: data, zoomValue: self.zoomValue, fov: self.fovValue, orientation: image!.imageOrientation)
                        if self.actualFile != nil && !self.actualFile!.url.path.starts(with: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path){
                                do {
                                    var newPath = self.actualFile!.url.deletingLastPathComponent().appendingPathComponent(self.actualFile!.url.deletingPathExtension().lastPathComponent, isDirectory: true)
                                    var i = 1
                                    try FileManager.default.createDirectory(at: newPath, withIntermediateDirectories: true, attributes: nil)
                                    while FileManager.default.fileExists(atPath: newPath.appendingPathComponent("\(i).\(self.actualFile!.url.pathExtension)", isDirectory: false).path){
                                        i += 1
                                    }
                                    newPath = newPath.appendingPathComponent("\(i).\(self.actualFile!.url.pathExtension)")
                                    
                                    // writes the image data to disk
                                    try data.write(to: newPath)
                                } catch {
                                    print("error saving file:", error)
                                }
                            
                        } else {
                            //UIImageWriteToSavedPhotosAlbum(croppedImage, nil, nil, nil)
                            
                            let options = PHAssetResourceCreationOptions()
                            let creationRequest = PHAssetCreationRequest.forAsset()
                            options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType.map { $0.rawValue }
                            creationRequest.addResource(with: .photo, data: data, options: options)
                        }
                    }
                }, completionHandler: { _, error in
                    if let error = error {
                        print("Error occurered while saving photo to photo library: \(error)")
                    }
                    self.didFinish()
                })
            } else {
                self.didFinish()
            }
        }
    }
    
    func addDataToExif(imageData: Data, zoomValue: CGFloat, fov: Float, orientation: UIImage.Orientation) -> Data{
        let cgImgSource: CGImageSource = CGImageSourceCreateWithData(imageData as CFData, nil)!
        let uti: CFString = CGImageSourceGetType(cgImgSource)!
        let dataWithEXIF: NSMutableData = NSMutableData(data: imageData)
        let destination: CGImageDestination = CGImageDestinationCreateWithData((dataWithEXIF as CFMutableData), uti, 1, nil)!
        
        
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(cgImgSource, 0, nil)! as NSDictionary
        let mutable: NSMutableDictionary = imageProperties.mutableCopy() as! NSMutableDictionary
        
        let EXIFDictionary: NSMutableDictionary = (mutable[kCGImagePropertyExifDictionary as String] as? NSMutableDictionary)!
        
        EXIFDictionary[kCGImagePropertyExifUserComment as String] = "zoomValue:\(zoomValue);fov:\(fov)"
        
        mutable[kCGImagePropertyExifDictionary as String] = EXIFDictionary
        
        CGImageDestinationAddImageFromSource(destination, cgImgSource, 0, (mutable as CFDictionary))
        CGImageDestinationFinalize(destination)
        
        return dataWithEXIF as Data
    }
}
