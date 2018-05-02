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
}

class IncomingBall: GKState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is Striking.Type
    }
    
    override func didEnter(from previousState: GKState?) {
        print("Opponent moves to incoming ball.")
    }
    
}

class Striking: GKState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass is SquaringUp.Type
    }
    
    override func didEnter(from previousState: GKState?) {
        print("Opponents strikes the ball.")
    }
}
