import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';

import 'cau_hinh.dart';

/// Nạp và giữ toàn bộ hình ảnh của game ở MỘT chỗ.
///
/// Vì sao không để mỗi component tự nạp ảnh của mình:
///
///  * Nạp ảnh là thao tác bất đồng bộ và tốn thời gian. Nạp một lần lúc khởi
///    động thì lúc chơi không bao giờ bị khựng.
///  * Mười con quái dùng chung một `SpriteAnimation` thay vì mười bản sao.
///  * Component không cần biết gì về `Flame.images` -> dễ kiểm thử hơn.
class TaiNguyen {
  late final Map<HuongDi, SpriteAnimation> george;
  late final Map<HuongDi, SpriteAnimation> zombie;
  late final Map<HuongDi, SpriteAnimation> skeleton;
  late final SpriteAnimation dongXu;
  late final Sprite joystickNen;
  late final Sprite joystickNum;

  /// Gọi đúng một lần trong `onLoad` của game.
  Future<void> nap() async {
    final anhGeorge = await Flame.images.load('george.png');
    final anhZombie = await Flame.images.load('zombie.png');
    final anhSkeleton = await Flame.images.load('skeleton.png');
    final anhDongXu = await Flame.images.load('dong_xu.png');

    george = _bonHuong(anhGeorge, 0.12);
    zombie = _bonHuong(anhZombie, 0.18);
    skeleton = _bonHuong(anhSkeleton, 0.14);

    dongXu = SpriteAnimation.fromFrameData(
      anhDongXu,
      SpriteAnimationData.sequenced(
        amount: 8,
        amountPerRow: 8,
        stepTime: 0.09,
        textureSize: Vector2.all(CauHinh.kichThuocO),
      ),
    );

    joystickNen = Sprite(await Flame.images.load('joystick_nen.png'));
    joystickNum = Sprite(await Flame.images.load('joystick_num.png'));
  }

  /// Cắt một sprite sheet 4 hàng × 4 cột thành bốn hoạt ảnh theo hướng.
  ///
  /// `texturePosition` là góc trên-trái của hàng cần cắt. Hàng thứ `i` bắt đầu
  /// ở toạ độ y = i × 16. Đây là chỗ hay nhầm nhất khi làm việc với sprite
  /// sheet: nhầm hàng thì nhân vật đi xuống mà hoạt ảnh lại quay lưng.
  Map<HuongDi, SpriteAnimation> _bonHuong(ui.Image anh, double buocThoiGian) {
    SpriteAnimation hang(int i) => SpriteAnimation.fromFrameData(
          anh,
          SpriteAnimationData.sequenced(
            amount: 4,
            amountPerRow: 4,
            stepTime: buocThoiGian,
            textureSize: Vector2.all(CauHinh.kichThuocO),
            texturePosition: Vector2(0, i * CauHinh.kichThuocO),
          ),
        );

    return {
      HuongDi.xuong: hang(0),
      HuongDi.trai: hang(1),
      HuongDi.phai: hang(2),
      HuongDi.len: hang(3),
    };
  }
}
