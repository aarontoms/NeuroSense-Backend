package com.example.autism

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarkerResult

class FaceMeshHelper(context: Context) {

    private val faceLandmarker: FaceLandmarker

    init {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath("face_landmarker.task")
            .build()

        val options = FaceLandmarker.FaceLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.VIDEO)
            .setNumFaces(1)
            .setMinFaceDetectionConfidence(0.5f)
            .setMinTrackingConfidence(0.5f)
            .build()

        faceLandmarker = FaceLandmarker.createFromOptions(context, options)
    }

    fun process(bitmap: Bitmap, timestampMs: Long): List<Map<String, Float>>? {
        val image = BitmapImageBuilder(bitmap).build()
        val result: FaceLandmarkerResult = faceLandmarker.detectForVideo(image, timestampMs)

        if (result.faceLandmarks().isEmpty()) return null

        val face: List<NormalizedLandmark> = result.faceLandmarks()[0]

        return face.map { lm ->
            mapOf("x" to lm.x(), "y" to lm.y(), "z" to lm.z())
        }
    }

    fun close() {
        faceLandmarker.close()
    }
}
