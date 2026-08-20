package com.musiccatcher.music_catcher_mobile

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.musiccatcher/native_exec"

    // 可执行目录列表（按优先级）
    private val EXEC_DIRS = listOf(
        "/data/local/tmp/musiccatcher",
        "/data/data/musiccatcher_exec",
    )

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
                "prepareBinary" -> {
                    val srcPath = call.argument<String>("srcPath") ?: ""
                    val name = call.argument<String>("name") ?: "yt-dlp"
                    try {
                        val execPath = prepareBinary(srcPath, name)
                        result.success(execPath)
                    } catch (e: Exception) {
                        result.error("PREPARE_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "getAbi" -> {
                    result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown")
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 将二进制从 app 私有目录复制到可执行目录
     * 返回可执行路径，失败返回 null
     */
    private fun prepareBinary(srcPath: String, name: String): String? {
        val srcFile = File(srcPath)
        if (!srcFile.exists()) return null

        for (dirPath in EXEC_DIRS) {
            try {
                val dir = File(dirPath)
                if (!dir.exists()) dir.mkdirs()

                val destFile = File(dir, name)
                srcFile.copyTo(destFile, overwrite = true)
                destFile.setExecutable(true, false)
                destFile.setReadable(true, false)

                // 验证可执行
                if (destFile.canExecute()) {
                    return destFile.absolutePath
                }
            } catch (e: Exception) {
                continue
            }
        }
        return null
    }

    /**
     * 通过 Kotlin ProcessBuilder 执行二进制
     */
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

        // 设置环境变量
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
