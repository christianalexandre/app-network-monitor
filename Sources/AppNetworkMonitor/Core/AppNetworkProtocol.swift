#if APPNETWORKMONITOR_ENABLED
//
//  AppNetworkProtocol.swift
//  AppNetworkMonitor
//
//  Created by Christian Alexandre on 08/01/26.
//

import Network
import Foundation

class AppNetworkProtocol: NWProtocolFramerImplementation {
    static let label = "AppMonitorProtocol"
    static let definition = NWProtocolFramer.Definition(implementation: AppNetworkProtocol.self)
    
    required init(framer: NWProtocolFramer.Instance) {}
    func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { return .ready }
    func wakeup(framer: NWProtocolFramer.Instance) {}
    func stop(framer: NWProtocolFramer.Instance) -> Bool { return true }
    func cleanup(framer: NWProtocolFramer.Instance) {}
    
    func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var header: NWProtocolFramer.Message? = nil
            let headerSize = 4
            
            let parsed = framer.parseInput(
                minimumIncompleteLength: headerSize,
                maximumLength: headerSize
            ) { (buffer, isComplete) -> Int in
                guard let buffer = buffer, buffer.count >= headerSize else { return 0 }
                
                let length = buffer.bindMemory(to: UInt32.self).baseAddress!.pointee.bigEndian
                header = NWProtocolFramer.Message(definition: AppNetworkProtocol.definition)
                header?["length"] = length
                return headerSize
            }
            
            guard parsed, let message = header else { return headerSize }
            let messageSize = Int(message["length"] as! UInt32)
            if !framer.deliverInputNoCopy(length: messageSize, message: message, isComplete: true) {
                return 0
            }
        }
    }
    
    func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        var length = UInt32(messageLength).bigEndian
        framer.writeOutput(data: Data(bytes: &length, count: 4))
        
        try? framer.writeOutputNoCopy(length: messageLength)
    }
}
#endif
