import 'dart:io';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../controllers/settings_controller.dart';

class DBHelper {
  // ✨ THE MAGIC NUMBER ✨
  // Whenever you make changes to your databases and release an app update,
  // just increase this number by 1 (e.g., change 2 to 3).
  // The app will automatically overwrite the old databases with your new ones!
  static const int DATABASE_VERSION = 2;

  static Database? _sahifaDatabase;
  static Database? _quranDatabase;
  static Database? _istikharaDatabase;
  static Database? _nahjulDatabase;
  static Database? _ahadithDatabase;
  static Database? _ziyaratDatabase;
  static Database? _citiesDatabase;
  static Database? _calendarDatabase;
  static Database? _bookmarksDatabase;

  // --------------------------------------------------------
  // 1. CONNECTION MANAGERS & INITIALIZERS
  // --------------------------------------------------------

  static void clearQuranDatabase() {
    _quranDatabase = null;
  }

  static Future<Database> get sahifaDatabase async {
    if (_sahifaDatabase != null) return _sahifaDatabase!;
    _sahifaDatabase = await _initDB('sahifa.db');
    return _sahifaDatabase!;
  }

  static Future<Database> get quranDatabase async {
    if (_quranDatabase != null) return _quranDatabase!;
    _quranDatabase = await _initQuranDB();
    return _quranDatabase!;
  }

  static Future<Database> get istikharaDatabase async {
    if (_istikharaDatabase != null) return _istikharaDatabase!;
    _istikharaDatabase = await _initDB('istikhara.db');
    return _istikharaDatabase!;
  }

  static Future<Database> get nahjulDatabase async {
    if (_nahjulDatabase != null) return _nahjulDatabase!;
    _nahjulDatabase = await _initDB('nahjul1.db');
    return _nahjulDatabase!;
  }

  static Future<Database> get ahadithDatabase async {
    if (_ahadithDatabase != null) return _ahadithDatabase!;
    _ahadithDatabase = await _initDB('ahadith.db');
    return _ahadithDatabase!;
  }

  static Future<Database> get ziyaratDatabase async {
    if (_ziyaratDatabase != null) return _ziyaratDatabase!;
    _ziyaratDatabase = await _initDB('ziyarat.db');
    return _ziyaratDatabase!;
  }

  static Future<Database> get citiesDatabase async {
    if (_citiesDatabase != null) return _citiesDatabase!;
    _citiesDatabase = await _initDB('cities.db');
    return _citiesDatabase!;
  }

  static Future<Database> get calendarDatabase async {
    if (_calendarDatabase != null) return _calendarDatabase!;
    _calendarDatabase = await _initDB('calendar.db');
    return _calendarDatabase!;
  }

  static Future<Database> get bookmarksDatabase async {
    if (_bookmarksDatabase != null) return _bookmarksDatabase!;
    _bookmarksDatabase = await _initBookmarksDB();
    return _bookmarksDatabase!;
  }

  // Standard static initializer (Copies DB from assets to local device storage)
  static Future<Database> _initDB(String fileName) async {
    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, fileName);
    var exists = await databaseExists(path);

    final storage = GetStorage();
    int currentSavedVersion = storage.read('db_version_$fileName') ?? 1;

    // ✨ THE FIX: If the DB doesn't exist OR the version number was increased, copy the new DB!
    if (!exists || currentSavedVersion < DATABASE_VERSION) {
      try {
        if (exists) {
          await deleteDatabase(path); // Delete the old outdated database
        }

        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(join("assets/databases", fileName));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);

        // Save the new version number so it doesn't copy again until the next update
        storage.write('db_version_$fileName', DATABASE_VERSION);
      } catch (e) {
        throw Exception("Database file '$fileName' not found in assets.");
      }
    }
    return await openDatabase(path);
  }

  // Dynamic Quran initializer based on user translation preference
  static Future<Database> _initQuranDB() async {
    final settings = Get.find<SettingsController>();
    String dbName = settings.selectedTranslation.value == 0 ? "quran.db" : "quran2.db";

    var databasesPath = await getDatabasesPath();
    var path = join(databasesPath, dbName);
    var exists = await databaseExists(path);

    final storage = GetStorage();
    int currentSavedVersion = storage.read('db_version_$dbName') ?? 1;

    if (!exists || currentSavedVersion < DATABASE_VERSION) {
      try {
        if (exists) {
          await deleteDatabase(path);
        }

        await Directory(dirname(path)).create(recursive: true);
        ByteData data = await rootBundle.load(join("assets/databases", dbName));
        List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);

        storage.write('db_version_$dbName', DATABASE_VERSION);
      } catch (e) {
        throw Exception("Database file '$dbName' not found in assets.");
      }
    }
    return await openDatabase(path);
  }

  // User-owned bookmarks DB — created fresh on device, never copied from assets.
  static Future<Database> _initBookmarksDB() async {
    final path = join(await getDatabasesPath(), 'user_bookmarks.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book_type TEXT NOT NULL,
            unique_id TEXT NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            arabic TEXT NOT NULL DEFAULT '',
            translation TEXT NOT NULL DEFAULT '',
            nickname TEXT NOT NULL DEFAULT '',
            note TEXT NOT NULL DEFAULT '',
            translation_index INTEGER NOT NULL DEFAULT 0,
            timestamp TEXT NOT NULL DEFAULT '',
            UNIQUE(book_type, unique_id)
          )
        ''');
      },
    );
  }

  // --------------------------------------------------------
  // 2. SAHIFA SAJJADIYA QUERIES
  // --------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getChapters() async {
    final db = await sahifaDatabase;
    return await db.query('Chaps');
  }

  static Future<List<Map<String, dynamic>>> getSections(int chapRowId) async {
    final db = await sahifaDatabase;
    final chapInfo = await db.query('Chaps', where: 'ID = ?', whereArgs: [chapRowId]);
    if (chapInfo.isEmpty) return [];

    final realChapId = chapInfo.first['cid'];
    return await db.query('Sections', where: 'Chapid = ?', whereArgs: [realChapId]);
  }

  static Future<List<Map<String, dynamic>>> getParagraphs(int secRowId) async {
    final db = await sahifaDatabase;
    final secInfo = await db.query('Sections', where: 'ID = ?', whereArgs: [secRowId]);
    if (secInfo.isEmpty) return [];

    final realSecId = secInfo.first['Secid'];
    return await db.query('Parags', where: 'Secid = ?', orderBy: 'paganum ASC', whereArgs: [realSecId]);
  }

  // --------------------------------------------------------
  // 3. QURAN QUERIES
  // --------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getSurahs() async {
    final db = await quranDatabase;
    return await db.query('ChapterProperty', orderBy: 'Id ASC');
  }

  static Future<List<Map<String, dynamic>>> getAyahsBySurah(int chapterId) async {
    final db = await quranDatabase;
    return await db.query('Quran', where: 'chapter = ?', orderBy: 'verse ASC', whereArgs: [chapterId]);
  }

  static Future<List<Map<String, dynamic>>> getAyahsByJuz(int juzId) async {
    final db = await quranDatabase;
    final List<Map<String, int>> juzBounds = [
      {'start': 1,    'end': 148},   {'start': 149,  'end': 259},
      {'start': 260,  'end': 384},   {'start': 385,  'end': 516},
      {'start': 517,  'end': 640},   {'start': 641,  'end': 751},
      {'start': 752,  'end': 899},   {'start': 900,  'end': 1041},
      {'start': 1042, 'end': 1200},  {'start': 1201, 'end': 1328},
      {'start': 1329, 'end': 1478},  {'start': 1479, 'end': 1648},
      {'start': 1649, 'end': 1803},  {'start': 1804, 'end': 2029},
      {'start': 2030, 'end': 2214},  {'start': 2215, 'end': 2483},
      {'start': 2484, 'end': 2673},  {'start': 2674, 'end': 2875},
      {'start': 2876, 'end': 3218},  {'start': 3219, 'end': 3384},
      {'start': 3385, 'end': 3563},  {'start': 3564, 'end': 3726},
      {'start': 3727, 'end': 4089},  {'start': 4090, 'end': 4264},
      {'start': 4265, 'end': 4510},  {'start': 4511, 'end': 4705},
      {'start': 4706, 'end': 5104},  {'start': 5105, 'end': 5241},
      {'start': 5242, 'end': 5672},  {'start': 5673, 'end': 6236},
    ];
    int startId = juzBounds[juzId - 1]['start']!;
    int endId = juzBounds[juzId - 1]['end']!;

    return await db.query('Quran', where: 'ID BETWEEN ? AND ?', whereArgs: [startId, endId], orderBy: 'ID ASC');
  }

  // --------------------------------------------------------
  // 4. ISTIKHARA QUERIES
  // --------------------------------------------------------

  static Future<Map<String, dynamic>?> getRandomIstikhara() async {
    final db = await istikharaDatabase;
    final result = await db.rawQuery('SELECT * FROM istikhara ORDER BY RANDOM() LIMIT 1');
    if (result.isNotEmpty) return result.first;
    return null;
  }

  // --------------------------------------------------------
  // 5. NAHJUL BALAGHA QUERIES
  // --------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getNahjulChapters() async {
    final db = await nahjulDatabase;
    return await db.query('Chaps');
  }

  static Future<List<Map<String, dynamic>>> getNahjulSections(int chapRowId) async {
    final db = await nahjulDatabase;
    final chapInfo = await db.query('Chaps', where: 'ID = ?', whereArgs: [chapRowId]);
    if (chapInfo.isEmpty) return [];

    final realChapId = chapInfo.first['cid'];
    return await db.query('Sections', where: 'Chapid = ?', whereArgs: [realChapId]);
  }

  static Future<List<Map<String, dynamic>>> getNahjulParagraphs(int secRowId) async {
    final db = await nahjulDatabase;
    final secInfo = await db.query('Sections', where: 'ID = ?', whereArgs: [secRowId]);
    if (secInfo.isEmpty) return [];

    final realSecId = secInfo.first['Secid'];
    return await db.query('Parags', where: 'Secid = ?', orderBy: 'paganum ASC', whereArgs: [realSecId]);
  }

  // --------------------------------------------------------
  // 6. AHADITH QUERIES
  // --------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getAhadithCategories() async {
    final db = await ahadithDatabase;
    return await db.query('numorison', orderBy: 'id ASC');
  }

  static Future<List<Map<String, dynamic>>> getAhadithByCategory(int categoryId) async {
    final db = await ahadithDatabase;
    return await db.query('orison', where: 'numorison_id = ?', orderBy: 'id ASC', whereArgs: [categoryId]);
  }

  // --------------------------------------------------------
  // 7. ZIYARAT & DUAS QUERIES
  // --------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getZiyaratChapters() async {
    final db = await ziyaratDatabase;
    return await db.query('Chaps');
  }

  static Future<List<Map<String, dynamic>>> getZiyaratSections(int chapRowId) async {
    final db = await ziyaratDatabase;
    final chapInfo = await db.query('Chaps', where: 'ID = ?', whereArgs: [chapRowId]);
    if (chapInfo.isEmpty) return [];

    final realChapId = chapInfo.first['cid'];
    return await db.query('Sections', where: 'Chapid = ?', whereArgs: [realChapId]);
  }

  static Future<List<Map<String, dynamic>>> getZiyaratParagraphs(int secRowId) async {
    final db = await ziyaratDatabase;
    final secInfo = await db.query('Sections', where: 'ID = ?', whereArgs: [secRowId]);
    if (secInfo.isEmpty) return [];

    final realSecId = secInfo.first['Secid'];
    return await db.query('Parags', where: 'Secid =  ?', orderBy: 'paganum ASC', whereArgs: [realSecId]);
  }

  // --------------------------------------------------------
  // 8. CITIES SEARCH QUERIES
  // --------------------------------------------------------

  static Future<List<Map<String, dynamic>>> searchCities(String query) async {
    final db = await citiesDatabase;
    return await db.rawQuery("SELECT city, country, lat, lng FROM cities WHERE city LIKE ? OR city_ascii LIKE ? LIMIT 50", ['%$query%', '%$query%']);
  }

  static Future<List<String>> getCountries() async {
    final db = await citiesDatabase;
    final result = await db.rawQuery('SELECT DISTINCT country FROM cities ORDER BY country ASC');
    return result.map((e) => e['country'].toString()).toList();
  }

  static Future<List<Map<String, dynamic>>> getCitiesByCountry(String country) async {
    final db = await citiesDatabase;
    return await db.rawQuery('SELECT city, lat, lng FROM cities WHERE country = ? ORDER BY city ASC', [country]);
  }

  static Future<Map<String, dynamic>?> getNearestCity(double lat, double lng) async {
    final db = await citiesDatabase;
    try {
      final result = await db.rawQuery('''
        SELECT city, country, lat, lng, 
        (ABS(lat - ?) + ABS(lng - ?)) as difference 
        FROM cities ORDER BY difference ASC LIMIT 1
      ''', [lat, lng]);
      if (result.isNotEmpty) return result.first;
      return null;
    } catch (_) {
      return null;
    }
  }

  // --------------------------------------------------------
  // 9. CALENDAR EVENTS QUERIES
  // --------------------------------------------------------

  static Future<List<Map<String, dynamic>>> getAllCalendarEvents() async {
    final db = await calendarDatabase;
    return await db.query('calendar_events');
  }

  // --------------------------------------------------------
  // 10. GLOBAL SEARCH FUNCTIONS
  // --------------------------------------------------------

  static Future<List<Map<String, dynamic>>> searchEntireQuran() async {
    final db = await quranDatabase;
    return await db.query('Quran', orderBy: 'ID ASC');
  }

  static Future<List<Map<String, dynamic>>> searchEntireSahifa() async {
    final db = await sahifaDatabase;
    return await db.rawQuery('SELECT Parags.*, Sections.title as section_title, Sections.ID as section_row_id FROM Parags INNER JOIN Sections ON Parags.Secid = Sections.Secid ORDER BY Parags.ID ASC');
  }

  static Future<List<Map<String, dynamic>>> searchEntireNahjul() async {
    final db = await nahjulDatabase;
    return await db.rawQuery('SELECT Parags.*, Sections.title as section_title, Sections.ID as section_row_id FROM Parags INNER JOIN Sections ON Parags.Secid = Sections.Secid ORDER BY Parags.ID ASC');
  }

  static Future<List<Map<String, dynamic>>> searchEntireZiyarat() async {
    final db = await ziyaratDatabase;
    return await db.rawQuery('SELECT Parags.*, Sections.title as section_title, Sections.ID as section_row_id FROM Parags INNER JOIN Sections ON Parags.Secid = Sections.Secid ORDER BY Parags.ID ASC');
  }

  static Future<List<Map<String, dynamic>>> searchEntireAhadith() async {
    final db = await ahadithDatabase;
    return await db.rawQuery('SELECT orison.*, numorison.title as category_title FROM orison INNER JOIN numorison ON orison.numorison_id = numorison.id ORDER BY orison.id ASC');
  }

  // --------------------------------------------------------
  // 11. GLOBAL SEARCH — LIKE queries
  //
  //  Why not compute() here?  sqflite uses a Flutter method channel
  //  under the hood, which only works on the main Dart isolate.
  //  Calling these from a spawned Isolate/compute() will throw.
  //  Instead: schedule all five in parallel with Future.wait().
  //  sqflite queues each on its own native background thread and
  //  suspends the main isolate (not the UI thread) until done,
  //  keeping the render loop completely unblocked.
  //
  //  LIMIT caps keep result-set deserialization on the main isolate
  //  negligible (50-150 maps vs 6 000+).
  // --------------------------------------------------------

  // Column names for Quran vary between quran.db and quran2.db.
  // The method tries the most common name first and falls back silently.
  static Future<List<Map<String, dynamic>>> searchQuranLike(
    String term, {
    bool arabicMode = false,
    int limit = 150,
  }) async {
    final db = await quranDatabase;
    final like = '%$term%';
    final primaryCol = arabicMode ? 'arabic' : 'sindhi';
    final fallbackCol = arabicMode ? 'ayahtext' : 'tarjuma';
    try {
      return await db.rawQuery(
        'SELECT * FROM Quran WHERE "$primaryCol" LIKE ? ORDER BY ID ASC LIMIT ?',
        [like, limit],
      );
    } catch (_) {
      try {
        return await db.rawQuery(
          'SELECT * FROM Quran WHERE "$fallbackCol" LIKE ? ORDER BY ID ASC LIMIT ?',
          [like, limit],
        );
      } catch (_) {
        return [];
      }
    }
  }

  static Future<List<Map<String, dynamic>>> searchSahifaLike(
    String term, {
    bool arabicMode = false,
    int limit = 100,
  }) async {
    final db = await sahifaDatabase;
    final col = arabicMode ? 'txt' : 'mean';
    return db.rawQuery('''
      SELECT Parags.*, Sections.title AS section_title, Sections.ID AS section_row_id
      FROM Parags
      INNER JOIN Sections ON Parags.Secid = Sections.Secid
      WHERE Parags.$col LIKE ?
      ORDER BY Parags.ID ASC LIMIT ?
    ''', ['%$term%', limit]);
  }

  static Future<List<Map<String, dynamic>>> searchNahjulLike(
    String term, {
    bool arabicMode = false,
    int limit = 100,
  }) async {
    final db = await nahjulDatabase;
    final col = arabicMode ? 'txt' : 'mean';
    return db.rawQuery('''
      SELECT Parags.*, Sections.title AS section_title, Sections.ID AS section_row_id
      FROM Parags
      INNER JOIN Sections ON Parags.Secid = Sections.Secid
      WHERE Parags.$col LIKE ?
      ORDER BY Parags.ID ASC LIMIT ?
    ''', ['%$term%', limit]);
  }

  static Future<List<Map<String, dynamic>>> searchZiyaratLike(
    String term, {
    bool arabicMode = false,
    int limit = 100,
  }) async {
    final db = await ziyaratDatabase;
    final col = arabicMode ? 'txt' : 'mean';
    return db.rawQuery('''
      SELECT Parags.*, Sections.title AS section_title, Sections.ID AS section_row_id
      FROM Parags
      INNER JOIN Sections ON Parags.Secid = Sections.Secid
      WHERE Parags.$col LIKE ?
      ORDER BY Parags.ID ASC LIMIT ?
    ''', ['%$term%', limit]);
  }

  static Future<List<Map<String, dynamic>>> searchAhadithLike(
    String term, {
    bool arabicMode = false,
    int limit = 100,
  }) async {
    final db = await ahadithDatabase;
    final col = arabicMode ? 'contentar' : 'contentur';
    return db.rawQuery('''
      SELECT orison.*, numorison.title AS category_title
      FROM orison
      INNER JOIN numorison ON orison.numorison_id = numorison.id
      WHERE orison.$col LIKE ?
      ORDER BY orison.id ASC LIMIT ?
    ''', ['%$term%', limit]);
  }

  // --------------------------------------------------------
  // 12. BOOKMARK CRUD
  // --------------------------------------------------------

  // Returns all bookmarks newest-first, mapped to the same key names the rest
  // of the app already expects (bookType, uniqueId, …).
  static Future<List<Map<String, dynamic>>> getAllBookmarks() async {
    final db = await bookmarksDatabase;
    final rows = await db.query('bookmarks', orderBy: 'id DESC');
    return rows.map((r) => {
      'bookType': r['book_type'],
      'uniqueId': r['unique_id'],
      'title': r['title'],
      'arabic': r['arabic'],
      'translation': r['translation'],
      'nickname': r['nickname'],
      'note': r['note'],
      'translationIndex': r['translation_index'],
      'timestamp': r['timestamp'],
    }).toList();
  }

  static Future<void> insertBookmark(Map<String, dynamic> b) async {
    final db = await bookmarksDatabase;
    await db.insert(
      'bookmarks',
      {
        'book_type': b['bookType'],
        'unique_id': b['uniqueId'],
        'title': b['title'] ?? '',
        'arabic': b['arabic'] ?? '',
        'translation': b['translation'] ?? '',
        'nickname': b['nickname'] ?? '',
        'note': b['note'] ?? '',
        'translation_index': b['translationIndex'] ?? 0,
        'timestamp': b['timestamp'] ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteBookmark(String bookType, String uniqueId) async {
    final db = await bookmarksDatabase;
    await db.delete(
      'bookmarks',
      where: 'book_type = ? AND unique_id = ?',
      whereArgs: [bookType, uniqueId],
    );
  }

  static Future<void> updateBookmarkNote(
      String bookType, String uniqueId, String nickname, String note) async {
    final db = await bookmarksDatabase;
    await db.update(
      'bookmarks',
      {'nickname': nickname, 'note': note},
      where: 'book_type = ? AND unique_id = ?',
      whereArgs: [bookType, uniqueId],
    );
  }

  static Future<void> clearAllBookmarks() async {
    final db = await bookmarksDatabase;
    await db.delete('bookmarks');
  }
}