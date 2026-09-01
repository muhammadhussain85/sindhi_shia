import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

class QuranAudioController extends GetxController {
  final AudioPlayer _player = AudioPlayer();
  final Dio _dio = Dio();
  CancelToken? _cancelToken;
  AudioSession? _audioSession;
  bool _pausedByInterruption = false;

  // Playback State
  var isPlaying = false.obs;
  var isLoading = false.obs;
  var currentPlayingVerse = 0.obs;
  var currentPlayingSurah = 0.obs;

  // Continuous Play State
  var isContinuousPlay = false.obs;
  int totalVerses = 0;

  // Offline Download State
  var isDownloading = false.obs;
  var downloadProgress = 0.0.obs;
  var downloadingSurahId = 0.obs;
  var isSurahDownloaded = false.obs;
  var currentViewingSurah = 0.obs;

  @override
  void onInit() {
    super.onInit();
    _initAudioSession();
    _player.playerStateStream.listen((state) {
      isPlaying.value = state.playing;
      isLoading.value = state.processingState == ProcessingState.buffering ||
          state.processingState == ProcessingState.loading;

      if (state.processingState == ProcessingState.completed) {
        if (isContinuousPlay.value && currentPlayingVerse.value < totalVerses) {
          int nextVerse = currentPlayingVerse.value + 1;
          playAyah(currentViewingSurah.value, nextVerse, isAutoNext: true);
        } else {
          isPlaying.value = false;
          currentPlayingVerse.value = 0;
          currentPlayingSurah.value = 0;
          isContinuousPlay.value = false;
          _player.stop();
        }
      }
    });
  }

  Future<void> _initAudioSession() async {
    _audioSession = await AudioSession.instance;
    await _audioSession!.configure(const AudioSessionConfiguration.music());
    // Pause when another app takes audio focus (adhan alarm, phone call, etc.)
    _audioSession!.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (_player.playing) {
          _player.pause();
          _pausedByInterruption = true;
        }
      } else if (_pausedByInterruption) {
        _pausedByInterruption = false;
        _player.play();
      }
    });
    // Pause when headphones are unplugged
    _audioSession!.becomingNoisyEventStream.listen((_) {
      _player.pause();
    });
  }

  Future<void> playFullSurah(int surahNumber, int totalAyahs) async {
    isContinuousPlay.value = true;
    totalVerses = totalAyahs;
    currentViewingSurah.value = surahNumber;
    await playAyah(surahNumber, 1, isAutoNext: true);
  }

  Future<void> playAyah(int surahNumber, int verseNumber, {bool isAutoNext = false}) async {
    try {
      if (!isAutoNext) {
        isContinuousPlay.value = false;
      }

      if (currentPlayingSurah.value == surahNumber && currentPlayingVerse.value == verseNumber && isPlaying.value) {
        await _player.pause();
        return;
      }
      if (currentPlayingSurah.value == surahNumber && currentPlayingVerse.value == verseNumber && !isPlaying.value) {
        await _player.play();
        return;
      }

      currentPlayingSurah.value = surahNumber;
      currentPlayingVerse.value = verseNumber;
      isLoading.value = true;

      String surahStr = surahNumber.toString().padLeft(3, '0');
      String verseStr = verseNumber.toString().padLeft(3, '0');

      final dir = await getApplicationDocumentsDirectory();
      String localPath = '${dir.path}/quran_audio/$surahStr/$surahStr$verseStr.mp3';
      File localFile = File(localPath);

      if (await localFile.exists()) {
        await _player.setFilePath(localPath);
      } else {
        String url = "https://everyayah.com/data/Alafasy_128kbps/$surahStr$verseStr.mp3";
        await _player.setUrl(url);
      }

      await _audioSession?.setActive(true);
      await _player.play();

    } catch (e) {
      debugPrint("Audio Stream Error: $e");
      isLoading.value = false;
      currentPlayingVerse.value = 0;
      currentPlayingSurah.value = 0;
    }
  }

  Future<void> pauseAudio() async => await _player.pause();
  Future<void> resumeAudio() async => await _player.play();

  Future<void> stopAudio() async {
    await _player.stop();
    currentPlayingVerse.value = 0;
    currentPlayingSurah.value = 0;
    isPlaying.value = false;
    isContinuousPlay.value = false;
    _pausedByInterruption = false;
    await _audioSession?.setActive(false);
  }

  // ----------------------------------------------------------------
  // OFFLINE DOWNLOAD MANAGEMENT
  // ----------------------------------------------------------------

  void cancelDownload() {
    if (isDownloading.value) {
      _cancelToken?.cancel("User cancelled");
      isDownloading.value = false;
      downloadingSurahId.value = 0;
      Fluttertoast.showToast(msg: "ڊائونلوڊ روڪي وئي", backgroundColor: Colors.orange);
    }
  }

  Future<void> checkDownloadStatus(int surahNumber, int totalAyahs) async {
    currentViewingSurah.value = surahNumber;
    final dir = await getApplicationDocumentsDirectory();
    String surahStr = surahNumber.toString().padLeft(3, '0');
    final surahDir = Directory('${dir.path}/quran_audio/$surahStr');

    if (await surahDir.exists()) {
      final files = surahDir.listSync();
      if (files.length >= totalAyahs) {
        isSurahDownloaded.value = true;
        return;
      }
    }
    isSurahDownloaded.value = false;
  }

  // ✨ FIX: Accepts "totalAyahs" directly so we don't have to wait for the database!
  Future<void> downloadFullSurah(int surahNumber, int totalAyahs) async {
    if (isDownloading.value && downloadingSurahId.value == surahNumber) {
      cancelDownload();
      return;
    }

    // ✨ INSTANT UI UPDATE: Variables set to true instantly, bypassing any async lag
    isDownloading.value = true;
    downloadingSurahId.value = surahNumber;
    downloadProgress.value = 0.0;
    _cancelToken = CancelToken();

    try {
      final dir = await getApplicationDocumentsDirectory();
      String surahStr = surahNumber.toString().padLeft(3, '0');
      final surahDir = Directory('${dir.path}/quran_audio/$surahStr');

      if (!await surahDir.exists()) {
        await surahDir.create(recursive: true);
      }

      for (int i = 1; i <= totalAyahs; i++) {
        if (_cancelToken?.isCancelled ?? false) break;

        String verseStr = i.toString().padLeft(3, '0');
        String url = "https://everyayah.com/data/Alafasy_128kbps/$surahStr$verseStr.mp3";
        String savePath = '${surahDir.path}/$surahStr$verseStr.mp3';

        if (!File(savePath).existsSync()) {
          await _dio.download(url, savePath, cancelToken: _cancelToken);
        }
        // Smooth fast progress bar
        downloadProgress.value = i / totalAyahs;
      }

      if (!(_cancelToken?.isCancelled ?? false)) {
        isSurahDownloaded.value = true;
        Fluttertoast.showToast(msg: "سورة مڪمل ڊائونلوڊ ٿي وئي", backgroundColor: Colors.green);
      }

    } catch (e) {
      if (e is! DioException || !CancelToken.isCancel(e)) {
        Fluttertoast.showToast(msg: "ڊائونلوڊ ڪرڻ ۾ مسئلو آيو: ڪنيڪشن چيڪ ڪريو", backgroundColor: Colors.redAccent);
      }
    } finally {
      isDownloading.value = false;
      downloadingSurahId.value = 0;
      _cancelToken = null;
    }
  }

  Future<void> deleteSurah(int surahNumber) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String surahStr = surahNumber.toString().padLeft(3, '0');
      final surahDir = Directory('${dir.path}/quran_audio/$surahStr');

      if (await surahDir.exists()) {
        await surahDir.delete(recursive: true);
        isSurahDownloaded.value = false;
        Fluttertoast.showToast(msg: "آڊيو ڊليٽ ڪئي وئي", backgroundColor: Colors.black87);
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  @override
  void onClose() {
    _player.dispose();
    _dio.close();
    super.onClose();
  }
}