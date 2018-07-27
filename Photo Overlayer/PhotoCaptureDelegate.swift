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
    
    var actialFile : CameraViewController.File?
    
    var zoomValue = CGFloat()

	init(with requestedPhotoSettings: AVCapturePhotoSettings,
	     willCapturePhotoAnimation: @escaping () -> Void,
	     livePhotoCaptureHandler: @escaping (Bool) -> Void,
	     completionHandler: @escaping (PhotoCaptureProcessor) -> Void) {
        if CameraViewController.filesQueue.count > 0{
            actialFile = CameraViewController.filesQueue.first!
            CameraViewController.filesQueue.remove(at: 0)
        }
        zoomValue = CameraViewController.actualZoom
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
                    if self.actialFile != nil && !self.actialFile!.url.path.starts(with: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].path){
                        if var data = croppedImage.jpegData(compressionQuality: 1.0){
                            do {
                                var newPath = self.actialFile!.url.deletingLastPathComponent().appendingPathComponent(self.actialFile!.url.deletingPathExtension().lastPathComponent, isDirectory: true)
                                var i = 1
                                try FileManager.default.createDirectory(at: newPath, withIntermediateDirectories: true, attributes: nil)
                                while FileManager.default.fileExists(atPath: newPath.appendingPathComponent("\(i).\(self.actialFile!.url.pathExtension)", isDirectory: false).path){
                                    i += 1
                                }
                                newPath = newPath.appendingPathComponent("\(i).\(self.actialFile!.url.pathExtension)")
                                
                                data = self.addZoomToExif(imageData: data, zoomValue: self.zoomValue, orientation: image!.imageOrientation)
                                // writes the image data to disk
                                try data.write(to: newPath)
                            } catch {
                                print("error saving file:", error)
                            }
                        }
                    } else {
                        UIImageWriteToSavedPhotosAlbum(croppedImage, nil, nil, nil)
                        
                        /*let options = PHAssetResourceCreationOptions()
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        options.uniformTypeIdentifier = self.requestedPhotoSettings.processedFileType.map { $0.rawValue }
                        creationRequest.addResource(with: .photo, data: photoData, options: options)*/
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
    
    func addZoomToExif(imageData: Data, zoomValue: CGFloat, orientation: UIImage.Orientation) -> Data{
        let cgImgSource: CGImageSource = CGImageSourceCreateWithData(imageData as CFData, nil)!
        let uti: CFString = CGImageSourceGetType(cgImgSource)!
        let dataWithEXIF: NSMutableData = NSMutableData(data: imageData)
        let destination: CGImageDestination = CGImageDestinationCreateWithData((dataWithEXIF as CFMutableData), uti, 1, nil)!
        
        
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(cgImgSource, 0, nil)! as NSDictionary
        let mutable: NSMutableDictionary = imageProperties.mutableCopy() as! NSMutableDictionary
        
        print("Mutable before: \(mutable)")
        
        let EXIFDictionary: NSMutableDictionary = (mutable[kCGImagePropertyExifDictionary as String] as? NSMutableDictionary)!
        
        print("EXIF before: \(EXIFDictionary)")
        
        EXIFDictionary[kCGImagePropertyExifUserComment as String] = "zoomValue:\(zoomValue);"
        
        mutable[kCGImagePropertyExifDictionary as String] = EXIFDictionary
        
        CGImageDestinationAddImageFromSource(destination, cgImgSource, 0, (mutable as CFDictionary))
        CGImageDestinationFinalize(destination)
        
        let testImage: CIImage = CIImage(data: dataWithEXIF as Data, options: nil)!
        let newproperties: NSDictionary = testImage.properties as NSDictionary
        
        print("EXIF after: \(newproperties)")
        return dataWithEXIF as Data
    }
}
