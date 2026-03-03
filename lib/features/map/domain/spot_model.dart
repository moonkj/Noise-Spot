import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/map_constants.dart';

enum StickerType {
  // 포커스 & 생산성
  study, work, studyZone, nomad,
  // 소셜
  meeting, vibe, date, gathering,
  // 가족 & 라이프
  family, relax, healing, cozy,
  // 감성 스타일
  insta, retro, minimal, green,
  // 기타 분위기
  peak, music,
}

extension StickerTypeX on StickerType {
  String get key => switch (this) {
        StickerType.study     => 'STUDY',
        StickerType.meeting   => 'MEETING',
        StickerType.relax     => 'RELAX',
        StickerType.vibe      => 'VIBE',
        StickerType.healing   => 'HEALING',
        StickerType.work      => 'WORK',
        StickerType.studyZone => 'STUDY_ZONE',
        StickerType.nomad     => 'NOMAD',
        StickerType.date      => 'DATE',
        StickerType.gathering => 'GATHERING',
        StickerType.family    => 'FAMILY',
        StickerType.cozy      => 'COZY',
        StickerType.insta     => 'INSTA',
        StickerType.retro     => 'RETRO',
        StickerType.minimal   => 'MINIMAL',
        StickerType.green     => 'GREEN',
        StickerType.peak      => 'PEAK',
        StickerType.music     => 'MUSIC',
      };

  String get label => switch (this) {
        StickerType.study     => '딥 포커스',
        StickerType.meeting   => '소셜 버즈',
        StickerType.relax     => '소프트 바이브',
        StickerType.vibe      => '활기찬 에너지',
        StickerType.healing   => '힐링 감성',
        StickerType.work      => '재택 성지',
        StickerType.studyZone => '조용한 스터디존',
        StickerType.nomad     => '디지털 노마드',
        StickerType.date      => '데이트 감성',
        StickerType.gathering => '동호회·모임',
        StickerType.family    => '가족·아이 동반',
        StickerType.cozy      => '코지 감성',
        StickerType.insta     => '인스타 감성',
        StickerType.retro     => '레트로 감성',
        StickerType.minimal   => '미니멀 감성',
        StickerType.green     => '식물 천국',
        StickerType.peak      => '피크타임',
        StickerType.music     => '음악 취향 저격',
      };

  /// 필터칩 표시용 (label과 동일)
  String get filterLabel => label;

  String get emoji => switch (this) {
        StickerType.study     => '🎧',
        StickerType.meeting   => '💬',
        StickerType.relax     => '☕',
        StickerType.vibe      => '⚡',
        StickerType.healing   => '🌿',
        StickerType.work      => '💻',
        StickerType.studyZone => '📖',
        StickerType.nomad     => '🌐',
        StickerType.date      => '💕',
        StickerType.gathering => '🙌',
        StickerType.family    => '🧸',
        StickerType.cozy      => '🛋️',
        StickerType.insta     => '📸',
        StickerType.retro     => '🎞️',
        StickerType.minimal   => '🤍',
        StickerType.green     => '🪴',
        StickerType.peak      => '🔥',
        StickerType.music     => '🎵',
      };

  static StickerType fromKey(String key) => switch (key.toUpperCase()) {
        'STUDY'      => StickerType.study,
        'MEETING'    => StickerType.meeting,
        'RELAX'      => StickerType.relax,
        'VIBE'       => StickerType.vibe,
        'HEALING'    => StickerType.healing,
        'WORK'       => StickerType.work,
        'STUDY_ZONE' => StickerType.studyZone,
        'NOMAD'      => StickerType.nomad,
        'DATE'       => StickerType.date,
        'GATHERING'  => StickerType.gathering,
        'FAMILY'     => StickerType.family,
        'COZY'       => StickerType.cozy,
        'INSTA'      => StickerType.insta,
        'RETRO'      => StickerType.retro,
        'MINIMAL'    => StickerType.minimal,
        'GREEN'      => StickerType.green,
        'PEAK'       => StickerType.peak,
        'MUSIC'      => StickerType.music,
        _ => StickerType.relax,
      };
}

class SpotModel {
  final String id;
  final String name;
  final String? googlePlaceId;
  final String? formattedAddress;
  final double lat;
  final double lng;
  final double averageDb;
  final StickerType? representativeSticker;
  final int reportCount;
  final double trustScore;
  final int recent24hCount;
  final DateTime? lastReportAt;
  final String? photoUrl;

  const SpotModel({
    required this.id,
    required this.name,
    this.googlePlaceId,
    this.formattedAddress,
    required this.lat,
    required this.lng,
    required this.averageDb,
    this.representativeSticker,
    required this.reportCount,
    required this.trustScore,
    required this.recent24hCount,
    this.lastReportAt,
    this.photoUrl,
  });

  factory SpotModel.fromJson(Map<String, dynamic> json) {
    return SpotModel(
      id: json['id'] as String,
      name: json['name'] as String,
      googlePlaceId: json['google_place_id'] as String?,
      formattedAddress: json['formatted_address'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      averageDb: (json['average_db'] as num).toDouble(),
      representativeSticker: json['representative_sticker'] != null
          ? StickerTypeX.fromKey(json['representative_sticker'] as String)
          : null,
      reportCount: (json['report_count'] as num).toInt(),
      trustScore: (json['trust_score'] as num).toDouble(),
      recent24hCount: (json['recent_24h_count'] as num? ?? 0).toInt(),
      lastReportAt: json['last_report_at'] != null
          ? DateTime.parse(json['last_report_at'] as String)
          : null,
      photoUrl: json['photo_url'] as String?,
    );
  }

  /// True if the spot has not been reported for [MapConstants.spotFadeAfterDays] days.
  bool get isStale {
    if (lastReportAt == null) return true;
    return DateTime.now().difference(lastReportAt!).inDays >=
        MapConstants.spotFadeAfterDays;
  }

  /// Opacity: 1.0 for active spots, 0.4 for stale ones.
  double get markerOpacity => isStale ? 0.4 : 1.0;

  Color get markerColor => AppColors.dbColor(averageDb);

  /// Border width based on trust score (gamification)
  double get markerBorderWidth => switch (trustScore) {
        >= 3 => 3.5,
        >= 2 => 2.5,
        >= 1 => 1.5,
        _ => 0.5,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpotModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
