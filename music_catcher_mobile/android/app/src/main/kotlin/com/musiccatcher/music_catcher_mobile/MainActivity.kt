package com.musiccatcher.music_catcher_mobile

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.File
import java.io.FileOutputStream
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.musiccatcher/native_exec"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "exec" -> {
                    val binaryPath = call.argument<String>("binaryPath") ?: ""
                    val args = call.argument<List<String>>("args") ?: emptyList()
                    val env = call.argument<Map<String, String>>("env") ?: emptyMap()
                    val timeoutSec = call.argument<Int>("timeout") ?: 120

                    try {
                        val execResult = execBinary(binaryPath, args, env, timeoutSec)
                        result.success(execResult)
                    } catch (e: Exception) {
                        result.error("EXEC_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "extractBinary" -> {
                    val assetPath = call.argument<String>("assetPath") ?: "bin/yt-dlp"
                    try {
                        val path = extractBinaryFromAssets(assetPath)
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("EXTRACT_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "getNativeLibDir" -> {
                    result.success(applicationContext.applicationInfo.nativeLibraryDir)
                }
                "getAbi" -> {
                    result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown")
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 从 APK assets 中提取二进制文件到 native lib 目录（允许执行）
     */
    private fun extractBinaryFromAssets(assetPath: String): String? {
        val nativeLibDir = applicationContext.applicationInfo.nativeLibraryDir
        val destFile = File(nativeLibDir, "yt-dlp")

        // 如果已提取且大小正确，直接返回
        if (destFile.exists() && destFile.length() > 10000) {
            return destFile.absolutePath
        }

        // 从 assets 提取
        try {
            assets.open(assetPath).use { input ->
                FileOutputStream(destFile).use { output ->
                    input.copyTo(output)
                }
            }
            destFile.setExecutable(true, false)
            destFile.setReadable(true, false)

            if (destFile.exists() && destFile.canExecute()) {
                return destFile.absolutePath
            }
        } catch (e: Exception) {
            // native lib 目录可能只读，尝试其他方式
        }

        // 备选：复制到 cache 目录（部分设备允许执行）
        val cacheDir = applicationContext.cacheDir
        val cacheFile = File(cacheDir, "yt-dlp")
        try {
            assets.open(assetPath).use { input ->
                FileOutputStream(cacheFile).use { output ->
                    input.copyTo(output)
                }
            }
            cacheFile.setExecutable(true, false)
            if (cacheFile.exists() && cacheFile.length() > 10000) {
                return cacheFile.absolutePath
            }
        } catch (e: Exception) {
            // 继续
        }

        return null
    }

    private fun execBinary(
        binaryPath: String,
        args: List<String>,
        env: Map<String, String>,
        timeoutSec: Int
    ): Map<String, Any> {
        val cmd = mutableListOf(binaryPath)
        cmd.addAll(args)

        val pb = ProcessBuilder(cmd)
        pb.redirectErrorStream(false)

        val processEnv = pb.environment()
        for ((key, value) in env) {
            processEnv[key] = value
        }

        val process = pb.start()

        val stdout = BufferedReader(InputStreamReader(process.inputStream)).use { it.readText() }
        val stderr = BufferedReader(InputStreamReader(process.errorStream)).use { it.readText() }

        val completed = process.waitFor(timeoutSec.toLong(), TimeUnit.SECONDS)
        val exitCode = if (completed) process.exitValue() else {
            process.destroyForcibly()
            -1
        }

        return mapOf(
            "exitCode" to exitCode,
            "stdout" to stdout,
            "stderr" to stderr,
            "timeout" to !completed
        )
    }
}
