package com.bharatgps.bharatgps_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "bharatgps/voice"
    private val MIC_PERM_CODE = 7001
    private var channel: MethodChannel? = null
    private var recognizer: SpeechRecognizer? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "listen") {
                ensurePermissionThenListen()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun ensurePermissionThenListen() {
        val granted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (granted) {
            startListening()
        } else {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), MIC_PERM_CODE)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == MIC_PERM_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startListening()
            } else {
                channel?.invokeMethod("onError", "Microphone permission denied")
            }
        }
    }

    private fun startListening() {
        runOnUiThread {
            try {
                if (recognizer == null) {
                    recognizer = SpeechRecognizer.createSpeechRecognizer(this)
                    recognizer?.setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) { channel?.invokeMethod("onReady", null) }
                        override fun onResults(results: Bundle?) {
                            val list = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val text = if (list != null && list.isNotEmpty()) list[0] else ""
                            channel?.invokeMethod("onResult", text)
                        }
                        override fun onError(error: Int) { channel?.invokeMethod("onError", "code $error") }
                        override fun onBeginningOfSpeech() {}
                        override fun onEndOfSpeech() {}
                        override fun onPartialResults(partialResults: Bundle?) {}
                        override fun onEvent(eventType: Int, params: Bundle?) {}
                        override fun onBufferReceived(buffer: ByteArray?) {}
                        override fun onRmsChanged(rmsdB: Float) {}
                    })
                }
                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
                intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                recognizer?.startListening(intent)
            } catch (e: Exception) {
                channel?.invokeMethod("onError", e.message ?: "unknown")
            }
        }
    }

    override fun onDestroy() {
        recognizer?.destroy()
        super.onDestroy()
    }
}
