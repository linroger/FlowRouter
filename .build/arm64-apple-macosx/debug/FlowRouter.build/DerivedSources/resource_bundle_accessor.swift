import Foundation

extension Foundation.Bundle {
    static let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("FlowRouter_FlowRouter.bundle").path
        let buildPath = "/Users/rogerlin/Downloads/FlowRouter/FlowRouter/.build/arm64-apple-macosx/debug/FlowRouter_FlowRouter.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}