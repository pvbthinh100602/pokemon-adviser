# rr_logger – cho Pika "xem" m chơi Radical Red

Script Lua này chạy trong mGBA, cứ khoảng nửa giây đọc RAM game một lần rồi ghi ra file. Nó chỉ đọc, không sửa gì trong game, nên save của m vẫn an toàn.

## Cài (làm 1 lần)

1. Cần **mGBA 0.10 trở lên** (Help > About để xem version).
2. Copy `rr_logger.lua` vào đâu cũng được, ví dụ `C:\Users\phamv\Documents\rr-log\`.
3. Mặc định log được ghi vào `D:/pokemon-adviser/rr-log/`. Muốn đổi thì mở file `.lua`, sửa dòng `OUT_DIR` ở đầu file (dùng dấu `/`). Để `""` thì log nằm chung thư mục với script.
   - Nếu thư mục chưa có, script tự tạo (có thể nháy lên cái cửa sổ cmd đen 1 giây, kệ nó). Tạo không được thì nó ghi vào thư mục chứa script.

## Mỗi lần chơi

1. Mở mGBA, load ROM Radical Red.
2. **Tools > Scripting...**
3. Trong cửa sổ Scripting: **File > Load script** rồi chọn `rr_logger.lua`.
4. **Đừng tắt cửa sổ Scripting** (thu nhỏ thì được). Tắt là script ngừng ghi.
5. Load file trước hay sau khi mở game đều được. Lần đầu nó quét ROM mất khoảng 1 giây để lấy tên Pokémon, chiêu, ability, item.

Trong khung console m sẽ thấy mấy dòng `[rr] {...}` mỗi khi có chuyện xảy ra, vậy là script đang chạy ngon.

## File nó ghi ra

| File | Là gì |
|---|---|
| `rr_events.jsonl` | Nhật ký live, mỗi dòng là 1 sự kiện, có giờ và số frame. Chỉ ghi nối thêm, xoá lúc nào cũng được. |
| `rr_snapshot.json` | Trạng thái hiện tại: team (level, HP, chiêu + PP, ability, nature, item, IV/EV), badge, vị trí, tiền, giờ chơi, đang đánh ai, 25 sự kiện gần nhất. Cứ vài giây ghi đè lại. |
| `rr_rom_tables.json` | Thông tin chẩn đoán: script có tìm được bảng tên trong ROM không. |

Sự kiện được log: vào map mới, bắt đầu/kết thúc trận (wild hay trainer, đối thủ là con gì level mấy, thắng/thua/chạy/bắt), máu lên xuống và chiêu được dùng trong trận, đổi con, ngất, bắt được Pokémon, thêm/bớt con trong team, lên level, tiến hoá, học/quên chiêu, đổi item cầm, lấy badge, whiteout, tiền thay đổi, load save state.

Muốn t xem thì nói kiểu "Pika xem log đi". T sẽ đọc `rr_snapshot.json` với đoạn cuối `rr_events.jsonl` trên máy m (lúc đó m bấm duyệt cho t đọc file).

## Mấy cái nên test trước

1. Load script, vào game, đi vài bước, mở `rr_rom_tables.json` xem có chỗ nào ghi `NOT FOUND` không. Nếu `species`/`moves` bị NOT FOUND thì log chỉ có số ID, không có tên. Gửi t file đó là t sửa.
2. Mở `rr_snapshot.json`, so team với màn hình Summary trong game: level, HP, chiêu, nature, ability.
3. Đánh 1 trận wild, thử chạy trốn, rồi đánh 1 trận trainer. Xem `rr_events.jsonl` có `battle_start` / `battle_end` với outcome đúng không.
4. Đổi map xem có `map_change` không. Tên map chỉ có cho vùng Kanto, chỗ nào lạ thì chỉ có số.

## Lưu ý

- Load save state thoải mái: script tự nhận ra (event `state_jump`) và chụp lại trạng thái mới. Chỉ là mấy event xảy ra ngay quanh lúc load có thể bị thiếu.
- Một số thứ còn là đoán (xem phần "chưa chắc" trong báo cáo của t). Thấy sai thì nói t.
- Muốn bớt spam (ví dụ không muốn log từng phát mất máu) thì sửa `LOG_BATTLE_DETAIL = false` ở đầu file.
