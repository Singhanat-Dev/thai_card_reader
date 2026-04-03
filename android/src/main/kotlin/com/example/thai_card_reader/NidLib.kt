package com.example.thai_card_reader

import android.Manifest
import android.app.Activity
import android.content.res.AssetManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Message
import android.os.MessageQueue

import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat

import io.flutter.plugin.common.BasicMessageChannel
import io.flutter.util.PathUtils.getFilesDir

import rd.nalib.NA
import rd.nalib.ResponseListener

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.InputStream;
import java.lang.reflect.Field
import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method
import java.util.ArrayList;
import java.util.Base64

class NidLib(activity: Activity) {

    companion object {
        private const val TAG = "NidLib"

        private const val NA_BLE1 = 0x08
        private const val NA_BLE0 = 0x04
        private const val NA_POPUP = 0x80
        private const val NA_SCAN = 0x10
        private const val NA_BLE = NA_BLE1 + NA_BLE0
        private const val NA_BT = 0x02
        private const val NA_USB = 0x01

        private lateinit var mFlutterContext: Activity
        private var mNiOS: NA? = null
        private var nActiveReaderType = NA_BLE + NA_BT + NA_USB

        fun setReaderType(ntype: Int): String {
            nActiveReaderType = when (ntype) {
                1 -> NA_USB
                2 -> NA_BT
                3 -> NA_USB + NA_BT
                4 -> NA_BLE
                7 -> NA_USB + NA_BT + NA_BLE
                else -> NA_BLE + NA_BT + NA_USB
            }
            return """{ "ResCode" : 0 , "ResValue" : "OK"} """
        }

        fun getReaderType(): Int = nActiveReaderType
    }

    private var mBasicMessageChannel: BasicMessageChannel<String>? = null

    init {
        mFlutterContext = activity
    }

    private val responseListener = object : MyResponseListener {
        private val INIT_RESULT = -9999
        private var iRes = INIT_RESULT
        private var resValue = ""

        private var mMsgQueueNextMethod: Method? = null
        private var mMsgTargetField: Field? = null
        private var mQuitModal = false

        override fun init() {
            prepareModal()
        }

        private fun prepareModal(): Boolean {
            return try {
                val clsMsgQueue = Class.forName("android.os.MessageQueue")
                val clsMessage = Class.forName("android.os.Message")

                mMsgQueueNextMethod = clsMsgQueue.getDeclaredMethod("next").also {
                    it.isAccessible = true
                }
                mMsgTargetField = clsMessage.getDeclaredField("target").also {
                    it.isAccessible = true
                }
                true
            } catch (e: Exception) {
                e.printStackTrace()
                false
            }
        }

        private fun forceExitMessageLoop() {
            mQuitModal = true
        }

        private fun initMessageLoop() {
            mQuitModal = false
        }

        private fun messageLoop() {
            val queue: MessageQueue = Looper.myQueue()
            while (!mQuitModal) {
                try {
                    val msg = mMsgQueueNextMethod?.invoke(queue) as? Message ?: continue
                    val target = mMsgTargetField?.get(msg) as? Handler
                    if (target == null) {
                        mQuitModal = true
                    } else {
                        target.dispatchMessage(msg)
                    }
                } catch (e: IllegalArgumentException) {
                    e.printStackTrace()
                } catch (e: IllegalAccessException) {
                    e.printStackTrace()
                } catch (e: InvocationTargetException) {
                    e.printStackTrace()
                }
            }
        }

        override fun initResult(): Int {
            iRes = INIT_RESULT
            resValue = ""
            initMessageLoop()
            return 0
        }

        override fun getResult(): Int {
            messageLoop()
            return iRes
        }

        override fun getResultValue(): String {
            if (iRes == INIT_RESULT) getResult()
            return resValue
        }

        private fun setResult(res: Int) {
            iRes = res
            forceExitMessageLoop()
        }

        private fun setResultValue(value: String) {
            resValue = value
            forceExitMessageLoop()
        }

        override fun onOpenLibNA(iResult: Int) {
            setResult(iResult)
            setResultValue(" ")
        }

        override fun onGetReaderListNA(arrayList: ArrayList<String>?, iResult: Int) {
            if (arrayList != null) {
                setResult(arrayList.size)
                val readerList = arrayList.joinToString(";")
                arrayList.forEach { readerName ->
                    val msg = """{ "ResCode" : "EVENT_READERLIST" , "ResValue" : "0", "ResText" : "$readerName" } """
                    sendEventWithName(msg)
                }
                setResult(iResult)
                setResultValue(readerList)
            } else {
                setResult(iResult)
                setResultValue("")
            }
        }

        override fun onSelectReaderNA(iResult: Int) {
            setResult(iResult)
            setResultValue(" ")
        }

        override fun onGetNIDNumberNA(s: String?, iResult: Int) {}

        override fun onGetNIDTextNA(sData: String?, iResult: Int) {
            if (iResult == 0) {
                setResult(iResult)
                setResultValue(sData ?: "")
            } else {
                setResult(iResult)
                setResultValue("NI_GET_TEXT_ERROR")
            }
        }

        @RequiresApi(Build.VERSION_CODES.O)
        override fun onGetNIDPhotoNA(sData: ByteArray?, iResult: Int) {
            if (iResult == 0 && sData != null) {
                val sValue = Base64.getEncoder().encodeToString(sData)
                setResult(sData.size)
                setResultValue(sValue)
            } else {
                setResult(iResult)
                setResultValue("NI_GET_PHOTO_ERROR")
            }
        }

        override fun onUpdateLicenseFileNA(iResult: Int) {
            setResult(iResult)
        }
    }

    fun bindMessageChannel(channel: BasicMessageChannel<String>?) {
        mBasicMessageChannel = channel
    }

    // ฟังก์ชันสำหรับดึงอินสแตนซ์ของ NA และขออนุญาตที่จำเป็นสำหรับการใช้งานไลบรารี
    fun getNiOS(): NA {
        if (mNiOS == null) {
            mNiOS = NA(mFlutterContext).also { na ->
                ActivityCompat.requestPermissions(
                    mFlutterContext,
                    arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE, Manifest.permission.ACCESS_FINE_LOCATION),
                    0x1
                )
                na.setPermissionsNA(0)
                responseListener.init()
                na.setListenerNA(responseListener)
            }
        }
        return mNiOS!!
    }

    // เปิดไลบรารีในโฟลเดอร์
    fun writeLicFile(path: String, filename: String) {
        val assetManager: AssetManager = mFlutterContext.assets
        try {
            val inputStream = assetManager.open("rdnidlib.dls")
            val fullName = "$path/$filename"
            val outFile = File(fullName)
            if (outFile.exists()) return

            File(path).mkdirs()
            val buffer = ByteArray(1024)
            FileOutputStream(outFile).use { fos ->
                var read: Int
                while (inputStream.read(buffer, 0, 1024).also { read = it } >= 0) {
                    fos.write(buffer, 0, read)
                }
                fos.flush()
            }
            inputStream.close()
        } catch (e: IOException) {
            e.printStackTrace()
        }
    }

    // เปิดไลบรารี
    fun openNiOSLibNi(strLICPath: String): String {
        val niOS = getNiOS()
        val path: String = if (strLICPath.isNotEmpty()) {
            val rootFolder = getFilesDir(mFlutterContext) + "/NidApp"
            writeLicFile(rootFolder, strLICPath)
            "$rootFolder/$strLICPath"
        } else {
            strLICPath
        }

        responseListener.initResult()
        niOS.openLibNA(path)
        val res = responseListener.getResult()
        val resValue = responseListener.getResultValue()
        return """{ "ResCode" : $res , "ResValue" : "$resValue"} """
    }

    // ปิดไลบรารี
    fun closeNiOSLibNi(): String {
        val res = mNiOS?.closeLibNA() ?: -1
        return """{ "ResCode" : $res , "ResValue" : ""} """
    }

    // สแกนหาเครื่องอ่านที่รองรับ BLE
    fun scanReaderListBleNi(): String {
        val niOS = getNiOS()
        responseListener.initResult()
        niOS.getReaderListNA(NA_SCAN + getReaderType())
        val res = responseListener.getResult()
        val resValue = responseListener.getResultValue()
        return """{ "ResCode" : $res , "ResValue" : "$resValue"} """
    }

    // หยุดการสแกนหาเครื่องอ่านที่รองรับ BLE
    fun stopReaderListBleNi(): String =
        """{ "ResCode" : 0 , "ResValue" : "OK"} """

    // ดึงรายการเครื่องอ่านที่รองรับทั้งหมด (จะแสดง popup ให้เลือกเครื่องอ่าน)
    fun getReaderListNi(): String {
        val niOS = getNiOS()
        responseListener.initResult()
        niOS.getReaderListNA(NA_SCAN + getReaderType() + NA_POPUP)
        val res = responseListener.getResult()
        val resValue = responseListener.getResultValue()
        return """{ "ResCode" : $res , "ResValue" : "$resValue"} """
    }

    // เลือกเครื่องอ่านที่ต้องการใช้งาน
    fun selectReaderNi(reader: String): String {
        val niOS = getNiOS()
        responseListener.initResult()
        niOS.selectReaderNA(reader)
        val res = responseListener.getResult()
        val resValue = responseListener.getResultValue()
        return """{ "ResCode" : $res , "ResValue" : "$resValue"} """
    }

    // ยกเลิกการเลือกเครื่องอ่าน
    fun deselectReaderNi(): String {
        val niOS = getNiOS()
        val res = niOS.deselectReaderNA()
        return """{ "ResCode" : $res , "ResValue" : ""} """
    }

    // เชื่อมต่อบัตร
    fun connectCardNi(): String {
        val niOS = getNiOS()
        val res = niOS.connectCardNA()
        return """{ "ResCode" : $res , "ResValue" : ""} """
    }

    // ตัดการเชื่อมต่อบัตร
    fun disconnectCardNi(): String {
        val niOS = getNiOS()
        val res = niOS.disconnectCardNA()
        return """{ "ResCode" : $res , "ResValue" : ""} """
    }

    // ดึงข้อมูลข้อความจากบัตร
    fun getNIDTextNi(): String {
        val niOS = getNiOS()
        responseListener.initResult()
        niOS.getNIDTextNA()
        val res = responseListener.getResult()
        val resValue = responseListener.getResultValue()
        return """{ "ResCode" : $res , "ResValue" : "$resValue"} """
    }

    // ดึงข้อมูลรูปภาพจากบัตร
    fun getNIDPhotoNi(): String {
        val niOS = getNiOS()
        responseListener.initResult()
        niOS.getNIDPhotoNA()
        val res = responseListener.getResult()
        val resValue = responseListener.getResultValue()
        return """{ "ResCode" : $res , "ResValue" : "$resValue"} """
    }

    // ส่งอีเวนต์ไปยัง Flutter เมื่อมีการอ่านข้อมูลจากบัตร
    fun sendEventWithName(eventData: String) {
        mBasicMessageChannel?.send(eventData)
    }

    // อ่านข้อมูลทั้งหมดจากบัตร (ข้อความและรูปภาพ) พร้อมส่งอีเวนต์ระหว่างการอ่านข้อมูล
    fun readAllData(): String {
        sendEventWithName("""{ "ResCode" : "EVENT_NIDTEXT" , "ResValue" : "0"} """)

        val niOS = getNiOS()

        responseListener.initResult()
        var res = niOS.connectCardNA() // ตรวจสอบการเชื่อมต่อบัตรก่อนอ่านข้อมูล
        if (res != 0) {
            return """{ "ResCode" : $res , "ResValue" : "NI_CONNECTION_ERROR"} """
        }

        sendEventWithName("""{ "ResCode" : "EVENT_NIDTEXT" , "ResValue" : "10"} """)

        val startTime = System.nanoTime()

        responseListener.initResult()
        niOS.getNIDTextNA() // อ่านข้อมูลข้อความจากบัตร
        res = responseListener.getResult()
        if (res != 0) {
            niOS.disconnectCardNA()
            return """{ "ResCode" : $res , "ResValue" : "NI_GET_TEXT_ERROR"} """
        }

        val nsDataTxt = responseListener.getResultValue()
        val textTime = System.nanoTime()

        sendEventWithName("""{ "ResCode" : "EVENT_NIDTEXT" , "ResValue" : "35", "ResText" : "$nsDataTxt"} """)

        responseListener.initResult()
        niOS.getNIDPhotoNA() // อ่านข้อมูลรูปภาพจากบัตร
        val photoTime = System.nanoTime()

        val zPhotoSize = responseListener.getResult()
        if (zPhotoSize < 0) {
            niOS.disconnectCardNA() // ตัดการเชื่อมต่อบัตรเมื่อเกิดข้อผิดพลาดในการอ่านข้อมูลรูปภาพ
            return """{ "ResCode" : $res , "ResValue" : "NI_GET_PHOTO_ERROR"} """
        }

        val sPhoto = responseListener.getResultValue()

        val totalTextSec = (textTime - startTime) / 1_000_000_000.0
        val totalTextPhotoSec = (photoTime - startTime) / 1_000_000_000.0
        val msgTime = "$nsDataTxt \\n\\n Read Text= %.2f s \\n Read Text + Photo= %.2f s"
            .format(totalTextSec, totalTextPhotoSec)

        sendEventWithName("""{ "ResCode" : "EVENT_NIDPHOTO" , "ResValue" : "100"} """)

        val msg = """{ "ResCode" : $res , "ResValue" : "100", "ResText" : "$msgTime" , "ResPhoto" : "$sPhoto","ResPhotoSize" :"$zPhotoSize"} """
        sendEventWithName(msg)

        niOS.disconnectCardNA() // ตัดการเชื่อมต่อบัตรหลังจากอ่านข้อมูลเสร็จสิ้น
        return msg
    }

    // อัปเดตไฟล์ใบอนุญาต
    fun updateLicenseFileNi(): String {
        val niOS = getNiOS()
        responseListener.initResult()
        niOS.updateLicenseFileNA()
        val res = responseListener.getResult()
        val resValue = responseListener.getResultValue()
        return """{ "ResCode" : $res , "ResValue" : "$resValue"} """
    }

    // ดึงข้อมูลเวอร์ชันของไลบรารี
    fun getSoftwareInfoNi(): String {
        val niOS = getNiOS()
        val ver = arrayOfNulls<String>(1)
        val res = niOS.getSoftwareInfoNA(ver)
        return """{ "ResCode" : $res , "ResValue" : "${ver[0]}"} """
    }

    // ดึงข้อมูลเครื่องอ่านที่เชื่อมต่ออยู่
    fun getReaderInfoNi(): String {
        val niOS = getNiOS()
        val nsData = arrayOfNulls<String>(1)
        val res = niOS.getReaderInfoNA(nsData)
        return if (res == 0) {
            """{ "ResCode" : $res , "ResValue" : "${nsData[0]}"} """
        } else {
            """{ "ResCode" : $res , "ResValue" : "error code $res"} """
        }
    }

    // ดึงรหัส RID ของเครื่องอ่าน
    fun getRidNi(): String {
        val niOS = getNiOS()
        val rid = ByteArray(16)
        val result = niOS.getRidNA(rid)
        return if (result == 16) {
            val hexString = rid.joinToString(" ") { byte ->
                Integer.toHexString(0xFF and byte.toInt()).padStart(2, '0').uppercase()
            }
            """{ "ResCode" : 16 , "ResValue" : "$hexString"} """
        } else {
            """{ "ResCode" : $result , "ResValue" : "-"} """
        }
    }

    fun ftGetLibVersion(): String =
        """{ "ResCode" : -999 , "ResValue" : "not support function FtGetLibVersion"} """

    fun ftGetDevVer(): String =
        """{ "ResCode" : -999 , "ResValue" : " not support function FtGetDevVer", "firmwareRevision" : "", "hardwareRevision" : ""} """

    fun ftGetSerialNum(): String =
        """{ "ResCode" : -999 , "ResValue" : " not support function FtGetSerialNum"} """

    // ฟังก์ชันสำหรับทดสอบการมีอยู่ของแอป (จะปิดแอปเมื่อเรียกใช้)
    fun existApp(): String {
        val msg = """{ "ResCode" : 0 , "ResValue" : ""} """
        System.exit(0)
        return msg
    }

    // ดึงข้อมูลใบอนุญาตที่ใช้งานอยู่
    fun getLicenseInfoNi(): String {
        val niOS = getNiOS()
        val data = arrayOfNulls<String>(1)
        val result = niOS.getLicenseInfoNA(data)
        return """{ "ResCode" : $result , "ResValue" : "${data[0]}"} """
    }

    interface MyResponseListener : ResponseListener {
        fun init()
        fun initResult(): Int
        fun getResult(): Int
        fun getResultValue(): String
    }
}
