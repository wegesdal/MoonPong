//
//  ViewController.swift
//  MoonPong
//
//  Created by Will Egesdal on 4/23/2018
//  Copyright (c) 2018 Will Egesdal. All rights reserved.
//

import UIKit
import SceneKit
import Foundation

struct CollisionCategory {
    
    static let None: Int = 0b00000000
    static let All: Int = 0b11111111
    static let Map: Int = 0b00000001
    static let Player: Int = 0b00000010
    static let Monster: Int = 0b00000100
    static let Bullet: Int = 0b00001000
}

class GameViewController: UIViewController, UIGestureRecognizerDelegate, SCNSceneRendererDelegate {
    
    //MARK: config
    let autofireTapTimeThreshold = 0.2
    let maxRoundsPerSecond = 30
    let bulletRadius = 100.00
    let bulletImpulse = 2
    let maxBullets = 100
    let gravity = CGFloat(60000)
    
    @IBOutlet var sceneView: SCNView!
    var lookGesture: UIPanGestureRecognizer!
    var walkGesture: UIPanGestureRecognizer!
    var zoomGesture: UIPinchGestureRecognizer!
    var fireGesture: FireGestureRecognizer!
    var player: SCNNode!
    var block: SCNNode!
    var camNode: SCNNode!
    var cameraPosition: SCNNode!
    var elevation: Float = 0
    
    var tapCount = 0
    var lastTappedFire: TimeInterval = 0
    var lastFired: TimeInterval = 0
    var bullets = [SCNNode]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //create a new scene
        let scene = SCNScene()
        scene.physicsWorld.timeStep = 1.0/360
        scene.background.contents = UIImage(named: "skybox.png")
        
        //sceneView.debugOptions = [.showPhysicsShapes]
        //Configure world and add to scene
        let moon = SCNMaterial()
        moon.isDoubleSided = false
        moon.diffuse.contents = UIImage(named: "moon_surface.png")
        moon.diffuse.contentsTransform = SCNMatrix4MakeScale(1.0, 1.0, 0)
        moon.diffuse.wrapS = SCNWrapMode.repeat
        moon.diffuse.wrapT = SCNWrapMode.repeat
        let world = SCNNode(geometry: SCNSphere(radius: 64))
        world.position = SCNVector3Make(0, -32, 0)
        world.geometry?.firstMaterial = moon
        world.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: world.geometry!, options: nil))
        
        world.physicsBody?.categoryBitMask = CollisionCategory.Map
        world.physicsBody?.collisionBitMask = CollisionCategory.All
        scene.rootNode.addChildNode(world)
        
        //Configure radial gravity and add to scene
        let gravityNode = SCNNode()
        let radialGravityField = SCNPhysicsField.radialGravity()
        radialGravityField.categoryBitMask = CollisionCategory.Bullet
        gravityNode.position = SCNVector3Make(0, -32, 0)
        gravityNode.physicsField = radialGravityField
        radialGravityField.strength = gravity
        scene.rootNode.addChildNode(gravityNode)
        
        //Disable default gravity
        scene.physicsWorld.gravity = SCNVector3Make(0, 0, 0)
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 90, z: 0)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        //Build Net
        //        let voxelArray = loadPlistArray()
        //        let compactMapped: [Int] = voxelArray.compactMap { str in Int(str) }
        //        print(compactMapped)
        //        voxelObjectFromArray(position: SCNVector3(x: -25, y: -25, z:25), scene: scene, array: compactMapped)
        
        //player
        player = SCNNode()
        player.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNBox(width: 1.0, height: 1.0,  length: 1.0, chamferRadius: 0.0), options: nil))
        player.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "tile117")
        player.physicsBody?.angularDamping = 0.6
        player.physicsBody?.damping = 0.6
        player.physicsBody?.rollingFriction = 0.2
        player.physicsBody?.friction = 0.2
        player.physicsBody?.velocityFactor = SCNVector3(x: 1, y: 1, z: 1)
        player.physicsBody?.categoryBitMask = CollisionCategory.Player
        player.physicsField?.categoryBitMask = CollisionCategory.Player
        player.physicsBody?.collisionBitMask = CollisionCategory.All ^ CollisionCategory.Bullet
        if #available(iOS 9.0, *) {
            player.physicsBody?.contactTestBitMask = ~0
        }
        
        //Test Racquet
        let stone = SCNMaterial()
        stone.isDoubleSided = true
        stone.diffuse.contents = UIColor.red
        //        stone.diffuse.contentsTransform = SCNMatrix4MakeScale(4.0, 4.0, 4.0)
        //        stone.diffuse.wrapS = SCNWrapMode.repeat
        //        stone.diffuse.wrapT = SCNWrapMode.repeat
        block = SCNNode(geometry: SCNBox(width: 8, height: 8, length: 1, chamferRadius: 16.0))
        block.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.kinematic, shape: SCNPhysicsShape(geometry: block.geometry!, options: nil))
        block.opacity = 0.3
        block.physicsBody?.mass = 100
        block.physicsBody?.categoryBitMask = CollisionCategory.Map
        block.physicsBody?.collisionBitMask = CollisionCategory.Bullet
        block.geometry?.firstMaterial = stone
        block.rotation = SCNVector4(x: Float(Double.pi/32), y: 0, z: 0, w: 0.28)
        block.position = SCNVector3(x: 0, y: -8, z: 0)
        
        
        let lookAtWorldConstraint = SCNLookAtConstraint(target: world)
        lookAtWorldConstraint.isGimbalLockEnabled = true
        player.constraints = [lookAtWorldConstraint]
        block.constraints = [lookAtWorldConstraint]
        block.constraints = nil
        player.position = SCNVector3(x: 0, y: 128, z: 0)
        scene.rootNode.addChildNode(player)
        player.addChildNode(block)
        
        //add a camera node
        camNode = SCNNode()
        camNode.position = SCNVector3(x: 0, y: 0, z: 16)
        player.addChildNode(camNode)
        
        //add camera
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = Double(max(1000, 1000))
        camNode.camera = camera
        
        
        let lookAtBallConstraint = SCNLookAtConstraint(target: player)
        lookAtBallConstraint.isGimbalLockEnabled = true
        
        let tempCam = SCNCamera()
        tempCam.zFar = 5000
        camNode = SCNNode()
        camNode.camera = tempCam
        camNode.position = SCNVector3(x: 0, y: 0, z: 0)
        camNode.constraints = [lookAtBallConstraint]
        
        cameraPosition = SCNNode()
        cameraPosition.position = SCNVector3(x: 0, y: 5, z: 12)
        cameraPosition.addChildNode(camNode)
        
        
        //set the scene to the view
        sceneView.scene = scene
        sceneView.delegate = self
        
        //show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        //configure the view
        sceneView.backgroundColor = UIColor.black
        
        //look gesture
        lookGesture = UIPanGestureRecognizer(target: self, action: #selector(GameViewController.lookGestureRecognized))
        lookGesture.delegate = self
        view.addGestureRecognizer(lookGesture)
        
        //zoom gesture
        zoomGesture = UIPinchGestureRecognizer(target: self, action: #selector(GameViewController.zoomGestureRecognized))
        zoomGesture.delegate = self
        view.addGestureRecognizer(zoomGesture)
        
        //walk gesture
        walkGesture = UIPanGestureRecognizer(target: self, action: #selector(GameViewController.walkGestureRecognized))
        walkGesture.delegate = self
        view.addGestureRecognizer(walkGesture)
        
        //fire gesture
        fireGesture = FireGestureRecognizer(target: self, action: #selector(GameViewController.fireGestureRecognized))
        fireGesture.delegate = self
        view.addGestureRecognizer(fireGesture)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        if gestureRecognizer == zoomGesture {
            return true
        } else {
            if gestureRecognizer == lookGesture {
                return touch.location(in: view).x > view.frame.size.width / 2
                
            } else if gestureRecognizer == walkGesture {
                return touch.location(in: view).x < view.frame.size.width / 2
                
            }
            return true
        }
    }
    
    private func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return true
    }
    
    @objc func lookGestureRecognized(gesture: UIPanGestureRecognizer) {
        
        //get translation and convert to rotation
        let translation = gesture.translation(in: self.view)
        block.position.x = block.presentation.position.x + Float(translation.x / 2)
        block.position.y = block.presentation.position.y + Float(translation.y * -1 / 2)
        if block.position.x > 0 {
            block.position.z = block.presentation.position.z - Float((translation.x)) / 2
        } else {
            block.position.z = block.presentation.position.z + Float((translation.x)) / 2
        }
        
        block.rotation.w = block.presentation.rotation.w + Float(translation.y / 128)
        
        print(translation.x)
        print(block.position)
        print(block.rotation)
        
        
        
        gesture.setTranslation(.zero, in: self.view)
        if gesture.state == UIGestureRecognizerState.ended || gesture.state == UIGestureRecognizerState.cancelled {
            block.position = SCNVector3(0, -8, 0)
            block.rotation.w = 0.28
        }
        
    }
    
    @objc func zoomGestureRecognized(gesture: UIPinchGestureRecognizer) {
        
        let frontDirection = player.presentation.convertVector(SCNNode.localFront , to: nil)
        let scale = gesture.scale
        let velocity = gesture.velocity
        var impulse = SCNVector3(x: 0, y: 0, z: max(-1, min(1, Float(scale * velocity * 6))))
        impulse = SCNVector3(
            x: frontDirection.x * Float(impulse.z) * 10,
            y: frontDirection.y * Float(impulse.z) * 10,
            z: frontDirection.z * Float(impulse.z) * 10
        )
        player.physicsBody?.applyForce(impulse, asImpulse: true)
        if gesture.state == UIGestureRecognizerState.ended || gesture.state == UIGestureRecognizerState.cancelled {
        }
    }
    
    @objc func walkGestureRecognized(gesture: UIPanGestureRecognizer) {
        //get walk gesture translation
        let translation = walkGesture.translation(in: self.view)
        let strafeDirection = player.presentation.convertVector(SCNNode.localRight, to: nil)
        let upDirection = player.presentation.convertVector(SCNNode.localUp, to: nil)
        var impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 25)), y: 0, z: max(-1, min(1, Float(-translation.y) / 25)))
        impulse = SCNVector3(
            x: upDirection.x * Float(impulse.z) * 5 + strafeDirection.x * Float(impulse.x) * 5,
            y: upDirection.y * Float(impulse.z) * 5 + strafeDirection.y * Float(impulse.x) * 5,
            z: upDirection.z * Float(impulse.z) * 5 + strafeDirection.z * Float(impulse.x) * 5
        )
        
        player.physicsBody?.applyForce(impulse, asImpulse: true)
        
        if gesture.state == UIGestureRecognizerState.ended || gesture.state == UIGestureRecognizerState.cancelled {
            gesture.setTranslation(.zero, in: self.view)
        }
    }
    
    @objc func fireGestureRecognized(gesture: FireGestureRecognizer) {
        
        //update timestamp
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTappedFire < autofireTapTimeThreshold {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTappedFire = now
    }
    
    func renderer(_ aRenderer: SCNSceneRenderer, didApplyAnimationsAtTime time: TimeInterval) {
        let frontDirection = player.presentation.convertVector(SCNNode.localFront, to: nil)
        let cameraP = SCNVector3(x: player.presentation.position.x, y: player.presentation.position.y + 5, z: player.presentation.position.z + 12)
        cameraPosition.position = cameraP
        
        player.position = player.presentation.position
        player.rotation = player.presentation.rotation
        
        //handle firing
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTappedFire < autofireTapTimeThreshold {
            let fireRate = min(Double(maxRoundsPerSecond), Double(tapCount) / autofireTapTimeThreshold)
            if now - lastFired > 1 / fireRate {
                
                //create or recycle bullet node
                let ball: SCNNode = {
                    if self.bullets.count < self.maxBullets {
                        return SCNNode()
                    } else {
                        return self.bullets.remove(at: 0)
                    }
                }()
                
                bullets.append(ball)
                ball.geometry = SCNSphere(radius: 2.0)
                ball.position = SCNVector3(x: player.presentation.position.x, y: player.presentation.position.y, z: player.presentation.position.z)
                ball.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: ball.geometry!, options: nil))
                ball.geometry?.firstMaterial?.locksAmbientWithDiffuse = true
                ball.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
                ball.physicsBody?.mass = 0.01
                ball.physicsBody?.categoryBitMask = CollisionCategory.Bullet
                ball.physicsBody?.collisionBitMask = CollisionCategory.All ^ CollisionCategory.Player
                ball.physicsBody?.velocityFactor = SCNVector3(x: 1.0, y: 1.0, z: 1.0)
                ball.physicsBody?.restitution = 2.0
                self.sceneView.scene!.rootNode.addChildNode(ball)
                
                //apply impulse
                let impulse = SCNVector3(x: frontDirection.x * Float(bulletImpulse), y: frontDirection.y * Float(bulletImpulse), z: frontDirection.z * Float(bulletImpulse))
                ball.physicsBody?.applyForce(impulse, asImpulse: true)
                
                //update timestamp
                lastFired = now
            }
        }
    }
}

