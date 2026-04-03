# thai_card_reader

Flutter plugin สำหรับอ่านข้อมูลบัตรประชาชนไทยผ่านเครื่องอ่านบัตร USB / Bluetooth / BLE โดยใช้ไลบรารี R&D NID (rdnalib)

## Features

- อ่านข้อมูลบัตรประชาชนไทย (ชื่อ, เลขบัตร, วันเกิด, ที่อยู่, รูปภาพ ฯลฯ)
- รองรับเครื่องอ่านบัตร USB, Bluetooth Classic, BLE
- Auto-detect และ auto-connect เครื่องอ่านเมื่อเสียบ USB (Android)
- Stream events สำหรับ progress การอ่านและ USB device events
- รองรับ Android และ iOS

---

## Getting started

### 1. เพิ่ม dependency

ใน `pubspec.yaml` ของ project ที่ต้องการใช้งาน:

```yaml
dependencies:
  thai_card_reader:
    path: /path/to/thai_card_reader
```

---

### 2. Android — วางไฟล์ License

คัดลอกไฟล์ `rdnidlib.dls` (ได้รับจาก R&D) ไปวางที่:

```
android/app/src/main/assets/rdnidlib.dls
```

> สร้างโฟลเดอร์ `assets/` ถ้ายังไม่มี

Plugin จะอ่านไฟล์นี้จาก Android native assets และคัดลอกไปที่ files directory อัตโนมัติเมื่อเรียก `openLib()`

---

### 3. Android — เพิ่ม permissions ใน `AndroidManifest.xml`

Plugin merge permissions ให้อัตโนมัติผ่าน manifest merger แต่ถ้าต้องการ Out-of-App USB permission (แจ้งเตือนเมื่อเสียบเครื่องอ่านขณะแอปปิดอยู่) ให้เพิ่มใน `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
    <!-- ถ้าต้องการ Out-of-App USB permission -->
    <application>
        <activity
            android:name="rd.nalib.UsbEventReceiverActivity"
            android:excludeFromRecents="true"
            android:exported="false"
            android:noHistory="true"
            android:process=":UsbEventReceiverActivityProcess"
            android:taskAffinity="com.example.taskAffinityUsbEventReceiver"
            android:directBootAware="true"
            android:theme="@style/Theme.Transparent">
            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
            </intent-filter>
            <meta-data
                android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
                android:resource="@xml/device_filter" />
        </activity>
    </application>
</manifest>
```

> `device_filter.xml` และ `Theme.Transparent` ถูก bundle ไว้ใน plugin แล้ว ไม่ต้องสร้างเอง

---

### 4. iOS — เพิ่ม Bluetooth permissions ใน `Info.plist`

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>ใช้ Bluetooth สำหรับเชื่อมต่อเครื่องอ่านบัตร</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>ใช้ Bluetooth สำหรับเชื่อมต่อเครื่องอ่านบัตร</string>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>
```

### 5. iOS — `pod install`

```bash
cd ios && pod install
```

> iOS ใช้ BLE เท่านั้น ไม่ต้องวางไฟล์ license (`openLib()` ส่ง empty path ให้อัตโนมัติ)

---

## Usage

### Import

```dart
import 'dart:convert';
import 'package:thai_card_reader/thai_card_reader.dart';
```

### 1. ฟัง Events ก่อนเปิดระบบ

```dart
final reader = ThaiCardReader.instance;

// ฟัง card reading progress events (ทั้ง Android และ iOS)
reader.cardEvents.listen((event) {
  final resCode = event['ResCode']?.toString() ?? '';
  final value   = event['ResValue']?.toString() ?? '';
  if (resCode == 'EVENT_NIDTEXT') {
    print('Progress: $value%');
  }
});

// ฟัง USB hardware events — Android เท่านั้น
reader.usbEvents.listen((event) {
  switch (event['event']) {
    case 'device_attached':
      print('เสียบเครื่องอ่านแล้ว: ${event['device_name']}');
    case 'readers_found':
      print('พบเครื่องอ่าน: ${event['readers']}');
    case 'device_detached':
      print('ถอดเครื่องอ่านแล้ว');
  }
});
```

### 2. เปิดระบบ

```dart
final error = await reader.openLib();
if (error != null) {
  print('เปิดระบบไม่สำเร็จ: $error');
  return;
}
print('เปิดระบบสำเร็จ');
```

### 3. สแกนและเลือกเครื่องอ่าน

`scanReaders()` คืนค่า `Map` ที่ `ResValue` เป็นรายชื่อเครื่องอ่านคั่นด้วย `;` ต้อง parse แล้วเรียก `selectReader()` ต่อ:

```dart
final scanResult = await reader.scanReaders();

if (!reader.isSuccess(scanResult)) {
  print('ไม่พบเครื่องอ่านบัตร');
  return;
}

// ResValue = "Reader1;Reader2;..." — เลือกตัวแรก
final readerName = (scanResult?['ResValue']?.toString() ?? '')
    .split(';')
    .firstWhere((s) => s.trim().isNotEmpty, orElse: () => '');

if (readerName.isEmpty) {
  print('ไม่พบเครื่องอ่านบัตร');
  return;
}

final selectError = await reader.selectReader(readerName);
if (selectError != null) {
  print('เชื่อมต่อไม่สำเร็จ: $selectError');
}
```

### 4. อ่านบัตรประชาชน

```dart
final result = await reader.readCard();

if (result.isSuccess) {
  final card = result.data!;

  print('เลขบัตร: ${card.idNumber}');       // 1-2345-67890-12-3
  print('ชื่อไทย: ${card.fullNameTh}');      // นาย สมชาย ใจดี
  print('ชื่ออังกฤษ: ${card.fullNameEn}');  // Mr. SOMCHAI JAIDEE
  print('เพศ: ${card.gender}');              // ชาย / หญิง
  print('วันเกิด: ${card.dateOfBirth}');     // 01/01/2530
  print('วันหมดอายุ: ${card.expireDate}');   // 31/12/2575 หรือ ตลอดชีพ
  print('บ้านเลขที่: ${card.houseNo}');
  print('ที่อยู่: ${card.address}');
  print('จังหวัด: ${card.province}');
  print('วันออกบัตร: ${card.issueDate}');
  print('ออกที่: ${card.issueDistrict} ${card.issueProvince}');
  print('หมายเลขคำขอ: ${card.requestNo}');  // xxxx-xx-xxxxxxxx

  // รูปภาพ (base64 → Uint8List)
  if (card.photoBase64.isNotEmpty) {
    final imageBytes = base64Decode(card.photoBase64);
    // Image.memory(imageBytes)
  }
} else {
  print('อ่านบัตรไม่สำเร็จ: ${result.error}');
}
```

### 5. ปิดระบบ

```dart
await reader.closeLib();
```

### ดึงข้อมูลเพิ่มเติม

```dart
// รายการ USB smart card readers ที่เสียบอยู่ — Android เท่านั้น
final devices = await reader.getConnectedReaders();
for (final d in devices) {
  print('${d['productName']} — permission: ${d['hasPermission']}');
}

// ข้อมูลเครื่องอ่านที่ connect อยู่
final info = await reader.getReaderInfo();
print(info?['ResValue']);

// เวอร์ชันไลบรารี
final ver = await reader.getSoftwareInfo();
print(ver?['ResValue']);

// ข้อมูล license
final lic = await reader.getLicenseInfo();
print(lic?['ResValue']);
```

---

## CardData Fields

| Field | ตัวอย่าง | คำอธิบาย |
|-------|---------|---------|
| `idNumber` | `1-2345-67890-12-3` | เลขบัตรประชาชน (13 หลัก) |
| `titleTh` | `นาย` | คำนำหน้าชื่อ (ภาษาไทย) |
| `firstNameTh` | `สมชาย` | ชื่อ (ภาษาไทย) |
| `middleNameTh` | `` | ชื่อกลาง (ภาษาไทย) |
| `lastNameTh` | `ใจดี` | นามสกุล (ภาษาไทย) |
| `titleEn` | `Mr.` | คำนำหน้าชื่อ (ภาษาอังกฤษ) |
| `firstNameEn` | `SOMCHAI` | ชื่อ (ภาษาอังกฤษ) |
| `middleNameEn` | `` | ชื่อกลาง (ภาษาอังกฤษ) |
| `lastNameEn` | `JAIDEE` | นามสกุล (ภาษาอังกฤษ) |
| `fullNameTh` | `นาย สมชาย ใจดี` | ชื่อเต็ม (ไทย) — computed getter |
| `fullNameEn` | `Mr. SOMCHAI JAIDEE` | ชื่อเต็ม (อังกฤษ) — computed getter |
| `gender` | `ชาย` / `หญิง` | เพศ |
| `dateOfBirth` | `01/01/2530` | วันเกิด (DD/MM/YYYY) |
| `houseNo` | `123` | บ้านเลขที่ |
| `address` | `ถ.สุขุมวิท แขวงคลองเตย เขตคลองเตย` | ที่อยู่ (address1–6 รวมกัน) |
| `province` | `กรุงเทพมหานคร` | จังหวัด |
| `issueDate` | `15/03/2563` | วันออกบัตร (DD/MM/YYYY) |
| `expireDate` | `14/03/2573` / `ตลอดชีพ` | วันหมดอายุ |
| `issueDistrict` | `เขตคลองเตย` | เขต/อำเภอที่ออกบัตร |
| `issueProvince` | `กรุงเทพมหานคร` | จังหวัดที่ออกบัตร |
| `requestNo` | `1234-56-78901234` | หมายเลขคำขอ (เลขใต้รูป) |
| `photoBase64` | `iVBORw0KGgo...` | รูปภาพ (base64 string) |
| `photoSize` | `6144` | ขนาดรูปภาพ (bytes) |
| `rawText` | `1234567890123#นาย#...` | ข้อมูลดิบจากบัตร (แบ่งด้วย `#`) |

---

## USB Events (Android เท่านั้น)

Stream จาก `reader.usbEvents`

| `event` | ข้อมูลเพิ่มเติม | คำอธิบาย |
|---------|--------------|---------|
| `device_attached` | `device_name`, `vendor_id`, `product_id` | เสียบเครื่องอ่าน USB |
| `device_detached` | — | ถอดเครื่องอ่าน USB |
| `permission_granted` | `device` | ได้รับอนุญาต USB |
| `permission_denied` | — | ปฏิเสธ USB permission |
| `readers_found` | `readers` (List\<String\>) | พบเครื่องอ่านหลัง auto-scan |
| `reader_not_found` | — | ไม่พบเครื่องอ่าน |

## Card Events

Stream จาก `reader.cardEvents`

| `ResCode` | `ResValue` | คำอธิบาย |
|-----------|-----------|---------|
| `EVENT_NIDTEXT` | `0` / `10` / `35` | progress อ่านข้อมูลข้อความ (%) |
| `EVENT_NIDPHOTO` | `100` | อ่านรูปภาพเสร็จ |
| `EVENT_READERLIST` | reader name | พบเครื่องอ่านระหว่าง scan (iOS) |
| `EVENT_READER` | `true` / `false` | สถานะการเชื่อมต่อเครื่องอ่าน (iOS) |
| `EVENT_CARD` | `true` / `false` | สถานะบัตรในเครื่องอ่าน (iOS) |
