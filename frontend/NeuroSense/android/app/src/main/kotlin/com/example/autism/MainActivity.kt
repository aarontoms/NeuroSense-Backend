package com.example.autism

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Environment
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.YuvImage
import android.graphics.Rect
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "app/landmark_method"
    private val FACE_MESH_CHANNEL = "app/face_mesh"
    private lateinit var extractor: VideoExtractor
    private var faceMeshHelper: FaceMeshHelper? = null
    private var frameTimestamp = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        extractor = VideoExtractor(this)

        // ── Existing Pose Landmark Channel ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "extractLandmarksToCsv" -> {
                    val videoPath = call.argument<String>("videoPath")
                    val fps = (call.argument<Double>("fps") ?: 30.0).toFloat()
                    val keepIds =
                        call.argument<List<Int>>("keepIds") ?: emptyList()

                    if (videoPath == null) {
                        result.error("NO_VIDEO", "videoPath is null", null)
                        return@setMethodCallHandler
                    }

                    val outDir = getExternalFilesDir(Environment.DIRECTORY_DOCUMENTS)
                    val csvFile = File(
                        outDir,
                        "landmarks_${System.currentTimeMillis()}.csv"
                    )

                    extractor.startExtraction(
                        videoPath = videoPath,
                        fps = fps,
                        keepIds = keepIds,
                        outputCsv = csvFile
                    ) {
                        result.success(csvFile.absolutePath)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ── Face Mesh Channel for Attention Monitor ──
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            FACE_MESH_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initFaceMesh" -> {
                    try {
                        faceMeshHelper?.close()
                        faceMeshHelper = FaceMeshHelper(this)
                        frameTimestamp = 0L
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", e.message, null)
                    }
                }

                "processFrame" -> {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")!!
                        val width = call.argument<Int>("width")!!
                        val height = call.argument<Int>("height")!!

                        // Convert NV21/YUV bytes to Bitmap
                        val yuvImage = YuvImage(bytes, ImageFormat.NV21, width, height, null)
                        val out = ByteArrayOutputStream()
                        yuvImage.compressToJpeg(Rect(0, 0, width, height), 80, out)
                        val jpegBytes = out.toByteArray()
                        val bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)

                        if (bitmap == null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }

                        frameTimestamp += 33 // ~30fps interval
                        val landmarks = faceMeshHelper?.process(bitmap, frameTimestamp)
                        bitmap.recycle()

                        if (landmarks != null) {
                            // Convert List<Map<String, Float>> to List<Map<String, Double>>
                            // for Dart compatibility
                            val dartLandmarks = landmarks.map { lm ->
                                mapOf(
                                    "x" to lm["x"]!!.toDouble(),
                                    "y" to lm["y"]!!.toDouble(),
                                    "z" to lm["z"]!!.toDouble()
                                )
                            }
                            result.success(dartLandmarks)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        result.error("PROCESS_ERROR", e.message, null)
                    }
                }

                "disposeFaceMesh" -> {
                    faceMeshHelper?.close()
                    faceMeshHelper = null
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}
