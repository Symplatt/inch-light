const academicDegrees = ['硕士生', '博士生', '直博', '硕博连读', '其他'];
const peerGenders = ['男', '女'];

class AcademicProfile {
  const AcademicProfile({required this.year, required this.degree});
  final int? year;
  final String degree;

  // Use a three-year master's stage for post-master's doctoral entrants.
  // Direct doctorates and combined programs use their original admission year.
  int? get seniorityYear =>
      year == null ? null : year! - (degree == '博士生' ? 3 : 0);

  Map<String, dynamic> toJson() => {'year': year, 'degree': degree};

  factory AcademicProfile.fromJson(Map<String, dynamic> json) {
    final profile = AcademicProfile(
      year: json['year'] as int?,
      degree: json['degree'] as String,
    );
    if ((profile.year != null &&
            (profile.year! < 1000 || profile.year! > 9999)) ||
        !academicDegrees.contains(profile.degree)) {
      throw const FormatException('Invalid academic profile');
    }
    return profile;
  }
}

class AcademicPeer {
  const AcademicPeer({
    required this.id,
    required this.name,
    required this.gender,
    required this.profile,
    this.manualRelation,
    this.note = '',
  });
  final String id;
  final String name;
  final String gender;
  final AcademicProfile profile;
  final String? manualRelation;
  final String note;

  // Explicit relationships take priority over the inferred admission cohort.
  String? relationTo(AcademicProfile? me) {
    if (manualRelation?.trim().isNotEmpty == true) return manualRelation;
    final mine = me?.seniorityYear;
    final theirs = profile.seniorityYear;
    if (mine == null || theirs == null) return null;
    if (theirs == mine) return '同届';
    if (theirs < mine) return gender == '男' ? '师兄' : '师姐';
    return gender == '男' ? '师弟' : '师妹';
  }

  int seniorityGroup(AcademicProfile? me) => switch (relationTo(me)) {
    '师兄' || '师姐' => 0,
    '同届' || '同级' || '平辈' => 1,
    '师弟' || '师妹' => 2,
    _ => 3,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gender': gender,
    ...profile.toJson(),
    'manualRelation': manualRelation,
    'note': note,
  };

  factory AcademicPeer.fromJson(Map<String, dynamic> json) {
    final peer = AcademicPeer(
      id: json['id'] as String,
      name: json['name'] as String,
      gender: json['gender'] as String,
      profile: AcademicProfile.fromJson(json),
      manualRelation: json['manualRelation'] as String?,
      note: json['note'] as String? ?? '',
    );
    if (peer.id.isEmpty ||
        peer.name.trim().isEmpty ||
        !peerGenders.contains(peer.gender)) {
      throw const FormatException('Invalid academic peer');
    }
    return peer;
  }
}

class AcademicPeersData {
  AcademicPeersData({this.me, List<AcademicPeer> peers = const []})
    : peers = List.unmodifiable(peers);
  final AcademicProfile? me;
  final List<AcademicPeer> peers;

  Map<String, dynamic> toJson() => {
    'me': me?.toJson(),
    'peers': peers.map((p) => p.toJson()).toList(),
  };

  factory AcademicPeersData.fromJson(Map<String, dynamic> json) {
    final peers = (json['peers'] as List)
        .map((p) => AcademicPeer.fromJson(Map<String, dynamic>.from(p)))
        .toList();
    if (peers.map((p) => p.id).toSet().length != peers.length) {
      throw const FormatException('Duplicate academic peer');
    }
    return AcademicPeersData(
      me: json['me'] == null
          ? null
          : AcademicProfile.fromJson(Map<String, dynamic>.from(json['me'])),
      peers: peers,
    );
  }
}
