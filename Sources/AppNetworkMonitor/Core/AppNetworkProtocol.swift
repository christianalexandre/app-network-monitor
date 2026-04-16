import Network
import Foundation

internal final class AppNetworkProtocol: NWProtocolFramerImplementation {
    internal static let label = "AppMonitorProtocol"
    internal static let definition = NWProtocolFramer.Definition(implementation: AppNetworkProtocol.self)
    
    internal required init(framer: NWProtocolFramer.Instance) {}
    internal func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult { return .ready }
    internal func wakeup(framer: NWProtocolFramer.Instance) {}
    internal func stop(framer: NWProtocolFramer.Instance) -> Bool { return true }
    internal func cleanup(framer: NWProtocolFramer.Instance) {}
    
    internal func handleInput(framer: NWProtocolFramer.Instance) -> Int {
        while true {
            var header: NWProtocolFramer.Message?
            let headerSize = 4
            
            let parsed = framer.parseInput(
                minimumIncompleteLength: headerSize,
                maximumLength: headerSize
            ) { (buffer, _) -> Int in
                guard let buffer = buffer, buffer.count >= headerSize else { return 0 }
                
                let length = buffer.load(as: UInt32.self).bigEndian
                header = NWProtocolFramer.Message(definition: AppNetworkProtocol.definition)
                header?["length"] = length
                return headerSize
            }
            
            guard parsed, let message = header else { return headerSize }
            guard let lengthValue = message["length"] as? UInt32 else { return headerSize }
            let messageSize = Int(lengthValue)
            if !framer.deliverInputNoCopy(length: messageSize, message: message, isComplete: true) {
                return 0
            }
        }
    }
    
    internal func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
        var length = UInt32(messageLength).bigEndian
        framer.writeOutput(data: Data(bytes: &length, count: 4))
        
        try? framer.writeOutputNoCopy(length: messageLength)
    }
}
