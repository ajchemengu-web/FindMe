/// Ported 1:1 from findme_app/lib/database.types.ts. Field names match
/// findme_backend_fastapi's Pydantic response schemas exactly.
library;

class Device {
  final String id;
  final String ownerId;
  final String nickname;
  final String deviceType;
  final String? platform; // ios | android | web | other | null
  final bool isSelfOwned;
  final num? batteryPct;
  final DateTime? lastSeenAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String visibility; // owner | precise | city | none

  Device({
    required this.id,
    required this.ownerId,
    required this.nickname,
    required this.deviceType,
    required this.platform,
    required this.isSelfOwned,
    required this.batteryPct,
    required this.lastSeenAt,
    required this.createdAt,
    required this.updatedAt,
    required this.visibility,
  });

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: j['id'] as String,
        ownerId: j['owner_id'] as String,
        nickname: j['nickname'] as String,
        deviceType: j['device_type'] as String,
        platform: j['platform'] as String?,
        isSelfOwned: j['is_self_owned'] as bool,
        batteryPct: j['battery_pct'] as num?,
        lastSeenAt: j['last_seen_at'] != null ? DateTime.parse(j['last_seen_at'] as String) : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
        visibility: j['visibility'] as String,
      );
}

class Consent {
  final String id;
  final String grantorId;
  final String granteeId;
  final String status; // pending | active | denied | revoked
  final String scope; // precise | city
  final DateTime? expiresAt;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final DateTime? revokedAt;
  final String? revokedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Consent({
    required this.id,
    required this.grantorId,
    required this.granteeId,
    required this.status,
    required this.scope,
    required this.expiresAt,
    required this.requestedAt,
    required this.respondedAt,
    required this.revokedAt,
    required this.revokedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Consent.fromJson(Map<String, dynamic> j) => Consent(
        id: j['id'] as String,
        grantorId: j['grantor_id'] as String,
        granteeId: j['grantee_id'] as String,
        status: j['status'] as String,
        scope: j['scope'] as String,
        expiresAt: j['expires_at'] != null ? DateTime.parse(j['expires_at'] as String) : null,
        requestedAt: DateTime.parse(j['requested_at'] as String),
        respondedAt: j['responded_at'] != null ? DateTime.parse(j['responded_at'] as String) : null,
        revokedAt: j['revoked_at'] != null ? DateTime.parse(j['revoked_at'] as String) : null,
        revokedBy: j['revoked_by'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

class Geofence {
  final String id;
  final String deviceId;
  final String createdBy;
  final String name;
  final double lon;
  final double lat;
  final double radiusM;
  final bool active;
  final DateTime createdAt;

  Geofence({
    required this.id,
    required this.deviceId,
    required this.createdBy,
    required this.name,
    required this.lon,
    required this.lat,
    required this.radiusM,
    required this.active,
    required this.createdAt,
  });

  factory Geofence.fromJson(Map<String, dynamic> j) => Geofence(
        id: j['id'] as String,
        deviceId: j['device_id'] as String,
        createdBy: j['created_by'] as String,
        name: j['name'] as String,
        lon: (j['lon'] as num).toDouble(),
        lat: (j['lat'] as num).toDouble(),
        radiusM: (j['radius_m'] as num).toDouble(),
        active: j['active'] as bool,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ThreatZoneGeo {
  final String id;
  final String category; // conflict | unrest | disaster
  final String severity; // warning | serious | critical
  final String title;
  final String? summary;
  final String source;
  final double lon;
  final double lat;
  final double? radiusKm;
  final DateTime? eventDate;

  ThreatZoneGeo({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.summary,
    required this.source,
    required this.lon,
    required this.lat,
    required this.radiusKm,
    required this.eventDate,
  });

  factory ThreatZoneGeo.fromJson(Map<String, dynamic> j) => ThreatZoneGeo(
        id: j['id'] as String,
        category: j['category'] as String,
        severity: j['severity'] as String,
        title: j['title'] as String,
        summary: j['summary'] as String?,
        source: j['source'] as String,
        lon: (j['lon'] as num).toDouble(),
        lat: (j['lat'] as num).toDouble(),
        radiusKm: (j['radius_km'] as num?)?.toDouble(),
        eventDate: j['event_date'] != null ? DateTime.parse(j['event_date'] as String) : null,
      );
}

class VisibleDeviceLocation {
  final String deviceId;
  final String nickname;
  final double lon;
  final double lat;
  final DateTime recordedAt;
  final String precisionLevel; // owner | precise | city

  VisibleDeviceLocation({
    required this.deviceId,
    required this.nickname,
    required this.lon,
    required this.lat,
    required this.recordedAt,
    required this.precisionLevel,
  });

  factory VisibleDeviceLocation.fromJson(Map<String, dynamic> j) => VisibleDeviceLocation(
        deviceId: j['device_id'] as String,
        nickname: j['nickname'] as String,
        lon: (j['lon'] as num).toDouble(),
        lat: (j['lat'] as num).toDouble(),
        recordedAt: DateTime.parse(j['recorded_at'] as String),
        precisionLevel: j['precision_level'] as String,
      );
}

class NewsItem {
  final String id;
  final String source;
  final String category; // politics | business | markets | security
  final String headline;
  final String? summary;
  final String? url;
  final num? sentiment;
  final DateTime publishedAt;

  NewsItem({
    required this.id,
    required this.source,
    required this.category,
    required this.headline,
    required this.summary,
    required this.url,
    required this.sentiment,
    required this.publishedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> j) => NewsItem(
        id: j['id'] as String,
        source: j['source'] as String,
        category: j['category'] as String,
        headline: j['headline'] as String,
        summary: j['summary'] as String?,
        url: j['url'] as String?,
        sentiment: j['sentiment'] as num?,
        publishedAt: DateTime.parse(j['published_at'] as String),
      );
}

class Alert {
  final String id;
  final String ownerId;
  final String severity; // good | warning | critical
  final String category;
  final String message;
  final String? relatedDeviceId;
  final String? relatedThreatId;
  final bool read;
  final DateTime createdAt;

  Alert({
    required this.id,
    required this.ownerId,
    required this.severity,
    required this.category,
    required this.message,
    required this.relatedDeviceId,
    required this.relatedThreatId,
    required this.read,
    required this.createdAt,
  });

  factory Alert.fromJson(Map<String, dynamic> j) => Alert(
        id: j['id'] as String,
        ownerId: j['owner_id'] as String,
        severity: j['severity'] as String,
        category: j['category'] as String,
        message: j['message'] as String,
        relatedDeviceId: j['related_device_id'] as String?,
        relatedThreatId: j['related_threat_id'] as String?,
        read: j['read'] as bool,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
