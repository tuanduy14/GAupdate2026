import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'ai/dieu_chinh_do_kho.dart';
import 'ai/gui_nhat_ky.dart';
import 'ai/mo_hinh_do_kho.dart';
import 'ai/nhat_ky_choi.dart';
import 'ai/tim_duong.dart';
import 'am_thanh/am_thanh.dart';
import 'cau_hinh.dart';
import 'components/ban_do.dart';
import 'components/dong_xu.dart';
import 'components/george.dart';
import 'components/hud.dart';
import 'components/ke_dich.dart';
import 'dieu_khien/nut_tam_dung.dart';
import 'tai_nguyen.dart';
import 'the_gioi.dart';

/// Tên các lớp phủ giao diện. Dùng hằng số thay vì gõ chuỗi khắp nơi để
/// gõ sai một chữ không biến thành lỗi chạy mới phát hiện được.
class LopPhu {
  LopPhu._();
  static const menu = 'menu';
  static const caiDat = 'caiDat';
  static const tamDung = 'tamDung';
  static const ketThuc = 'ketThuc';
}

class GoldRushGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  GoldRushGame._(this.theGioi) : super(world: theGioi);

  factory GoldRushGame() => GoldRushGame._(TheGioi());

  final TheGioi theGioi;

  final TaiNguyen taiNguyen = TaiNguyen();
  late final BanDo banDo;

  // ---------- Phần AI (thư mục lib/ai/) ----------
  /// Phiên bản app ghi vào nhật ký — khớp `version` trong pubspec.yaml.
  static const String phienBanApp = '1.1.0';

  /// Tệp mô hình độ khó trong assets. Đổi phiên bản mô hình = đổi dòng này
  /// (và khai báo tệp mới trong pubspec nếu đặt ở thư mục khác).
  static const String tepMoHinhDoKho = 'assets/models/do_kho_v1.json';

  /// Bộ tìm đường A* dùng chung cho mọi kẻ địch, dựng một lần sau khi nạp bản đồ.
  late final TimDuong timDuong;

  /// Bộ điều chỉnh độ khó; tự về độ khó cố định nếu không nạp được mô hình.
  final DieuChinhDoKho doKho = DieuChinhDoKho();

  /// Nhật ký ván đang chơi: nguồn đặc trưng cho mô hình và dữ liệu gửi máy chủ.
  final NhatKyChoi nhatKy = NhatKyChoi();

  bool _vanDangDienRa = false;
  int _mauTruoc = CauHinh.mauToiDa;
  int _diemTruoc = 0;

  George? george;
  JoystickComponent? joystick;
  Hud? hud;

  TrangThaiChoi trangThai = TrangThaiChoi.tamDung;

  int tongSoXu = 0;
  int soXuDaNhat = 0;

  /// Điểm cao nhất trong phiên chạy hiện tại (không lưu xuống đĩa cho gọn;
  /// muốn lưu lâu dài thì dùng shared_preferences như đã học ở Tuần 11).
  int diemCaoNhat = 0;

  @override
  Color backgroundColor() => CauHinh.mauNen;

  // ==================================================================
  // Nạp
  // ==================================================================
  @override
  Future<void> onLoad() async {
    await taiNguyen.nap();
    await AmThanh.napTruoc();

    banDo = await BanDo.nap();
    theGioi.add(banDo.thanhPhan);

    timDuong = TimDuong(
      soCot: banDo.soCot,
      soHang: banDo.soHang,
      biChan: banDo.luoi.biChanO,
    );
    await _napMoHinhDoKho();

    theGioi.khiChamVaoBanDo = (viTri) {
      george?.viTriDich = viTri;
    };

    _capNhatZoom();

    // HUD và cần điều khiển nằm trong viewport -> không trôi theo bản đồ.
    hud = Hud(
      layMau: () => george?.mau ?? 0,
      layDiem: () => george?.diem ?? 0,
      layXuConLai: () => tongSoXu - soXuDaNhat,
    );
    camera.viewport.add(hud!);

    joystick = JoystickComponent(
      knob: SpriteComponent(
        sprite: taiNguyen.joystickNum,
        size: Vector2.all(30),
      ),
      background: SpriteComponent(
        sprite: taiNguyen.joystickNen,
        size: Vector2.all(72),
      ),
      margin: const EdgeInsets.only(left: 26, bottom: 26),
      priority: 100,
    );
    camera.viewport.add(joystick!);

    camera.viewport.add(NutTamDung(khiBam: tamDung));

    // Dựng sẵn một ván để phía sau lớp phủ menu có cảnh chứ không phải màn đen.
    _dungVan();
    _anTatCaLopPhu();
    overlays.add(LopPhu.menu);
    trangThai = TrangThaiChoi.tamDung;
    _datDieuKhien(false);
  }

  /// Nạp mô hình độ khó từ assets. Thiếu tệp hay tệp sai định dạng thì CHỈ
  /// ghi log và chơi với độ khó cố định — AI hỏng không được làm hỏng game.
  Future<void> _napMoHinhDoKho() async {
    try {
      final chuoi = await rootBundle.loadString(tepMoHinhDoKho);
      doKho.moHinh =
          MoHinhDoKho.tuJson(jsonDecode(chuoi) as Map<String, dynamic>);
      debugPrint('Đã nạp mô hình độ khó ${doKho.moHinh!.phienBan}');
    } catch (e) {
      debugPrint('Không nạp được mô hình độ khó ($e) — dùng độ khó cố định.');
    }
  }

  /// Dừng vòng lặp NGAY SAU khi nạp xong, không dừng ngay trong onLoad.
  ///
  /// onLoad chạy lúc component đang được gắn vào cây; đụng vào trạng thái
  /// chạy/dừng của cả game ngay tại đó là can thiệp vào giữa chừng một quy
  /// trình chưa kết thúc. onMount chạy sau khi mọi thứ đã yên vị.
  @override
  void onMount() {
    super.onMount();
    pauseEngine();
  }

  @override
  void onGameResize(Vector2 kichThuoc) {
    super.onGameResize(kichThuoc);
    if (isLoaded) _capNhatZoom();
  }

  /// Giữ cho người chơi luôn nhìn thấy đúng chừng ấy ô, dù màn hình to hay nhỏ.
  ///
  /// Đây là lời giải cho bài toán của Chương 8: điện thoại, trình duyệt và máy
  /// tính để bàn có độ phân giải rất khác nhau. Nếu vẽ theo pixel màn hình thì
  /// trên máy tính người chơi nhìn thấy nửa bản đồ, còn trên điện thoại thì chỉ
  /// thấy vài ô — hai trải nghiệm hoàn toàn khác nhau.
  void _capNhatZoom() {
    if (size.x <= 0) return;
    final z = size.x / (CauHinh.soONhinThayNgang * CauHinh.kichThuocO);
    camera.viewfinder.zoom =
        z.clamp(CauHinh.zoomToiThieu, CauHinh.zoomToiDa).toDouble();
  }

  // ==================================================================
  // Dựng ván chơi
  // ==================================================================
  void _dungVan() {
    // Xoá sạch nhân vật của ván trước, giữ lại bản đồ.
    theGioi.children
        .where((c) => c is George || c is KeDich || c is DongXu)
        .toList()
        .forEach((c) => c.removeFromParent());

    soXuDaNhat = 0;
    tongSoXu = 0;

    final diemGeorge = banDo.diemXuatHien.firstWhere(
      (d) => d.ten == 'george',
      orElse: () => DiemXuatHien('george', banDo.kichThuoc / 2),
    );

    george = George(
      banDo: banDo,
      hoatAnh: taiNguyen.george,
      viTri: diemGeorge.viTri.clone(),
      khiChiSoDoi: _khiChiSoDoi,
      khiChet: _khiGeorgeChet,
    );
    theGioi.add(george!);

    Vector2 viTriNguoiChoi() => george?.position ?? Vector2.zero();
    double heSoTocDo() => doKho.heSoTocDo;

    for (final d in banDo.diemXuatHien) {
      switch (d.ten) {
        case 'coin':
          tongSoXu++;
          theGioi.add(DongXu(
            hoatAnh: taiNguyen.dongXu,
            viTri: d.viTri.clone(),
          ));
          break;
        case 'zombie':
          theGioi.add(KeDich.zombie(
            banDo: banDo,
            hoatAnh: taiNguyen.zombie,
            viTri: d.viTri.clone(),
            viTriNguoiChoi: viTriNguoiChoi,
            timDuong: timDuong,
            heSoTocDo: heSoTocDo,
          ));
          break;
        case 'skeleton':
          theGioi.add(KeDich.skeleton(
            banDo: banDo,
            hoatAnh: taiNguyen.skeleton,
            viTri: d.viTri.clone(),
            viTriNguoiChoi: viTriNguoiChoi,
            timDuong: timDuong,
            heSoTocDo: heSoTocDo,
          ));
          break;
      }
    }

    camera.follow(george!, snap: true);

    nhatKy.batDau(tongSoXu);
    doKho.datLai();
    _mauTruoc = george!.mau;
    _diemTruoc = 0;
  }

  void _khiChiSoDoi() {
    final g = george;
    if (g == null) return;

    // Ghi nhật ký: điểm tăng = vừa nhặt xu, máu giảm = vừa trúng đòn.
    if (g.diem > _diemTruoc) nhatKy.ghiNhatXu(g.position.x, g.position.y);
    if (g.mau < _mauTruoc) nhatKy.ghiTrungDon(g.position.x, g.position.y);
    _diemTruoc = g.diem;
    _mauTruoc = g.mau;

    final nhat = g.diem ~/ CauHinh.diemMoiDongXu;
    if (nhat != soXuDaNhat) {
      soXuDaNhat = nhat;
      if (soXuDaNhat >= tongSoXu && tongSoXu > 0) {
        _khiThangCuoc();
      }
    }
  }

  void _khiGeorgeChet() {
    trangThai = TrangThaiChoi.thua;
    _ketThucVan();
  }

  void _khiThangCuoc() {
    trangThai = TrangThaiChoi.thang;
    _ketThucVan();
  }

  void _ketThucVan() {
    _guiNhatKy(trangThai == TrangThaiChoi.thang ? 'thang' : 'thua');
    diemCaoNhat = max(diemCaoNhat, george?.diem ?? 0);
    _datDieuKhien(false);
    AmThanh.dungNhacNen();
    overlays.add(LopPhu.ketThuc);
    pauseEngine();
  }

  // ==================================================================
  // Vòng lặp
  // ==================================================================
  @override
  void update(double dt) {
    super.update(dt);
    if (trangThai != TrangThaiChoi.dangChoi) return;

    _docJoystick();
    _ghimCameraTrongBanDo();

    // Mỗi 10 giây: chụp đặc trưng → mô hình dự đoán → chỉnh tốc độ kẻ địch.
    final g = george;
    if (g != null && nhatKy.troiThoiGian(dt)) {
      doKho.capNhat(nhatKy.chup(g.mau, CauHinh.mauToiDa));
    }
  }

  /// Đóng nhật ký ván và gửi về máy chủ (nếu đã cấu hình GOLD_RUSH_API).
  /// Không `await`: gửi chạy nền, màn hình kết thúc hiện ra ngay.
  void _guiNhatKy(String ketQua) {
    if (!_vanDangDienRa) return;
    _vanDangDienRa = false;
    final g = george;
    if (g != null) nhatKy.chup(g.mau, CauHinh.mauToiDa);
    final nk = nhatKy.thanhJson(
      ketQua: ketQua,
      diem: g?.diem ?? 0,
      phienBanApp: phienBanApp,
      doKhoThichUng: doKho.batThichUng && doKho.moHinh != null,
    );
    debugPrint('Ván ${nk['ma_van']}: $ketQua, ${nk['giay']} giây, '
        '${nhatKy.anhChup.length} ảnh chụp, ${nhatKy.suKien.length} sự kiện');
    unawaited(GuiNhatKy.gui(nk));
  }

  void _docJoystick() {
    final j = joystick;
    final g = george;
    if (j == null || g == null) return;

    if (j.direction == JoystickDirection.idle) {
      g.huongJoystick.setZero();
    } else {
      g.huongJoystick.setFrom(j.relativeDelta);
    }
  }

  /// Không cho camera nhìn ra ngoài rìa bản đồ.
  ///
  /// Gọi SAU super.update, vì hành vi `follow` của camera chạy trong lượt cập
  /// nhật của các component con — chặn trước thì bị ghi đè ngay sau đó.
  ///
  /// Bản đồ hẹp hơn màn hình theo trục nào thì canh giữa theo trục đó, nếu
  /// không sẽ thấy viền đen lệch hẳn về một bên.
  void _ghimCameraTrongBanDo() {
    final zoom = camera.viewfinder.zoom;
    if (zoom <= 0) return;

    final nuaW = size.x / (2 * zoom);
    final nuaH = size.y / (2 * zoom);
    final bd = banDo.kichThuoc;
    final vf = camera.viewfinder;

    if (bd.x <= nuaW * 2) {
      vf.position.x = bd.x / 2;
    } else {
      vf.position.x = vf.position.x.clamp(nuaW, bd.x - nuaW);
    }

    if (bd.y <= nuaH * 2) {
      vf.position.y = bd.y / 2;
    } else {
      vf.position.y = vf.position.y.clamp(nuaH, bd.y - nuaH);
    }
  }

  // ==================================================================
  // Điều hướng màn hình
  // ==================================================================
  /// Bật/tắt cùng lúc cả hai kênh điều khiển: chạm màn hình và bàn phím.
  void _datDieuKhien(bool bat) {
    theGioi.nhanCham = bat;
    george?.dieuKhienDuoc = bat;
    if (!bat) george?.viTriDich = null;
  }

  void _anTatCaLopPhu() {
    overlays.remove(LopPhu.menu);
    overlays.remove(LopPhu.caiDat);
    overlays.remove(LopPhu.tamDung);
    overlays.remove(LopPhu.ketThuc);
  }

  /// Bắt đầu ván mới từ menu hoặc từ màn hình kết thúc.
  void batDauVanMoi() {
    _dungVan();
    _vanDangDienRa = true;
    _anTatCaLopPhu();
    trangThai = TrangThaiChoi.dangChoi;
    _datDieuKhien(true);
    resumeEngine();
    // Bật nhạc NGAY SAU thao tác chạm của người dùng — trình duyệt chỉ cho
    // phát âm thanh sau cử chỉ đầu tiên.
    AmThanh.batNhacNen();
  }

  void tamDung() {
    if (trangThai != TrangThaiChoi.dangChoi) return;
    trangThai = TrangThaiChoi.tamDung;
    _datDieuKhien(false);
    george?.huongJoystick.setZero();
    AmThanh.tamDungNhac();
    overlays.add(LopPhu.tamDung);
    pauseEngine();
  }

  void tiepTuc() {
    if (trangThai != TrangThaiChoi.tamDung) return;
    overlays.remove(LopPhu.tamDung);
    trangThai = TrangThaiChoi.dangChoi;
    _datDieuKhien(true);
    AmThanh.tiepTucNhac();
    resumeEngine();
  }

  void veMenu() {
    _guiNhatKy('bo'); // rời ván giữa chừng (không làm gì nếu ván đã kết thúc)
    _anTatCaLopPhu();
    overlays.add(LopPhu.menu);
    trangThai = TrangThaiChoi.tamDung;
    _datDieuKhien(false);
    AmThanh.dungNhacNen();
    _dungVan();
    pauseEngine();
  }

  void moCaiDat() {
    overlays.add(LopPhu.caiDat);
  }

  void dongCaiDat() {
    overlays.remove(LopPhu.caiDat);
  }
}
