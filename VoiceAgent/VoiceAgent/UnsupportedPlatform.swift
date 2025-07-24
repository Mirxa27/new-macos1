#if !os(macOS)
@main
struct UnsupportedPlatformApp {
    static func main() {
        print("VoiceAgent is only supported on macOS.")
    }
}
#endif
