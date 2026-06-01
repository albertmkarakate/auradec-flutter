package app.auradec.auradec_flutter

import android.media.audiofx.AudioEffect
import android.media.audiofx.Equalizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class EQPlugin : MethodChannel.MethodCallHandler {

    private var equalizer: Equalizer? = null
    private lateinit var channel: MethodChannel

    fun register(messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "app.auradec/equalizer")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                val sessionId = call.argument<Int>("sessionId")
                if (sessionId == null) {
                    result.error("INVALID_ARGS", "sessionId is required", null)
                    return
                }
                try {
                    equalizer?.release()
                    equalizer = Equalizer(0, sessionId)
                    equalizer!!.enabled = true
                    result.success(null)
                } catch (e: Exception) {
                    result.error("EQ_INIT_FAILED", e.message, null)
                }
            }

            "setEnabled" -> {
                val eq = equalizer
                if (eq == null) {
                    result.success(null)
                    return
                }
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("INVALID_ARGS", "enabled is required", null)
                    return
                }
                try {
                    eq.enabled = enabled
                    result.success(null)
                } catch (e: Exception) {
                    result.error("EQ_ERROR", e.message, null)
                }
            }

            "setBand" -> {
                val eq = equalizer
                if (eq == null) {
                    result.success(null)
                    return
                }
                val band = call.argument<Int>("band")
                val gainMilliBel = call.argument<Int>("gainMilliBel")
                if (band == null || gainMilliBel == null) {
                    result.error("INVALID_ARGS", "band and gainMilliBel are required", null)
                    return
                }
                try {
                    eq.setBandLevel(band.toShort(), gainMilliBel.toShort())
                    result.success(null)
                } catch (e: Exception) {
                    result.error("EQ_ERROR", e.message, null)
                }
            }

            "getNumBands" -> {
                val eq = equalizer
                if (eq == null) {
                    result.success(0)
                    return
                }
                try {
                    result.success(eq.numberOfBands.toInt())
                } catch (e: Exception) {
                    result.error("EQ_ERROR", e.message, null)
                }
            }

            "getBandFreqRange" -> {
                val eq = equalizer
                if (eq == null) {
                    result.success(listOf(0, 0))
                    return
                }
                val band = call.argument<Int>("band")
                if (band == null) {
                    result.error("INVALID_ARGS", "band is required", null)
                    return
                }
                try {
                    val range = eq.getBandFreqRange(band.toShort())
                    result.success(listOf(range[0], range[1]))
                } catch (e: Exception) {
                    result.error("EQ_ERROR", e.message, null)
                }
            }

            "getLevelRange" -> {
                val eq = equalizer
                if (eq == null) {
                    result.success(listOf(-1200, 1200))
                    return
                }
                try {
                    val range = eq.bandLevelRange
                    result.success(listOf(range[0].toInt(), range[1].toInt()))
                } catch (e: Exception) {
                    result.error("EQ_ERROR", e.message, null)
                }
            }

            "release" -> {
                try {
                    equalizer?.release()
                    equalizer = null
                    result.success(null)
                } catch (e: Exception) {
                    result.error("EQ_ERROR", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }
}
