package app.incoherences.bojairu

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.compartarenta/public_documents"
        private const val DEVICE_BINDING_CHANNEL = "com.compartarenta/device_binding"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_BINDING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "collectSignals" -> {
                        try {
                            result.success(DeviceBindingSignals.collect(applicationContext))
                        } catch (t: Throwable) {
                            // NoSuchFieldError and similar linkage errors are
                            // not Exception subclasses; they must not kill
                            // the main thread (crash loop until data clear).
                            result.error("collect_failed", t.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "writeTextFile" -> {
                        val subDir = call.argument<String>("subDir") ?: "Bojairũ"
                        val fileName = call.argument<String>("fileName")
                        val content = call.argument<String>("content")
                        val mimeType = call.argument<String>("mimeType") ?: "application/json"
                        if (fileName.isNullOrBlank() || content == null) {
                            result.error(
                                "invalid_args",
                                "fileName and content are required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            val writeResult =
                                writeTextFileToDocuments(subDir, fileName, content, mimeType)
                            result.success(writeResult.relativePath)
                        } catch (e: Exception) {
                            result.error("write_failed", e.message, null)
                        }
                    }

                    "writeBytesFile" -> {
                        val subDir = call.argument<String>("subDir") ?: "Bojairũ"
                        val fileName = call.argument<String>("fileName")
                        @Suppress("UNCHECKED_CAST")
                        val bytes = call.argument<ByteArray>("bytes")
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        if (fileName.isNullOrBlank() || bytes == null) {
                            result.error(
                                "invalid_args",
                                "fileName and bytes are required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            val writeResult =
                                writeBytesFileToDocuments(subDir, fileName, bytes, mimeType)
                            result.success(
                                mapOf(
                                    "storageKey" to writeResult.storageKey,
                                    "relativePath" to writeResult.relativePath,
                                ),
                            )
                        } catch (e: Exception) {
                            result.error("write_failed", e.message, null)
                        }
                    }

                    "readBytesFile" -> {
                        val storageKey = call.argument<String>("storageKey")
                        if (storageKey.isNullOrBlank()) {
                            result.error("invalid_args", "storageKey is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(readBytes(storageKey))
                        } catch (e: Exception) {
                            result.error("read_failed", e.message, null)
                        }
                    }

                    "deleteFile" -> {
                        val storageKey = call.argument<String>("storageKey")
                        if (storageKey.isNullOrBlank()) {
                            result.error("invalid_args", "storageKey is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            deleteStoredFile(storageKey)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("delete_failed", e.message, null)
                        }
                    }

                    "fileExists" -> {
                        val storageKey = call.argument<String>("storageKey")
                        if (storageKey.isNullOrBlank()) {
                            result.error("invalid_args", "storageKey is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(fileExists(storageKey))
                        } catch (e: Exception) {
                            result.error("exists_failed", e.message, null)
                        }
                    }

                    "listFileNames" -> {
                        val subDir = call.argument<String>("subDir") ?: "Bojairũ"
                        try {
                            result.success(listFileNamesInSubDir(subDir))
                        } catch (e: Exception) {
                            result.error("list_failed", e.message, null)
                        }
                    }

                    "resolveStorageKey" -> {
                        val subDir = call.argument<String>("subDir") ?: "Bojairũ"
                        val fileName = call.argument<String>("fileName")
                        if (fileName.isNullOrBlank()) {
                            result.error("invalid_args", "fileName is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            result.success(resolveStorageKey(subDir, fileName))
                        } catch (e: Exception) {
                            result.error("resolve_failed", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private data class WriteResult(val storageKey: String, val relativePath: String)

    private fun documentsRelativeFolder(subDir: String): String {
        return "${Environment.DIRECTORY_DOCUMENTS}/$subDir"
    }

    private fun legacyAbsoluteFile(subDir: String, fileName: String): File {
        @Suppress("DEPRECATION")
        val docsDir =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS)
        val dir = File(docsDir, subDir.replace('/', File.separatorChar))
        if (!dir.exists() && !dir.mkdirs()) {
            throw IllegalStateException("mkdirs failed for ${dir.absolutePath}")
        }
        return File(dir, fileName)
    }

    private fun writeTextFileToDocuments(
        subDir: String,
        fileName: String,
        content: String,
        mimeType: String,
    ): WriteResult {
        val relativeFolder = documentsRelativeFolder(subDir)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativeFolder)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val collection =
                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri =
                resolver.insert(collection, values)
                    ?: throw IllegalStateException("MediaStore insert failed")
            resolver.openOutputStream(uri)?.use { stream: OutputStream ->
                stream.write(content.toByteArray(Charsets.UTF_8))
            } ?: throw IllegalStateException("openOutputStream failed")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return WriteResult(uri.toString(), "$relativeFolder/$fileName")
        }

        val file = legacyAbsoluteFile(subDir, fileName)
        file.writeText(content, Charsets.UTF_8)
        return WriteResult(file.absolutePath, "$relativeFolder/$fileName")
    }

    private fun writeBytesFileToDocuments(
        subDir: String,
        fileName: String,
        bytes: ByteArray,
        mimeType: String,
    ): WriteResult {
        val relativeFolder = documentsRelativeFolder(subDir)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativeFolder)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val collection =
                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri =
                resolver.insert(collection, values)
                    ?: throw IllegalStateException("MediaStore insert failed")
            resolver.openOutputStream(uri)?.use { stream: OutputStream ->
                stream.write(bytes)
            } ?: throw IllegalStateException("openOutputStream failed")
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return WriteResult(uri.toString(), "$relativeFolder/$fileName")
        }

        val file = legacyAbsoluteFile(subDir, fileName)
        file.writeBytes(bytes)
        return WriteResult(file.absolutePath, "$relativeFolder/$fileName")
    }

    private fun readBytes(storageKey: String): ByteArray {
        if (storageKey.startsWith("content://")) {
            val uri = Uri.parse(storageKey)
            contentResolver.openInputStream(uri)?.use { input ->
                return input.readBytes()
            } ?: throw IllegalStateException("openInputStream failed for $storageKey")
        }
        return File(storageKey).readBytes()
    }

    private fun deleteStoredFile(storageKey: String) {
        if (storageKey.startsWith("content://")) {
            val uri = Uri.parse(storageKey)
            contentResolver.delete(uri, null, null)
            return
        }
        File(storageKey).delete()
    }

    private fun fileExists(storageKey: String): Boolean {
        if (storageKey.startsWith("content://")) {
            val uri = Uri.parse(storageKey)
            contentResolver.openInputStream(uri)?.use { return true }
            return false
        }
        return File(storageKey).exists()
    }

    private fun resolveStorageKey(subDir: String, fileName: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val relativeFolder = documentsRelativeFolder(subDir)
            val collection =
                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val selection =
                "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${MediaStore.MediaColumns.DISPLAY_NAME}=?"
            val args = arrayOf("$relativeFolder/", fileName)
            contentResolver.query(collection, arrayOf(MediaStore.MediaColumns._ID), selection, args, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
                        val id = cursor.getLong(idCol)
                        return Uri.withAppendedPath(collection, id.toString()).toString()
                    }
                }
            throw IllegalStateException("MediaStore file not found: $subDir/$fileName")
        }
        return legacyAbsoluteFile(subDir, fileName).absolutePath
    }

    private fun listFileNamesInSubDir(subDir: String): List<String> {
        val names = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val relativeFolder = documentsRelativeFolder(subDir)
            val collection =
                MediaStore.Files.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val selection = "${MediaStore.MediaColumns.RELATIVE_PATH}=?"
            val args = arrayOf("$relativeFolder/")
            contentResolver.query(
                collection,
                arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
                selection,
                args,
                null,
            )?.use { cursor ->
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
                while (cursor.moveToNext()) {
                    names.add(cursor.getString(nameCol))
                }
            }
            return names
        }
        val dir = legacyAbsoluteFile(subDir, ".").parentFile ?: return names
        if (!dir.exists()) return names
        dir.listFiles()?.forEach { file ->
            if (file.isFile) names.add(file.name)
        }
        return names
    }
}
