package com.example.autism

import android.content.Context
import android.graphics.Bitmap
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarkerResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class LandmarkData(
    val x: Float,
    val y: Float,
    val z: Float,
    val vis: Float
)

class PoseWrapper(
    context: Context,
    modelName: String = "pose_landmarker_lite.task"
) {

    private val poseLandmarker: PoseLandmarker

    init {
        val baseOptions = BaseOptions.builder()
            .setModelAssetPath(modelName)
            .build()

        val options = PoseLandmarker.PoseLandmarkerOptions.builder()
            .setBaseOptions(baseOptions)
            .setRunningMode(RunningMode.VIDEO)
            .build()

        poseLandmarker = PoseLandmarker.createFromOptions(context, options)
    }

    suspend fun process(
        bitmap: Bitmap,
        timestampMs: Long
    ): Map<Int, LandmarkData>? = withContext(Dispatchers.Default) {

        val image = BitmapImageBuilder(bitmap).build()
        val result: PoseLandmarkerResult =
            poseLandmarker.detectForVideo(image, timestampMs)

        if (result.landmarks().isEmpty()) return@withContext null

        val pose: List<NormalizedLandmark> = result.landmarks()[0]

        val out = mutableMapOf<Int, LandmarkData>()
        for (i in pose.indices) {
            val lm = pose[i]
            out[i] = LandmarkData(
                lm.x(),
                lm.y(),
                lm.z(),
                lm.visibility().orElse(1f)
            )
        }
        out
    }

    fun close() {
        poseLandmarker.close()
    }
}
