package com.example.autism

import android.content.Context
import android.media.MediaMetadataRetriever
import kotlinx.coroutines.*
import java.io.File
import java.io.FileWriter
import android.util.Log

class VideoExtractor(private val context: Context) {

    private val scope = CoroutineScope(Dispatchers.IO)

    fun startExtraction(
        videoPath: String,
        fps: Float,
        keepIds: List<Int>,
        outputCsv: File,
        onDone: () -> Unit
    ) {
        scope.launch {
            extract(videoPath, fps, keepIds, outputCsv)
            withContext(Dispatchers.Main) {
                onDone()
            }
        }
    }


    private suspend fun extract(
        videoPath: String,
        fps: Float,
        keepIds: List<Int>,
        outputCsv: File
    ) {
        Log.d("VideoExtractor", "START extraction")
        val retriever = MediaMetadataRetriever()
        retriever.setDataSource(videoPath)

        val durationMs =
            retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)!!
                .toLong()
        Log.d("VideoExtractor", "DurationMs=$durationMs")

        val frameIntervalUs = (1_000_000f / fps).toLong()

        val writer = FileWriter(outputCsv)
        writeHeader(writer, keepIds)

        val pose = PoseWrapper(context)

        var timestampUs = 0L
        var frameIndex = 0

        while (timestampUs <= durationMs * 1000L) {

            if (frameIndex % 10 == 0) {
                Log.d(
                    "VideoExtractor",
                    "Processing frame=$frameIndex timeUs=$timestampUs"
                )
            }

            val bitmap = retriever.getFrameAtTime(
                timestampUs,
                MediaMetadataRetriever.OPTION_CLOSEST
            )

            if (bitmap != null) {
                val landmarks = pose.process(bitmap, timestampUs / 1000L)
                val row = buildCsvRow(frameIndex, timestampUs, keepIds, landmarks)
                writer.write(row)
                bitmap.recycle()
            }

            frameIndex++
            timestampUs += frameIntervalUs

            if (frameIndex > (durationMs * fps / 1000).toInt() + 10) {
                Log.e("VideoExtractor", "Breaking loop: frameIndex exceeded expected")
                break
            }
        }

        writer.flush()
        writer.close()
        retriever.release()
        pose.close()
        Log.d("VideoExtractor", "END extraction")
    }

    private fun writeHeader(writer: FileWriter, keepIds: List<Int>) {
        val sb = StringBuilder("frame")
        for (id in keepIds) {
            sb.append(",landmark_${id}_x,landmark_${id}_y,landmark_${id}_z,landmark_${id}_vis")
        }
        sb.append("\n")
        writer.write(sb.toString())
    }

    private fun buildCsvRow(
        frame: Int,
        timestampUs: Long,
        keepIds: List<Int>,
        landmarks: Map<Int, LandmarkData>?
    ): String {
        val sb = StringBuilder()
        sb.append(frame)
//        sb.append(",")
//        sb.append(timestampUs / 1_000_000.0)

        for (id in keepIds) {
            val lm = landmarks?.get(id)
            if (lm != null) {
                sb.append(",${lm.x},${lm.y},${lm.z},${lm.vis}")
            } else {
                sb.append(",NaN,NaN,NaN,NaN")
            }
        }
        sb.append("\n")
        return sb.toString()
    }
}
