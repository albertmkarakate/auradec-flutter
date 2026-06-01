package app.auradec.auradec_flutter

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    private val eqPlugin = EQPlugin()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(MediaStorePlugin())
        eqPlugin.register(flutterEngine.dartExecutor.binaryMessenger)
    }
}
