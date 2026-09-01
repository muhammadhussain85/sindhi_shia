import 'package:flutter/material.dart';

class ArabicSearchUtils {
  static final RegExp _diacriticsRegExp = RegExp(r'[\u064B-\u065F\u0670\u200C]');

  // ✨ UPDATED: Added 'ھ' (Doachashmi Heh) and 'ة' (Teh Marbuta) to the equivalence class
  static const Map<String, String> _sindhiToLegacyGroup = {
    'ا': '[اإأآ]', 'آ': '[آ]', 'ب': '[ب]', 'ٻ': '[ٻت]', 'ڀ': '[ڀث]',
    'ت': '[تج]', 'ٿ': '[ٿح]', 'ٽ': '[ٽخ]', 'ث': '[ثش]', 'پ': '[پص]',
    'ج': '[جض]', 'ڄ': '[ڄط]', 'ڃ': '[ڃع]', 'چ': '[چغ]', 'ڇ': '[ڇف]',
    'ح': '[حق]', 'خ': '[خك]', 'د': '[دڈ]', 'ڌ': '[ڌڍ]', 'ڏ': '[ڏڊ]',
    'ڊ': '[ڊڋ]', 'ڍ': '[ڍذ]', 'ر': '[رڎ]', 'ڙ': '[ڙڏ]', 'ز': '[زڐ]',
    'س': '[سښ]', 'ش': '[شڛ]', 'ص': '[صڜ]', 'ض': '[ضڝ]', 'ط': '[طڞ]',
    'ظ': '[ظڟ]', 'ع': '[عڠ]', 'غ': '[غڡ]', 'ف': '[فڢ]', 'ڦ': '[ڦک]',
    'ق': '[قڤ]', 'ک': '[کڦ]', 'ڪ': '[ڪڥ]', 'گ': '[گڧ]', 'ڳ': '[ڳک]',
    'ڱ': '[ڱڪ]', 'ل': '[لڵ]', 'م': '[مڶ]', 'ن': '[نڷ]', 'ڻ': '[ڻڼ]',
    'و': '[وۆۇ]',
    'ه': '[هہێۏھة]', 'ہ': '[هہێۏھة]', 'ھ': '[هہێۏھة]', 'ة': '[هہێۏھة]',
    'ء': '[ء٭]',
    'ي': '[يیۑئ]', 'ی': '[يیۑئ]', 'ئ': '[يیۑئ]',
  };

  static const Map<String, String> _legacyToSindhi = {
    'إ': 'ا', 'أ': 'ا', 'ت': 'ٻ', 'ث': 'ڀ', 'ج': 'ت', 'ح': 'ٿ',
    'خ': 'ٽ', 'ش': 'ث', 'ص': 'پ', 'ض': 'ج', 'ط': 'ڄ', 'ع': 'ڃ',
    'غ': 'چ', 'ف': 'ڇ', 'ق': 'ح', 'ك': 'خ', 'ڈ': 'د', 'ڍ': 'ڌ',
    'ڊ': 'ڏ', 'ڋ': 'ڊ', 'ذ': 'ڍ', 'ڎ': 'ر', 'ڏ': 'ڙ', 'ڐ': 'ز',
    'ښ': 'س', 'ڛ': 'ش', 'ڜ': 'ص', 'ڝ': 'ض', 'ڞ': 'ط', 'ڟ': 'ظ',
    'ڠ': 'ع', 'ڡ': 'غ', 'ڢ': 'ف', 'ڤ': 'ق', 'ڦ': 'ک',
    'ڥ': 'ڪ', 'ڧ': 'گ', 'ک': 'ڳ', 'ڪ': 'ڱ', 'ڵ': 'ل', 'ڶ': 'م',
    'ڷ': 'ن', 'ڼ': 'ڻ', 'ۆ': 'و', 'ۇ': 'و', 'ێ': 'ه', 'ۏ': 'ه',
    '٭': 'ء', 'ۑ': 'ي', 'ی': 'ئ', '^': 'الله',
  };

  static String decryptRNLashari(String text) {
    if (text.isEmpty) return '';
    StringBuffer decrypted = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      decrypted.write(_legacyToSindhi[char] ?? char);
    }
    return decrypted.toString();
  }

  // ✨ UPDATED: Normalizes all versions of Heh to standard 'ه'
  static String normalizeLetters(String text) {
    return text
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک')
        .replaceAll(RegExp(r'[ہھة]'), 'ه')
        .replaceAll(RegExp(r'[أإآ]'), 'ا');
  }

  // ✨ NEW: Added `ignoreSpaces` parameter. If true, it inserts \s* everywhere!
  static RegExp getHighlightRegex(String query, {bool isLegacyFont = false, bool ignoreSpaces = false}) {
    String processedQuery = query.trim();
    if (processedQuery.isEmpty) return RegExp(r'');

    // If ignoring spaces, we allow optional spaces (\s*) between EVERY character and diacritic
    String separator = ignoreSpaces ? r'[\u064B-\u065F\u0670\u200C\s]*' : r'[\u064B-\u065F\u0670\u200C]*';

    if (isLegacyFont) {
      String pattern = processedQuery.split('').map((char) {
        if (char.trim().isEmpty) return ignoreSpaces ? r'\s*' : r'\s+';
        return _sindhiToLegacyGroup[char] ?? RegExp.escape(char);
      }).join(separator);

      return RegExp(pattern, caseSensitive: true);
    } else {
      processedQuery = normalizeLetters(processedQuery);

      String pattern = processedQuery.split('').map((char) {
        if (char.trim().isEmpty) return ignoreSpaces ? r'\s*' : r'\s+';
        return RegExp.escape(char);
      }).join(separator);

      return RegExp(pattern, caseSensitive: false);
    }
  }

  static List<TextSpan> buildHighlightedSpans(String text, RegExp regex, TextStyle baseStyle, TextStyle highlightStyle, {bool isLegacyFont = false}) {
    if (regex.pattern.isEmpty) return [TextSpan(text: text, style: baseStyle)];

    List<TextSpan> spans = [];
    int start = 0;
    String textToSearch = isLegacyFont ? text : normalizeLetters(text);
    Iterable<Match> matches = regex.allMatches(textToSearch);

    for (Match match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start), style: baseStyle));
      }
      spans.add(TextSpan(text: text.substring(match.start, match.end), style: highlightStyle));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }

    return spans;
  }
}