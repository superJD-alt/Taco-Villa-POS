package com.tacovilla.pos

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID

class WelirkcaPrinterPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    private val CHANNEL = "com.tuapp/welirkca_printer"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    private var bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private var bluetoothSocket: BluetoothSocket? = null
    private var outputStream: OutputStream? = null

    companion object {
        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val channel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "com.tuapp/welirkca_printer"
            )
            channel.setMethodCallHandler(WelirkcaPrinterPlugin(context))
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {

            "scanPrinters" -> {
                try {
                    val adapter = bluetoothAdapter
                    if (adapter == null || !adapter.isEnabled) {
                        result.error("BLUETOOTH_OFF", "Bluetooth está apagado", null)
                        return
                    }
                    // Retorna dispositivos ya emparejados
                    val paired: Set<BluetoothDevice> = adapter.bondedDevices
                    val list = paired.map { device ->
                        mapOf("id" to device.address, "name" to (device.name ?: "Desconocido"))
                    }
                    result.success(list)
                } catch (e: Exception) {
                    result.error("SCAN_ERROR", e.message, null)
                }
            }

            "stopScan" -> {
                result.success(null)
            }

            "connectBluetooth" -> {
                val deviceId = call.argument<String>("deviceId")
                if (deviceId == null) {
                    result.error("INVALID_ARG", "deviceId requerido", null)
                    return
                }
                try {
                    val device = bluetoothAdapter?.getRemoteDevice(deviceId)
                    bluetoothSocket?.close()
                    bluetoothSocket = device?.createRfcommSocketToServiceRecord(SPP_UUID)
                    bluetoothAdapter?.cancelDiscovery()
                    bluetoothSocket?.connect()
                    outputStream = bluetoothSocket?.outputStream
                    result.success(true)
                } catch (e: Exception) {
                    result.error("CONNECT_ERROR", e.message, null)
                }
            }

            "disconnect" -> {
                try {
                    outputStream?.close()
                    bluetoothSocket?.close()
                    outputStream = null
                    bluetoothSocket = null
                    result.success(null)
                } catch (e: Exception) {
                    result.error("DISCONNECT_ERROR", e.message, null)
                }
            }

            "printText" -> {
                val text = call.argument<String>("text") ?: ""
                try {
                    outputStream?.write(text.toByteArray(Charsets.UTF_8))
                    outputStream?.flush()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }

            "cutPaper" -> {
                try {
                    // Comando ESC/POS para cortar papel
                    outputStream?.write(byteArrayOf(0x1D, 0x56, 0x42, 0x00))
                    outputStream?.flush()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("CUT_ERROR", e.message, null)
                }
            }

            "beep" -> {
                try {
                    // Comando ESC/POS para beep
                    outputStream?.write(byteArrayOf(0x1B, 0x42, 0x03, 0x02))
                    outputStream?.flush()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("BEEP_ERROR", e.message, null)
                }
            }

            "openCashDrawer" -> {
                try {
                    // Comando ESC/POS para abrir cajón
                    outputStream?.write(byteArrayOf(0x1B, 0x70, 0x00, 0x19, 0xFA.toByte()))
                    outputStream?.flush()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("DRAWER_ERROR", e.message, null)
                }
            }

            "printTestPaper" -> {
                try {
                    val testText = "=== PRUEBA DE IMPRESION ===\n\nTaco Villa POS\nImpresora funcionando OK\n\n\n"
                    outputStream?.write(testText.toByteArray(Charsets.UTF_8))
                    outputStream?.flush()
                    result.success(null)
                } catch (e: Exception) {
                    result.error("PRINT_ERROR", e.message, null)
                }
            }

            "setPrintWidth" -> result.success(null)  // No aplica en ESC/POS básico
            "setFontSize" -> result.success(null)
            "selfTest" -> result.success(null)
            "connectWifi" -> result.error("NOT_SUPPORTED", "WiFi no implementado aún", null)
            "printBarcode" -> result.error("NOT_SUPPORTED", "Barcode no implementado aún", null)
            "printQRCode" -> result.error("NOT_SUPPORTED", "QR no implementado aún", null)
            "printImage" -> result.error("NOT_SUPPORTED", "Imagen no implementado aún", null)

            else -> result.notImplemented()
        }
    }
}