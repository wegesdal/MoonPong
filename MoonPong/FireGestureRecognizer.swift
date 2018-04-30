//FPSControls
//
//Version 1.0.1, September 10th, 2015
//
//Copyright (C) 2014 Charcoal Design
//
//This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
//
//Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
//
//    The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
//    Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
//    This notice may not be removed or altered from any source distribution.

import UIKit
import UIKit.UIGestureRecognizerSubclass

class FireGestureRecognizer: UIGestureRecognizer {
    
    var timeThreshold = 0.15
    var distanceThreshold = 5.0
    private var startTimes = [Int:TimeInterval]()
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        //record the start times of each touch
        for touch in touches {
            startTimes[touch.hash] = touch.timestamp
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        //discard any touches that have moved
        for touch in touches {
            
            let newPos = touch.location(in: view)
            let oldPos = touch.previousLocation(in: view)
            let distanceDelta = Double(max(abs(newPos.x - oldPos.x), abs(newPos.y - oldPos.y)))
            if distanceDelta >= distanceThreshold {
                startTimes[touch.hash] = nil
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        for touch in touches {
            
            let startTime = startTimes[touch.hash]
            if let startTime = startTime {
                
                //check if within time
                let timeDelta = touch.timestamp - startTime
                if timeDelta < timeThreshold {
                    
                    //recognized
                    state = .ended
                }
            }
        }
        reset()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        reset()
    }
    
    override func reset() {
        
        if state == .possible {
            state = .failed
        }
    }
}
