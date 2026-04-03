class CardData {
  final String rawText;
  final String photoBase64;
  final int photoSize;

  // parsed fields (Thai NID format)
  final String idNumber;
  final String titleTh;
  final String firstNameTh;
  final String middleNameTh;
  final String lastNameTh;
  final String titleEn;
  final String firstNameEn;
  final String middleNameEn;
  final String lastNameEn;
  final String houseNo;
  final String address;
  final String province;
  final String gender;
  final String dateOfBirth;
  final String issueDistrict;
  final String issueProvince;
  final String issueDate;
  final String expireDate;
  final String requestNo;

  const CardData({
    required this.rawText,
    required this.photoBase64,
    required this.photoSize,
    this.idNumber = '',
    this.titleTh = '',
    this.firstNameTh = '',
    this.middleNameTh = '',
    this.lastNameTh = '',
    this.titleEn = '',
    this.firstNameEn = '',
    this.middleNameEn = '',
    this.lastNameEn = '',
    this.houseNo = '',
    this.address = '',
    this.province = '',
    this.gender = '',
    this.dateOfBirth = '',
    this.issueDistrict = '',
    this.issueProvince = '',
    this.issueDate = '',
    this.expireDate = '',
    this.requestNo = '',
  });

  String get fullNameTh => '$titleTh $firstNameTh $lastNameTh'.trim();
  String get fullNameEn => '$titleEn $firstNameEn $lastNameEn'.trim();

  /// NID text format: IDNumber#TitleTh#FirstTh#MiddleNameTh#LastTh#TitleEn#FirstEn#MiddleNameEn#LastEn#HouseNo#Address1#Address2#Address3#Address4#Address5#Address6#Province#Gender#DOB#IssueDistrict/IssueProvince#IssueDate#ExpireDate#RequestId
  /// Index:           0       1        2       3             4      5        6       7             8      9        10       11       12       13       14       15       16        17      18   19                           20          21           22
  factory CardData.parse(String rawText, String photoBase64, int photoSize) {
    final parts = rawText.split('#');
    final issueLocation = parts.length > 19 ? parts[19].split('/') : <String>[];

    String get(int i) => parts.length > i ? parts[i].trim() : '';

    // IDNumber: xxxxxxxxxxxxx -> x-xxxx-xxxxx-xx-x
    String formatId(String id) {
      if (id.length != 13) return id;
      return '${id[0]}-${id.substring(1, 5)}-${id.substring(5, 10)}-${id.substring(10, 12)}-${id.substring(12, 13)}';
    }

    // Date: YYYYMMDD -> DD/MM/YYYY
    String formatDate(String date) {
      if (date.length == 8) {
        final year = date.substring(0, 4);
        final month = date.substring(4, 6);
        final day = date.substring(6, 8);
        return '$day/$month/$year';
      }
      return date;
    }

    // RequestNo: xxxxxxxxxxxxxx -> xxxx-xx-xxxxxxxx
    String formatRequestNo(String requestNo) {
      if (requestNo.length < 14) return requestNo;
      return '${requestNo.substring(0, 4)}-${requestNo.substring(4, 6)}-${requestNo.substring(6, 14)}';
    }

    return CardData(
      rawText: rawText,
      photoBase64: photoBase64,
      photoSize: photoSize,
      idNumber: formatId(get(0)),
      titleTh: get(1),
      firstNameTh: get(2),
      middleNameTh: get(3),
      lastNameTh: get(4),
      titleEn: get(5),
      firstNameEn: get(6),
      middleNameEn: get(7),
      lastNameEn: get(8),
      houseNo: get(9),
      address: '${get(10)} ${get(11)} ${get(12)} ${get(13)} ${get(14)} ${get(15)}'.trim(),
      province: get(16),
      gender: get(17) == '1'
          ? 'ชาย'
          : get(17) == '2'
              ? 'หญิง'
              : '',
      dateOfBirth: formatDate(get(18)),
      issueDistrict: issueLocation.isNotEmpty ? issueLocation[0] : '',
      issueProvince: issueLocation.length > 1 ? issueLocation[1] : '',
      issueDate: formatDate(get(20)),
      expireDate: get(21) != '99999999' ? formatDate(get(21)) : 'ตลอดชีพ',
      requestNo: formatRequestNo(get(22)),
    );
  }
}
