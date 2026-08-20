package com.musiccatcher.music_catcher_mobile

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
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
