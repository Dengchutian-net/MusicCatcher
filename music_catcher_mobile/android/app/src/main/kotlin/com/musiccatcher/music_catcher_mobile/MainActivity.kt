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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "exec" -> {
                    val command = call.argument<String>("command") ?: ""
                    val args = call.argument<List<String>>("args") ?: emptyList()
                    val env = call.argument<Map<String, String>>("env") ?: emptyMap()
                    val workDir = call.argument<String>("workDir")
                    val timeoutSec = call.argument<Int>("timeout") ?: 120

                    try {
                        val execResult = executeCommand(command, args, env, workDir, timeoutSec)
                        result.success(execResult)
                    } catch (e: Exception) {
                        result.error("EXEC_ERROR", e.message, e.stackTraceToString())
                    }
                }
                "setExecutable" -> {
                    val path = call.argument<String>("path") ?: ""
                    try {
                        val file = File(path)
                        val success = file.setExecutable(true, false)
                        result.success(success)
                    } catch (e: Exception) {
                        result.error("CHMOD_ERROR", e.message, null)
                    }
                }
                "getAbi" -> {
                    result.success(Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown")
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun executeCommand(
        command: String,
        args: List<String>,
        env: Map<String, String>,
        workDir: String?,
        timeoutSec: Int
    ): Map<String, Any> {
        val cmd = mutableListOf(command)
        cmd.addAll(args)

        val pb = ProcessBuilder(cmd)
        pb.redirectErrorStream(false)

        // 设置环境变量
        val processEnv = pb.environment()
        for ((key, value) in env) {
            processEnv[key] = value
        }

        // 设置工作目录
        if (workDir != null) {
            pb.directory(File(workDir))
        }

        val process = pb.start()

        // 读取 stdout
        val stdout = BufferedReader(InputStreamReader(process.inputStream)).use { it.readText() }
        // 读取 stderr
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
