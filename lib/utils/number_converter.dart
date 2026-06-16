class NumberConverter {
  // Map for English to Myanmar digits
  static const Map<String, String> _enToMy = {
    '0': '၀', '1': '၁', '2': '၂', '3': '၃', '4': '၄',
    '5': '၅', '6': '၆', '7': '၇', '8': '၈', '9': '၉',
  };

  // Map for Myanmar to English digits
  static const Map<String, String> _myToEn = {
    '၀': '0', '၁': '1', '2': '၂', '၃': '3', '၄': '4',
    '၅': '5', '၆': '6', '၇': '7', '၈': '8', '၉': '9',
  };

  /// Converts English numbers (String or num) to Myanmar numbers.
  /// Handles decimals and punctuation like commas or periods.
  static String toMyanmar(dynamic input) {
    if (input == null) return '';

    final String inputStr = input.toString();
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < inputStr.length; i++) {
      final String char = inputStr[i];
      // If the character matches an English digit, convert it; otherwise, keep it as-is
      buffer.write(_enToMy[char] ?? char);
    }

    return buffer.toString();
  }

  /// Converts Myanmar numbers (String) to English numbers.
  static String toEnglish(String input) {
    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < input.length; i++) {
      final String char = input[i];
      // If the character matches a Myanmar digit, convert it; otherwise, keep it as-is
      buffer.write(_myToEn[char] ?? char);
    }

    return buffer.toString();
  }
}