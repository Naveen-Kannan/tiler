import Testing
import Tiler

@Test func commandCollectionCanCrossTaskBoundaries() async {
    let tiler = TilerCommands()
    let names = await Task.detached { tiler.commands.keys.sorted() }.value
    #expect(names.contains("window.left_half"))
}

@Test func commandDictionaryFitsExistingHostSignature() {
    let hostCommands: [String: () -> Void] = TilerCommands().commands
    #expect(hostCommands["window.left_half"] != nil)
}
