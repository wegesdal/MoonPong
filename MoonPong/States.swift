//
//  States.swift
//  MoonPong
//
//  Created by William Egesdal on 5/2/18.
//  Copyright © 2018 William Egesdal. All rights reserved.
//

import Foundation
import GameplayKit

class SquaringUp: GKState {
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is IncomingBall.Type
    }
    
    override func didEnter(from previousState: GKState?) {
        print("Opponent is squaring up.")
    }
    
    override func update(deltaTime: TimeInterval) {
        GameViewController.player2.position.y = GameViewController.player1.position.y
        GameViewController.player2.position.x = GameViewController.player1.position.x * -1
        GameViewController.player2.position.z = GameViewController.player1.position.z * -1
        
    }
    
}

class IncomingBall: GKState {
    static var t: TimeInterval = 0
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is Striking.Type
    }
    
    override func didEnter(from previousState: GKState?) {
        print("Opponent moves to incoming ball.")
    }
    
    override func update(deltaTime: TimeInterval) {

    }
}

class Striking: GKState {
    var flashTimeCounter: TimeInterval = 0
    static let flashInterval = 0.2
    static var moved: Bool = false
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is SquaringUp.Type
    }
    
    override func didEnter(from previousState: GKState?) {
        print("Opponents strikes the ball.")
        Striking.moved = false
        GameViewController.paddle2.position.y = 0
    }
    
    override func update(deltaTime: TimeInterval) {
//        print(deltaTime)
        // Keep track of the time since the last update.
        
        flashTimeCounter += deltaTime
        if flashTimeCounter > Striking.flashInterval {
            if Striking.moved == false {

                Striking.moved = true
            }
            flashTimeCounter = 0
        }
    }
}
