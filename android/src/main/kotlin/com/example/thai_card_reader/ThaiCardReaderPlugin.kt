package com.example.thai_card_reader

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.PermissionChecker.PERMISSION_GRANTED

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StringCodec

class ThaiCardReaderPlugin : FlutterPlugin, ActivityAware {

    companion object {
        private const val TAG = "NiosLib"
        private const val METHOD_CHANNEL = "NiosLib/Api"
        private const val EVENT_CHANNEL = "NiosLib/usb_events"
        private const val ACTION_USB_PERMISSION = "com.example.thai_card_reader.USB_PERMISSION"
    }

    private var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding? = null

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var messageChannel: BasicMessageChannel<String>? = null

    private var activity: Activity? = null
    private var usbManager: UsbManager? = null
    private var mNidLib: NidLib? = null
    private var eventSink: EventChannel.EventSink? = null

    // ── USB BroadcastReceiver: permission result ──
    private val usbPermissionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (ACTION_USB_PERMISSION != intent.action) return
            synchronized(this) {
                val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                }

                if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                    device?.let {
                        eventSink?.success(mapOf("event" to "permission_granted", "device" to it.deviceName))
                        Handler(Looper.getMainLooper()).post { autoSelectReader() }
                    }
                } else {
                    eventSink?.success(mapOf("event" to "permission_denied"))
                }
            }
        }
    }

    // ── USB BroadcastReceiver: attach / detach ──
    private val usbAttachReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    val device: UsbDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                    }
                    device?.let {
                        eventSink?.success(mapOf(
                            "event" to "device_attached",
                            "device_name" to it.deviceName,
                            "vendor_id" to it.vendorId,
                            "product_id" to it.productId
                        ))
                        requestUsbPermissionAuto(it)
                    }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    mNidLib?.deselectReaderNi()
                    eventSink?.success(mapOf("event" to "device_detached"))
                }
            }
        }
    }

    // ── FlutterPlugin ──

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        flutterPluginBinding = binding

        messageChannel = BasicMessageChannel(
            binding.binaryMessenger,
            "NiosLib/message",
            StringCodec.INSTANCE
        )

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel!!.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null
        eventChannel?.setStreamHandler(null)
        eventChannel = null
        messageChannel = null
        flutterPluginBinding = null
    }

    // ── ActivityAware ──

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        setupPlugin()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        teardownPlugin()
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        setupPlugin()
    }

    override fun onDetachedFromActivity() {
        teardownPlugin()
        activity = null
    }

    // ── Setup / Teardown ──

    private fun setupPlugin() {
        val act = activity ?: return

        usbManager = act.getSystemService(Context.USB_SERVICE) as UsbManager

        // Register USB BroadcastReceivers
        val permFilter = IntentFilter(ACTION_USB_PERMISSION)
        val attachFilter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            act.registerReceiver(usbPermissionReceiver, permFilter, Context.RECEIVER_NOT_EXPORTED)
            act.registerReceiver(usbAttachReceiver, attachFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            act.registerReceiver(usbPermissionReceiver, permFilter)
            act.registerReceiver(usbAttachReceiver, attachFilter)
        }

        // Request Bluetooth permissions
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                act,
                arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT),
                0
            )
        } else {
            if (ActivityCompat.checkSelfPermission(act, Manifest.permission.ACCESS_FINE_LOCATION) != PERMISSION_GRANTED) {
                val dialog = AlertDialog.Builder(act).create()
                dialog.setTitle("Permission")
                dialog.setMessage("Please allow Location permission if use Bluetooth reader.")
                dialog.setCancelable(false)
                dialog.setCanceledOnTouchOutside(false)
                dialog.setButton(AlertDialog.BUTTON_POSITIVE, "Close") { d, _ ->
                    ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), 0)
                    d.dismiss()
                }
                dialog.show()
                dialog.getButton(AlertDialog.BUTTON_POSITIVE).isAllCaps = false
            } else {
                ActivityCompat.requestPermissions(act, arrayOf(Manifest.permission.ACCESS_FINE_LOCATION), 0)
            }
        }

        mNidLib = NidLib(act)
        mNidLib?.bindMessageChannel(messageChannel)

        setupMethodChannel()
    }

    private fun teardownPlugin() {
        try {
            activity?.unregisterReceiver(usbPermissionReceiver)
            activity?.unregisterReceiver(usbAttachReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receivers: ${e.message}")
        }
        mNidLib = null
    }

    private fun setupMethodChannel() {
        methodChannel?.setMethodCallHandler { call, result ->
            val act = activity
            val usb = usbManager
            val nidLib = mNidLib

            when (call.method) {
                // ── USB management ──
                "getConnectedReaders" -> {
                    try {
                        result.success(getConnectedSmartCardReaders())
                    } catch (e: Exception) {
                        result.error("USB_ERROR", e.message, null)
                    }
                }
                "requestPermission" -> {
                    val deviceName = call.argument<String>("deviceName")
                    if (deviceName == null) {
                        result.error("INVALID_ARG", "deviceName required", null)
                        return@setMethodCallHandler
                    }
                    val device = usb?.deviceList?.get(deviceName)
                    if (device == null) {
                        result.error("DEVICE_NOT_FOUND", "Device $deviceName not found", null)
                        return@setMethodCallHandler
                    }
                    if (usb.hasPermission(device)) {
                        result.success(true)
                    } else {
                        requestUsbPermissionAuto(device)
                        result.success(false)
                    }
                }

                // ── NidLib methods ──
                "getBatteryLevel" -> {
                    val level = getBatteryLevel()
                    if (level != -1) result.success(level)
                    else result.error("UNAVAILABLE", "Battery level not available.", null)
                }
                "openNiOSLibNi" -> {
                    val path: String = call.argument("path") ?: ""
                    result.success(nidLib?.openNiOSLibNi(path)
                        ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                }
                "updateLicenseFileNi" -> result.success(nidLib?.updateLicenseFileNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "closeNiOSLibNi"      -> result.success(nidLib?.closeNiOSLibNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "getReaderListNi"     -> result.success(nidLib?.getReaderListNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "selectReaderNi" -> {
                    val reader: String = call.argument("reader") ?: ""
                    result.success(nidLib?.selectReaderNi(reader)
                        ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                }
                "deselectReaderNi"    -> result.success(nidLib?.deselectReaderNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "readAllData"         -> result.success(nidLib?.readAllData()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "ExistApp"            -> result.success(nidLib?.existApp()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "getSoftwareInfoNi"   -> result.success(nidLib?.getSoftwareInfoNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "FtGetLibVersion"     -> result.success(nidLib?.ftGetLibVersion()
                    ?: """{ "ResCode" : -999 , "ResValue" : "not support function FtGetLibVersion"} """)
                "FtGetDevVer"         -> result.success(nidLib?.ftGetDevVer()
                    ?: """{ "ResCode" : -999 , "ResValue" : " not support function FtGetDevVer", "firmwareRevision" : "", "hardwareRevision" : ""} """)
                "getReaderInfoNi"     -> result.success(nidLib?.getReaderInfoNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "FtGetSerialNum"      -> result.success(nidLib?.ftGetSerialNum()
                    ?: """{ "ResCode" : -999 , "ResValue" : " not support function FtGetSerialNum"} """)
                "getRidNi"            -> result.success(nidLib?.getRidNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "scanReaderListBleNi" -> result.success(nidLib?.scanReaderListBleNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "stopReaderListBleNi" -> result.success(nidLib?.stopReaderListBleNi()
                    ?: """{ "ResCode" : 0 , "ResValue" : "OK"} """)
                "getLicenseInfoNi"    -> result.success(nidLib?.getLicenseInfoNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "setReaderType" -> {
                    val type: String = call.argument("readerType") ?: "0"
                    result.success(NidLib.setReaderType(type.trim().toInt()))
                }
                "connectCardNi"    -> result.success(nidLib?.connectCardNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "getNIDTextNi"     -> result.success(nidLib?.getNIDTextNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "getNIDPhotoNi"    -> result.success(nidLib?.getNIDPhotoNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                "disconnectCardNi" -> result.success(nidLib?.disconnectCardNi()
                    ?: """{ "ResCode" : -1 , "ResValue" : "NidLib not initialized"} """)
                else -> {
                    val msg = """{ "ResCode" : -999 , "ResValue" : "${call.method}"} """
                    result.success(msg)
                }
            }
        }
    }

    // ── Auto-request USB permission when device attaches ──
    private fun requestUsbPermissionAuto(device: UsbDevice) {
        val act = activity ?: return
        val usb = usbManager ?: return
        if (usb.hasPermission(device)) {
            eventSink?.success(mapOf("event" to "permission_granted", "device" to device.deviceName))
            Handler(Looper.getMainLooper()).post { autoSelectReader() }
            return
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        val pi = PendingIntent.getBroadcast(act, 0, Intent(ACTION_USB_PERMISSION), flags)
        usb.requestPermission(device, pi)
    }

    // ── Auto-scan readers and notify Flutter ──
    private fun autoSelectReader() {
        try {
            val scanJson = mNidLib?.scanReaderListBleNi() ?: return

            val readerRegex = Regex(""""ResValue"\s*:\s*"([^"]*)"""")
            val resValue = readerRegex.find(scanJson)?.groupValues?.get(1) ?: ""
            val readers = resValue.split(";").filter { it.isNotBlank() }

            if (readers.isNotEmpty()) {
                eventSink?.success(mapOf(
                    "event" to "readers_found",
                    "readers" to readers
                ))
            } else {
                eventSink?.success(mapOf("event" to "reader_not_found"))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in autoSelectReader: ${e.message}")
        }
    }

    // ── List connected CCID / smart card readers ──
    private fun getConnectedSmartCardReaders(): List<Map<String, Any>> {
        val usb = usbManager ?: return emptyList()
        val readers = mutableListOf<Map<String, Any>>()
        for ((_, device) in usb.deviceList) {
            var isSmartCardReader = false
            for (i in 0 until device.interfaceCount) {
                if (device.getInterface(i).interfaceClass == 0x0B) {
                    isSmartCardReader = true
                    break
                }
            }
            if (device.vendorId == 0x04E6) isSmartCardReader = true
            if (isSmartCardReader) {
                readers.add(mapOf(
                    "deviceName" to device.deviceName,
                    "vendorId" to device.vendorId,
                    "productId" to device.productId,
                    "manufacturerName" to (device.manufacturerName ?: "Unknown"),
                    "productName" to (device.productName ?: "Smart Card Reader"),
                    "hasPermission" to usb.hasPermission(device)
                ))
            }
        }
        return readers
    }

    private fun getBatteryLevel(): Int {
        val act = activity ?: return -1
        val bm = act.getSystemService(Activity.BATTERY_SERVICE) as android.os.BatteryManager
        return bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
    }
}
