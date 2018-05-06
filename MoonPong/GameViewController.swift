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
import GameplayKit

struct CollisionCategory {
    
    static let None: Int = 0b00000000
    static let All: Int = 0b11111111
    static let Map: Int = 0b00000001
    static let Player: Int = 0b00000010
    static let Ball: Int = 0b00001000
}

class GameViewController: UIViewController, UIGestureRecognizerDelegate, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {
    
    //MARK: config
    var stateMachine: GKStateMachine!
    var previousUpdateTime: TimeInterval = 0
    let autofireTapTimeThreshold = 0.2
    let maxRoundsPerSecond = 30
    let ballRadius = 100.00
    static let ballImpulse = 3
    static var tracer: SCNNode!
    let maxBalls = 1
    let gravity = CGFloat(20000)
    
    @IBOutlet var sceneView: SCNView!
    var lookGesture: UIPanGestureRecognizer!
    var walkGesture: UIPanGestureRecognizer!
    var zoomGesture: UIPinchGestureRecognizer!
    var fireGesture: FireGestureRecognizer!
    static var player1: SCNNode!
    static var player2: SCNNode!
    static var paddle1: SCNNode!
    static var paddle2: SCNNode!
    static var ball: SCNNode!
    var camNode: SCNNode!
    var cameraPosition: SCNNode!
    var elevation: Float = 0
    
    var tapCount = 0
    var lastTappedFire: TimeInterval = 0
    var lastFired: TimeInterval = 0
    var balls = [SCNNode]()
    var tracers = [SCNNode]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Creates and adds states to the opponent's state machine.
        // Create the states
        let incomingBall = Striking()
        let striking = Striking()
        stateMachine = GKStateMachine(states: [
            incomingBall, striking
            ])
        
        // Tells the state machine to enter the SquaringUp state.
        stateMachine.enter(Striking.self)
        
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
        
        
        
        let bounds = wallsForBox(box: SCNBox(width: 256, height: 128, length: 512, chamferRadius: 0.0), thickness: 1.0)
        bounds.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(bounds)
        
        
        
        let world = SCNNode()
        world.geometry = SCNSphere(radius: 32)
        world.name = "world"
        world.position = SCNVector3Make(0, -16, 0)
        world.geometry?.firstMaterial = moon
        world.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: world.geometry!, options: nil))
        
        world.physicsBody?.categoryBitMask = CollisionCategory.Map
        world.physicsBody?.collisionBitMask = CollisionCategory.All
        world.physicsBody?.contactTestBitMask = CollisionCategory.All
        scene.rootNode.addChildNode(world)
        
        //Configure radial gravity and add to scene
        let gravityNode = SCNNode()
        let radialGravityField = SCNPhysicsField.radialGravity()
        radialGravityField.categoryBitMask = CollisionCategory.Ball
        gravityNode.position = SCNVector3(0, -16, 0)
        gravityNode.physicsField = radialGravityField
        radialGravityField.strength = gravity
        scene.rootNode.addChildNode(gravityNode)
        
        //Disable default gravity
        scene.physicsWorld.gravity = SCNVector3(0, 0, 0)
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3( 0, 90, 0)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        
        let lookAtWorldConstraint = SCNLookAtConstraint(target: world)
        lookAtWorldConstraint.isGimbalLockEnabled = true
        
        //ball
        GameViewController.ball = SCNNode()
        
        //player
        GameViewController.player1 = SCNNode()
        GameViewController.player1.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNBox(width: 1.0, height: 1.0,  length: 1.0, chamferRadius: 0.0), options: nil))
        GameViewController.player1.physicsBody?.angularDamping = 0.6
        GameViewController.player1.physicsBody?.damping = 0.6
        GameViewController.player1.physicsBody?.rollingFriction = 0.2
        GameViewController.player1.physicsBody?.friction = 0.2
        GameViewController.player1.physicsBody?.velocityFactor = SCNVector3(x: 1, y: 1, z: 0)
        GameViewController.player1.physicsBody?.categoryBitMask = CollisionCategory.Player
        GameViewController.player1.physicsBody?.collisionBitMask = CollisionCategory.All ^ CollisionCategory.Ball
        GameViewController.player1.physicsField?.categoryBitMask = CollisionCategory.Player
        GameViewController.player1.position = SCNVector3(x: 0, y: 0, z: -255)
        GameViewController.player1.constraints = [lookAtWorldConstraint]
        
        GameViewController.player2 = SCNNode()
        GameViewController.player2.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: SCNBox(width: 1.0, height: 1.0,  length: 1.0, chamferRadius: 0.0), options: nil))
        GameViewController.player2.physicsBody?.angularDamping = 0.6
        GameViewController.player2.physicsBody?.damping = 0.6
        GameViewController.player2.physicsBody?.rollingFriction = 0.2
        GameViewController.player2.physicsBody?.friction = 0.2
        GameViewController.player2.physicsBody?.velocityFactor = SCNVector3(x: 1, y: 1, z: 0)
        GameViewController.player2.physicsBody?.categoryBitMask = CollisionCategory.Player
        GameViewController.player2.physicsBody?.collisionBitMask = CollisionCategory.All ^ CollisionCategory.Ball
        GameViewController.player2.physicsField?.categoryBitMask = CollisionCategory.Player
        GameViewController.player2.position = SCNVector3(x: 0, y: 0, z: 255)
        GameViewController.player2.constraints = [lookAtWorldConstraint]
        
        //paddle 1
        GameViewController.paddle1 = SCNNode()
        GameViewController.paddle1.geometry = SCNBox(width: 8, height: 8, length: 1, chamferRadius: 16.0)
        GameViewController.paddle1.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        GameViewController.paddle1.name = "paddle1"
        GameViewController.paddle1.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.kinematic, shape: SCNPhysicsShape(geometry: GameViewController.paddle1.geometry!, options: nil))
        GameViewController.paddle1.opacity = 0.3
        GameViewController.paddle1.physicsBody?.mass = 100
        GameViewController.paddle1.physicsBody?.categoryBitMask = CollisionCategory.Map
        GameViewController.paddle1.physicsBody?.collisionBitMask = CollisionCategory.Ball
        GameViewController.paddle1.physicsBody?.contactTestBitMask = CollisionCategory.Ball
//        GameViewController.paddle1.rotation = SCNVector4(x: Float(Double.pi/32), y: 0, z: 0, w: 0.28)
        GameViewController.paddle1.position = SCNVector3(x: 0, y: -16, z: 0)
        GameViewController.paddle1.constraints = nil

        //paddle 2
        GameViewController.paddle2 = SCNNode()
        GameViewController.paddle2.geometry = SCNBox(width: 8, height: 8, length: 1, chamferRadius: 16.0)
        GameViewController.paddle2.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        GameViewController.paddle2.name = "paddle2"
        GameViewController.paddle2.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.kinematic, shape: SCNPhysicsShape(geometry: GameViewController.paddle2.geometry!, options: nil))
        GameViewController.paddle2.opacity = 1.0
        GameViewController.paddle2.physicsBody?.mass = 100
        GameViewController.paddle2.physicsBody?.categoryBitMask = CollisionCategory.Map
        GameViewController.paddle2.physicsBody?.collisionBitMask = CollisionCategory.Ball
        GameViewController.paddle2.physicsBody?.contactTestBitMask = CollisionCategory.Ball
//        GameViewController.paddle2.rotation = SCNVector4(x: Float(Double.pi/32), y: 0, z: 0, w: 0.28)
        GameViewController.paddle2.position = SCNVector3(x: 0, y: -16, z: 0)
        GameViewController.paddle2.constraints = nil
        
        scene.rootNode.addChildNode(GameViewController.player1)
        GameViewController.player1.addChildNode(GameViewController.paddle1)
        
        scene.rootNode.addChildNode(GameViewController.player2)
        GameViewController.player2.addChildNode(GameViewController.paddle2)
        
        //add a camera node
        camNode = SCNNode()
        camNode.position = SCNVector3(x: 0, y: 0, z: 48)
        GameViewController.player1.addChildNode(camNode)

        
        //add camera
        let camera = SCNCamera()
        camera.zNear = 0.01
        camera.zFar = Double(max(1000, 1000))
        camNode.camera = camera
        let lookAtPlayerConstraint = SCNLookAtConstraint(target: GameViewController.player1)
        lookAtPlayerConstraint.isGimbalLockEnabled = true
        camNode.constraints = [lookAtPlayerConstraint]
        
        
        //set the scene to the view
        sceneView.scene = scene
        sceneView.delegate = self
        sceneView.scene = scene
        sceneView.scene?.physicsWorld.contactDelegate = self
        
        //show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
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
        GameViewController.paddle1.position.x = GameViewController.paddle1.presentation.position.x + Float(translation.x / 2)
        GameViewController.paddle1.position.y = GameViewController.paddle1.presentation.position.y + Float(translation.y * -1 / 2)
        
        
        gesture.setTranslation(.zero, in: self.view)
        if gesture.state == UIGestureRecognizerState.ended || gesture.state == UIGestureRecognizerState.cancelled {
            GameViewController.paddle1.position = SCNVector3(0, -16, 0)
        }
        
    }
    
    @objc func zoomGestureRecognized(gesture: UIPinchGestureRecognizer) {
        
        let frontDirection = GameViewController.player1.presentation.convertVector(SCNNode.localFront , to: nil)
        let scale = gesture.scale
        let velocity = gesture.velocity
        var impulse = SCNVector3(x: 0, y: 0, z: max(-1, min(1, Float(scale * velocity * 6))))
        impulse = SCNVector3(
            x: frontDirection.x * Float(impulse.z) * 10,
            y: frontDirection.y * Float(impulse.z) * 10,
            z: frontDirection.z * Float(impulse.z) * 10
        )
        GameViewController.player1.physicsBody?.applyForce(impulse, asImpulse: true)
        if gesture.state == UIGestureRecognizerState.ended || gesture.state == UIGestureRecognizerState.cancelled {
        }
    }
    
    @objc func walkGestureRecognized(gesture: UIPanGestureRecognizer) {
        
        //get walk gesture translation
        let translation = walkGesture.translation(in: self.view)
        let strafeDirection = GameViewController.player1.convertVector(SCNNode.localRight, to: nil)
        let upDirection = GameViewController.player1.convertVector(SCNNode.localUp, to: nil)
        var impulse = SCNVector3(x: max(-1, min(1, Float(translation.x) / 25)), y: 0, z: max(-1, min(1, Float(-translation.y) / 25)))
        impulse = SCNVector3(
            x: upDirection.x * Float(impulse.z) * 5 + strafeDirection.x * Float(impulse.x) * 5,
            y: upDirection.y * Float(impulse.z) * 5 + strafeDirection.y * Float(impulse.x) * 5,
            z: upDirection.z * Float(impulse.z) * 5 + strafeDirection.z * Float(impulse.x) * 5
        )
        
        GameViewController.player1.physicsBody?.applyForce(impulse, asImpulse: true)
        
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
    
    func renderer(_ aRenderer: SCNSceneRenderer, didApplyAnimationsAtTime currentTime: TimeInterval) {
        
            // Calculate the time change since the previous update.
        let timeSincePreviousUpdate = currentTime - previousUpdateTime
            
        // The Empty state uses this to keep the indicator light flashing.
        stateMachine.update(deltaTime: timeSincePreviousUpdate)
            
        /*
        Set previousUpdateTime to the current time, so the next update has
        accurate information.
        */
        previousUpdateTime = currentTime
        
        let frontDirection = GameViewController.player1.presentation.convertVector(SCNNode.localFront, to: nil)
        
        GameViewController.player1.position = GameViewController.player1.presentation.position
        GameViewController.player1.rotation = GameViewController.player1.presentation.rotation
        
        //handle firing
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTappedFire < autofireTapTimeThreshold {
            let fireRate = min(Double(maxRoundsPerSecond), Double(tapCount) / autofireTapTimeThreshold)
            if now - lastFired > 1 / fireRate {
                //create or recycle ball node
                GameViewController.ball = {
                    if self.balls.count < self.maxBalls {
                        return SCNNode()
                    } else {
                        return self.balls.remove(at: 0)
                    }
                }()
                stateMachine.enter(Striking.self)
                balls.append(GameViewController.ball)
                GameViewController.ball.name = "ball"
                GameViewController.ball.geometry = SCNSphere(radius: 2.0)
                GameViewController.ball.position = SCNVector3(x: GameViewController.player1.presentation.position.x, y: GameViewController.player1.presentation.position.y, z: GameViewController.player1.presentation.position.z)
                GameViewController.ball.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: GameViewController.ball.geometry!, options: nil))
                GameViewController.ball.geometry?.firstMaterial?.locksAmbientWithDiffuse = true
                GameViewController.ball.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
                GameViewController.ball.physicsBody?.mass = 0.01
                GameViewController.ball.physicsBody?.categoryBitMask = CollisionCategory.Ball
                GameViewController.ball.physicsBody?.collisionBitMask = CollisionCategory.All ^ CollisionCategory.Player
                GameViewController.ball.physicsBody?.velocityFactor = SCNVector3(x: 1.0, y: 1.0, z: 1.0)
                GameViewController.ball.physicsBody?.restitution = 2.0
                GameViewController.ball.physicsBody?.contactTestBitMask = CollisionCategory.All
                self.sceneView.scene!.rootNode.addChildNode(GameViewController.ball)
                
                //apply impulse
                let impulse = SCNVector3(x: frontDirection.x * Float(GameViewController.ballImpulse), y: frontDirection.y * Float(GameViewController.ballImpulse), z: frontDirection.z * Float(GameViewController.ballImpulse))
                GameViewController.ball.physicsBody?.applyForce(impulse, asImpulse: true)
                
                //update timestamp
                lastFired = now
                
                
            }
        }
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        print(contact.nodeA)
        print(contact.nodeB)
        
        if contact.nodeB.name == "ball" {
            print("make tracer")

            GameViewController.tracer = {
                if self.tracers.count < 1 {
                    return SCNNode()
                } else {
                    return self.tracers.remove(at: 0)
                }
            }()
            tracers.append(GameViewController.tracer)
            GameViewController.tracer.name = "tracer"
            GameViewController.tracer.geometry = SCNSphere(radius: 2.0)
            GameViewController.tracer.position = SCNVector3(x: GameViewController.ball.presentation.position.x, y: GameViewController.ball.presentation.position.y, z: GameViewController.ball.presentation.position.z)
            GameViewController.tracer.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: GameViewController.ball.geometry!, options: nil))
            GameViewController.tracer.geometry?.firstMaterial?.locksAmbientWithDiffuse = true
            GameViewController.tracer.geometry?.firstMaterial?.diffuse.contents = UIColor.purple
            GameViewController.tracer.physicsBody?.mass = 0.01
            GameViewController.tracer.physicsBody?.categoryBitMask = CollisionCategory.Ball
            GameViewController.tracer.physicsBody?.collisionBitMask = CollisionCategory.All ^ CollisionCategory.Player ^ CollisionCategory.Ball
            GameViewController.tracer.physicsBody?.velocityFactor = SCNVector3(x: 1.0, y: 1.0, z: 1.0)
            GameViewController.tracer.physicsBody?.restitution = 2.0
            GameViewController.tracer.physicsBody?.contactTestBitMask = CollisionCategory.All
            GameViewController.tracer.position = contact.contactPoint
            self.sceneView.scene!.rootNode.addChildNode(GameViewController.tracer)
            GameViewController.tracer.physicsBody?.velocity = SCNVector3((GameViewController.ball.physicsBody?.velocity.x)! * 2, (GameViewController.ball.physicsBody?.velocity.y)! * 2, (GameViewController.ball.physicsBody?.velocity.z)! * 2)
        }
        if contact.nodeB.name == "ball" && contact.nodeA.name == "paddle1" {
            print("Player 1 hits the ball.")
            stateMachine.enter(Striking.self)
        }
        if contact.nodeB.name == "ball" && contact.nodeA.name == "world" {
            print("Ball hits the world.")
            stateMachine.enter(Striking.self)
            print(contact.contactNormal)
        }
        if contact.nodeB.name == "ball" && contact.nodeA.name == "paddle2" {
            stateMachine.enter(Striking.self)
        }
        if contact.nodeB.name == "ball" && contact.nodeA.name == "backWall" {
            stateMachine.enter(Striking.self)
            print("GOAAAAAAAAAAAL!")
        }
        if contact.nodeA.name == "ball" && contact.nodeB.name == "goal1" {
            stateMachine.enter(Striking.self)
            print("GOAAAAAAAAAAAL!")
        }
        if contact.nodeB.name == "tracer" && contact.nodeA.name == "goal1" {
            print("tracer hits the wall")
        }
    }
    
    func wallsForBox(box: SCNBox, thickness: CGFloat) -> SCNNode {
        
        func physicsWall(width: CGFloat, height: CGFloat) -> SCNNode {
            let node = SCNNode(geometry: SCNPlane(width: width, height: height))
            node.physicsBody = .static()
            node.physicsBody = SCNPhysicsBody(type: SCNPhysicsBodyType.static, shape: SCNPhysicsShape(geometry: node.geometry!, options: nil))
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
            node.opacity = 1.0
            node.geometry?.firstMaterial?.isDoubleSided = true
            node.physicsBody?.categoryBitMask = CollisionCategory.Map
            node.physicsBody?.collisionBitMask = CollisionCategory.All
            node.physicsBody?.contactTestBitMask = CollisionCategory.All
            return node
        }
        
        let parent = SCNNode()
        
        let leftWall = physicsWall(width: box.length, height: box.height)
        leftWall.name = "left"
        leftWall.position.x = Float(-box.width / 2)
        leftWall.rotation = SCNVector4(0, 1, 0, CGFloat.pi/2)
        parent.addChildNode(leftWall)
        
        let rightWall = physicsWall(width: box.length, height: box.height)
        rightWall.name = "right"
        rightWall.position.x = Float(box.width / 2)
        rightWall.rotation = SCNVector4(0, 1, 0, CGFloat.pi/2)
        parent.addChildNode(rightWall)
        
        let frontWall = physicsWall(width: box.width, height: box.height)
        frontWall.name = "goal1"
        frontWall.position.z = Float(box.length / 2)
        frontWall.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        frontWall.geometry?.firstMaterial?.fillMode = .lines
        parent.addChildNode(frontWall)
        
        let backWall = physicsWall(width: box.width, height: box.height)
        backWall.name = "goal1"
        backWall.position.z = Float(-box.length / 2)
        backWall.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        backWall.geometry?.firstMaterial?.fillMode = .lines
        parent.addChildNode(backWall)
        
        let topWall = physicsWall(width: box.width, height: box.length)
        topWall.name = "top"
        topWall.position.y = Float(box.height / 2)
        topWall.rotation = SCNVector4(1, 0, 0, CGFloat.pi/2)
        parent.addChildNode(topWall)
        
        let bottomWall = physicsWall(width: box.width, height: box.length)
        bottomWall.name = "bot"
        bottomWall.position.y = Float(-box.height / 2)
        bottomWall.rotation = SCNVector4(1, 0, 0, CGFloat.pi/2)
        
        parent.addChildNode(bottomWall)
        
        return parent
    }
}

