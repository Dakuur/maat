import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/member.dart';

/// Reusable member avatar — shows profile picture with an initials fallback.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.size = 48});

  final Member member;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 2),
      child: member.profilePicture != null
          ? CachedNetworkImage(
              imageUrl: member.profilePicture!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _Initials(member: member, size: size),
              errorWidget: (_, __, ___) =>
                  _Initials(member: member, size: size),
            )
          : _Initials(member: member, size: size),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.member, required this.size});

  final Member member;
  final double size;

  static const _palette = [
    Color(0xFFE87D3E),
    Color(0xFF30A046),
    Color(0xFF0066CC),
    Color(0xFFD70015),
    Color(0xFF4B44C8),
  ];

  Color get _color => _palette[member.id.hashCode.abs() % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: _color,
      alignment: Alignment.center,
      child: Text(
        member.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
