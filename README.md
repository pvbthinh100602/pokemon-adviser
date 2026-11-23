# pokemon-adviser

Repo cho một AI agent đóng vai "adviser" đi cùng t chơi Pokémon. Game hiện tại: **Pokémon Radical Red v4.1** (ROM hack FireRed), chơi trên **mGBA 0.10.5** (Windows), Normal mode, Minimal Grinding, starter Sprigatito.

## Ý tưởng

1. `logger/rr_logger.lua` chạy trong mGBA, ghi lại quá trình chơi live (đổi map, trận đấu, bắt Pokémon, lên level, tiến hóa, badge, đổi team...) ra file.
2. Agent đọc log + snapshot để biết t đang ở đâu, team ra sao, rồi tư vấn: build team, type matchup, chiến thuật boss, chỗ bắt Pokémon / lấy item.
3. `progress/` lưu tiến độ tóm tắt để agent nhớ qua các phiên.

## Cấu trúc

| Đường dẫn | Nội dung |
|---|---|
| `AGENTS.md` | Hướng dẫn cho agent adviser (vai trò, nguồn tham khảo, luật) |
| `logger/` | Script Lua cho mGBA + hướng dẫn cài |
| `progress/` | Tiến độ chơi (badge, team, chỗ đang kẹt) |
| `docs/references.md` | Nguồn tham khảo chính thức |

## Cài logger nhanh

mGBA > Tools > Scripting > File > Load script > chọn `logger/rr_logger.lua`. Giữ cửa sổ Scripting mở. Log mặc định ghi vào `D:/pokemon-adviser/rr-log/` (xem `logger/README.md`).

> Repo này không chứa và không bao giờ link tới file ROM.
