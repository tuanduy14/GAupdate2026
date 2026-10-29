import 'package:flutter/material.dart';

import '../am_thanh/am_thanh.dart';
import '../cau_hinh.dart';
import '../gold_rush_game.dart';

/// Bốn màn hình phủ lên trên game: Menu, Cài đặt, Tạm dừng, Kết thúc.
///
/// Điểm quan trọng về kiến trúc: đây là widget Flutter bình thường, KHÔNG phải
/// component của Flame. Flame gọi chúng là "overlay" và vẽ chúng bằng chính hệ
/// thống widget của Flutter, xếp chồng lên canvas của game.
///
/// Vì sao không vẽ menu bằng component Flame cho đồng bộ? Vì nút bấm, chữ,
/// công tắc, cuộn, hiệu ứng chạm... Flutter đã làm sẵn hết và làm rất tốt.
/// Viết lại những thứ đó bằng canvas là phí công. Quy tắc thực dụng:
/// **cái gì chuyển động trong thế giới trò chơi thì dùng Flame, cái gì là
/// giao diện tĩnh thì dùng Flutter.**

// ---------------------------------------------------------------------------
// Thành phần dùng chung
// ---------------------------------------------------------------------------
class _Khung extends StatelessWidget {
  final String tieuDe;
  final String? phuDe;
  final List<Widget> noiDung;

  const _Khung({required this.tieuDe, this.phuDe, required this.noiDung});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CauHinh.mauNenMo,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tieuDe,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: CauHinh.mauChinh,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 6),
                    ],
                  ),
                ),
                if (phuDe != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    phuDe!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: Color(0xFFC9D2DB),
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                ...noiDung,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Nut extends StatelessWidget {
  final String nhan;
  final IconData bieuTuong;
  final VoidCallback khiBam;
  final bool chinh;

  const _Nut({
    required this.nhan,
    required this.bieuTuong,
    required this.khiBam,
    this.chinh = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: chinh
            ? FilledButton.icon(
                onPressed: khiBam,
                icon: Icon(bieuTuong),
                label: Text(nhan),
                style: FilledButton.styleFrom(
                  backgroundColor: CauHinh.mauChinh,
                  foregroundColor: const Color(0xFF241A05),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: khiBam,
                icon: Icon(bieuTuong),
                label: Text(nhan),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CauHinh.mauChu,
                  side: const BorderSide(color: Color(0x66FFFFFF)),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Menu chính
// ---------------------------------------------------------------------------
class ManHinhMenu extends StatelessWidget {
  final GoldRushGame game;

  const ManHinhMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return _Khung(
      tieuDe: 'GOLD RUSH',
      phuDe: 'George đi tìm vàng giữa vùng đất đầy zombie và bộ xương.\n'
          'Nhặt hết số xu trên bản đồ trước khi hết máu.',
      noiDung: [
        _Nut(
          nhan: 'CHƠI',
          bieuTuong: Icons.play_arrow_rounded,
          chinh: true,
          khiBam: game.batDauVanMoi,
        ),
        _Nut(
          nhan: 'Cài đặt',
          bieuTuong: Icons.tune_rounded,
          khiBam: game.moCaiDat,
        ),
        const SizedBox(height: 12),
        const Text(
          'Điều khiển:  cần gạt ở góc dưới trái  ·  phím mũi tên hoặc W A S D\n'
          'chạm vào bản đồ để đi tới chỗ đó',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.6, color: Color(0xFF9FAEBC)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cài đặt
// ---------------------------------------------------------------------------
class ManHinhCaiDat extends StatefulWidget {
  final GoldRushGame game;

  const ManHinhCaiDat({super.key, required this.game});

  @override
  State<ManHinhCaiDat> createState() => _ManHinhCaiDatState();
}

class _ManHinhCaiDatState extends State<ManHinhCaiDat> {
  @override
  Widget build(BuildContext context) {
    return _Khung(
      tieuDe: 'CÀI ĐẶT',
      noiDung: [
        SwitchListTile(
          value: AmThanh.batNhac,
          onChanged: (v) {
            setState(() => AmThanh.batNhac = v);
            AmThanh.datBatNhac(v);
          },
          title: const Text('Nhạc nền', style: TextStyle(color: CauHinh.mauChu)),
          subtitle: const Text(
            'Bản nhạc lặp 8 giây, sinh bằng mã nguồn',
            style: TextStyle(color: Color(0xFF9FAEBC), fontSize: 12),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        SwitchListTile(
          value: AmThanh.batHieuUng,
          onChanged: (v) => setState(() => AmThanh.batHieuUng = v),
          title: const Text('Hiệu ứng âm thanh',
              style: TextStyle(color: CauHinh.mauChu)),
          subtitle: const Text(
            'Tiếng nhặt xu, bước chân, kẻ địch nổ',
            style: TextStyle(color: Color(0xFF9FAEBC), fontSize: 12),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        // Người chơi phải BIẾT và TẮT ĐƯỢC việc AI chỉnh độ khó.
        SwitchListTile(
          value: widget.game.doKho.batThichUng,
          onChanged: widget.game.doKho.moHinh == null
              ? null
              : (v) => setState(() => widget.game.doKho.batThichUng = v),
          title: const Text('Độ khó thích ứng (AI)',
              style: TextStyle(color: CauHinh.mauChu)),
          subtitle: Text(
            widget.game.doKho.moHinh == null
                ? 'Chưa có mô hình trong assets/models/'
                : 'Kẻ địch nhanh/chậm trong khoảng 80–115% theo phong độ của bạn',
            style: const TextStyle(color: Color(0xFF9FAEBC), fontSize: 12),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 18),
        _Nut(
          nhan: 'Quay lại',
          bieuTuong: Icons.arrow_back_rounded,
          khiBam: widget.game.dongCaiDat,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tạm dừng
// ---------------------------------------------------------------------------
class ManHinhTamDung extends StatelessWidget {
  final GoldRushGame game;

  const ManHinhTamDung({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return _Khung(
      tieuDe: 'TẠM DỪNG',
      phuDe: 'Điểm hiện tại: ${game.george?.diem ?? 0}',
      noiDung: [
        _Nut(
          nhan: 'Chơi tiếp',
          bieuTuong: Icons.play_arrow_rounded,
          chinh: true,
          khiBam: game.tiepTuc,
        ),
        _Nut(
          nhan: 'Cài đặt',
          bieuTuong: Icons.tune_rounded,
          khiBam: game.moCaiDat,
        ),
        _Nut(
          nhan: 'Về menu',
          bieuTuong: Icons.home_rounded,
          khiBam: game.veMenu,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Kết thúc ván
// ---------------------------------------------------------------------------
class ManHinhKetThuc extends StatelessWidget {
  final GoldRushGame game;

  const ManHinhKetThuc({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final thang = game.trangThai == TrangThaiChoi.thang;
    final diem = game.george?.diem ?? 0;

    return _Khung(
      tieuDe: thang ? 'THẮNG RỒI!' : 'KẾT THÚC',
      phuDe: thang
          ? 'George đã gom hết vàng và thoát ra an toàn.'
          : 'George đã gục ngã giữa đường tìm vàng.',
      noiDung: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0x33FFFFFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _Dong('Điểm ván này', '$diem'),
              const SizedBox(height: 6),
              _Dong('Xu đã nhặt', '${game.soXuDaNhat} / ${game.tongSoXu}'),
              const SizedBox(height: 6),
              _Dong('Điểm cao nhất', '${game.diemCaoNhat}'),
            ],
          ),
        ),
        _Nut(
          nhan: 'Chơi lại',
          bieuTuong: Icons.refresh_rounded,
          chinh: true,
          khiBam: game.batDauVanMoi,
        ),
        _Nut(
          nhan: 'Về menu',
          bieuTuong: Icons.home_rounded,
          khiBam: game.veMenu,
        ),
      ],
    );
  }
}

class _Dong extends StatelessWidget {
  final String nhan;
  final String giaTri;

  const _Dong(this.nhan, this.giaTri);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(nhan, style: const TextStyle(color: Color(0xFFC9D2DB), fontSize: 14)),
        Text(
          giaTri,
          style: const TextStyle(
            color: CauHinh.mauChu,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
