import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../models/academic_peers.dart';
import '../providers/app_provider.dart';
import '../utils/journal_sort.dart';
import '../widgets/swipe_delete_card.dart';
import '../widgets/tool_edit_dialog.dart';

class AcademicPeersPage extends StatefulWidget {
  const AcademicPeersPage({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  State<AcademicPeersPage> createState() => _AcademicPeersPageState();
}

class _AcademicPeersPageState extends State<AcademicPeersPage> {
  Future<void> _editProfile() => showDialog<void>(
    context: context,
    builder: (_) =>
        _AcademicDialog(provider: context.read<AppProvider>(), isMe: true),
  );

  Future<void> _editPeer([AcademicPeer? peer]) async {
    final provider = context.read<AppProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) => _AcademicDialog(provider: provider, peer: peer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final data = provider.academicPeers;
    final peers = [...data.peers]
      ..sort((a, b) {
        final group = a
            .seniorityGroup(data.me)
            .compareTo(b.seniorityGroup(data.me));
        if (group != 0) return group;
        final aYear = a.profile.year;
        final bYear = b.profile.year;
        if (aYear == null && bYear != null) return -1;
        if (aYear != null && bYear == null) return 1;
        final yearOrder = (aYear ?? 0).compareTo(bYear ?? 0);
        return yearOrder != 0
            ? yearOrder
            : JournalNameKey(a.name).compareTo(JournalNameKey(b.name));
      });
    final nameStyle = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(fontSize: 16);
    final namePainter = TextPainter(
      text: TextSpan(text: '一二三四五', style: nameStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final nameWidth = namePainter.width;
    namePainter.dispose();
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: widget.onBack),
        title: const Text(
          '我的同门',
          style: TextStyle(fontWeight: FontWeight.w400),
        ),
        actions: [
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: '我的资料',
              onPressed: _editProfile,
              icon: const Icon(Icons.person_outline),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              tooltip: '新增同门',
              onPressed: _editPeer,
              icon: const Icon(Icons.add),
            ),
          ),
          SizedBox(
            width:
                8 +
                (MediaQuery.sizeOf(context).width - 720).clamp(
                      0.0,
                      double.infinity,
                    ) /
                    2,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: peers.isEmpty
              ? const Center(
                  child: Text(
                    '暂无同门',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: peers.length,
                  itemBuilder: (context, index) {
                    final peer = peers[index];
                    return SwipeDeleteCard(
                      key: ValueKey(peer.id),
                      id: peer.id,
                      bottomMargin: 8,
                      onDeleted: () => provider.updateAcademicPeers(
                        (d) => AcademicPeersData(
                          me: d.me,
                          peers: d.peers.where((p) => p.id != peer.id).toList(),
                        ),
                      ),
                      child: Material(
                        color: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE7E8EB)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _editPeer(peer),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    SizedBox(
                                      width: nameWidth,
                                      child: Text(
                                        peer.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: nameStyle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        [
                                          peer.gender == '男' ? '♂' : '♀',
                                          peer.profile.year == null
                                              ? '年份未知'
                                              : '${peer.profile.year}级',
                                          peer.profile.degree,
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 88,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F1F3),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Text(
                                          peer.relationTo(data.me) ?? '待填写',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _AcademicDialog extends StatefulWidget {
  const _AcademicDialog({required this.provider, this.isMe = false, this.peer});
  final AppProvider provider;
  final bool isMe;
  final AcademicPeer? peer;
  @override
  State<_AcademicDialog> createState() => _AcademicDialogState();
}

class _AcademicDialogState extends State<_AcademicDialog> {
  late final _profile = widget.isMe
      ? widget.provider.academicPeers.me
      : widget.peer?.profile;
  late final _name = TextEditingController(text: widget.peer?.name);
  late final _year = TextEditingController(text: _profile?.year?.toString());
  late final _note = TextEditingController(text: widget.peer?.note);
  late String _gender = widget.peer?.gender ?? '男';
  late String? _degree = _profile?.degree;
  late bool _manual = widget.peer?.manualRelation != null;
  late final _relation = TextEditingController(
    text: widget.peer?.relationTo(widget.provider.academicPeers.me),
  );

  void _calculate() {
    if (_manual) return;
    final peer = AcademicPeer(
      id: '',
      name: '',
      gender: _gender,
      profile: AcademicProfile(
        year: int.tryParse(_year.text),
        degree: _degree ?? '其他',
      ),
    );
    _relation.text = peer.relationTo(widget.provider.academicPeers.me) ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _note.dispose();
    _relation.dispose();
    super.dispose();
  }

  InputDecoration _field(String hint) => toolInputDecoration(hint);

  @override
  Widget build(BuildContext context) => ToolEditDialog(
    title: widget.isMe
        ? '我的资料'
        : widget.peer == null
        ? '新增同门'
        : '编辑同门',
    fields: (enabled) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.isMe) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _name,
                  enabled: enabled,
                  decoration: _field('姓名'),
                  validator: requiredToolText,
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: _gender == '男' ? '男' : '女',
                toggled: _gender == '女',
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: !enabled
                      ? null
                      : () => setState(() {
                          _gender = _gender == '男' ? '女' : '男';
                          _calculate();
                        }),
                  child: Container(
                    width: 88,
                    height: 48,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EAED),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: _gender == '男'
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _gender == '男' ? Icons.male : Icons.female,
                          size: 24,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _year,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: (_) => _calculate(),
                decoration: _field('入学年份'),
                validator: (value) =>
                    value != null &&
                        value.isNotEmpty &&
                        (int.tryParse(value) ?? 0) < 1000
                    ? '请输入四位年份'
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _degree,
                isExpanded: true,
                decoration: _field('类型'),
                hint: const Text('类型'),
                items: [
                  for (final degree in academicDegrees)
                    DropdownMenuItem(value: degree, child: Text(degree)),
                ],
                onChanged: enabled ? (value) => _degree = value : null,
                validator: requiredToolText,
              ),
            ),
          ],
        ),
        if (!widget.isMe) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _relation,
            enabled: enabled,
            onChanged: (value) => _manual = value.trim().isNotEmpty,
            decoration: _field('辈分'),
            validator: requiredToolText,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            enabled: enabled,
            minLines: 2,
            maxLines: 4,
            decoration: _field('备注'),
          ),
        ],
      ],
    ),
    save: () => widget.provider.updateAcademicPeers((data) {
      final profile = AcademicProfile(
        year: int.tryParse(_year.text),
        degree: _degree!,
      );
      if (widget.isMe) return AcademicPeersData(me: profile, peers: data.peers);
      final peer = AcademicPeer(
        id: widget.peer?.id ?? const Uuid().v4(),
        name: _name.text.trim(),
        gender: _gender,
        profile: profile,
        manualRelation: _manual ? _relation.text.trim() : null,
        note: _note.text.trim(),
      );
      final peers = [...data.peers];
      final index = peers.indexWhere((p) => p.id == peer.id);
      if (index < 0) {
        peers.add(peer);
      } else {
        peers[index] = peer;
      }
      return AcademicPeersData(me: data.me, peers: peers);
    }),
  );
}
