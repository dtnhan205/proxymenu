import os
import math
import shutil
import subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

BG_PATH = r"C:\Users\nhand\.gemini\antigravity-ide\brain\ac937181-c879-48b1-81e0-8dcbafb32db5\intro_cyber_bg_1790943974750.jpg"
OUTPUT_DIR = r"D:\DEVELOPER\proxy\proxymenu\tools"
OUTPUT_MP4 = os.path.join(OUTPUT_DIR, "intro.mp4")
OUTPUT_RESOURCE = r"D:\DEVELOPER\proxy\proxymenu\AppNew\ThreeOneOSFive\intro.mp4"

WIDTH = 720
HEIGHT = 1280
FPS = 30
TOTAL_FRAMES = 114  # 3.8 seconds

# Load fonts
FONT_DIR = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts")
font_title = ImageFont.truetype(os.path.join(FONT_DIR, "segoeuib.ttf"), 38)
font_sub = ImageFont.truetype(os.path.join(FONT_DIR, "consola.ttf"), 16)
font_bold = ImageFont.truetype(os.path.join(FONT_DIR, "arialbd.ttf"), 20)
font_hud = ImageFont.truetype(os.path.join(FONT_DIR, "consola.ttf"), 14)
font_small = ImageFont.truetype(os.path.join(FONT_DIR, "consola.ttf"), 12)

# Load and resize background
raw_bg = Image.open(BG_PATH).convert("RGBA").resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

VISOR_X = int(363 * (WIDTH / 768))
VISOR_Y = int(502 * (HEIGHT / 1376))

def draw_corner_brackets(draw, x0, y0, x1, y1, length=18, color=(0, 240, 255, 255), width=2):
    draw.line([(x0, y0), (x0 + length, y0)], fill=color, width=width)
    draw.line([(x0, y0), (x0, y0 + length)], fill=color, width=width)
    draw.line([(x1, y0), (x1 - length, y0)], fill=color, width=width)
    draw.line([(x1, y0), (x1, y0 + length)], fill=color, width=width)
    draw.line([(x0, y1), (x0 + length, y1)], fill=color, width=width)
    draw.line([(x0, y1), (x0, y1 - length)], fill=color, width=width)
    draw.line([(x1, y1), (x1 - length, y1)], fill=color, width=width)
    draw.line([(x1, y1), (x1 - length, y1)], fill=color, width=width)

def draw_reticle(draw, cx, cy, radius, angle, color, locked=False):
    for i in range(4):
        start_a = angle + i * 90 + 10
        end_a = angle + i * 90 + 80
        draw.arc([cx - radius, cy - radius, cx + radius, cy + radius],
                 start=start_a, end=end_a, fill=color, width=2)
    in_r = int(radius * 0.45)
    draw.ellipse([cx - in_r, cy - in_r, cx + in_r, cy + in_r], outline=color, width=1)
    if locked:
        draw.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=color)
        dist = radius + 6
        for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            draw.line([(cx + dx * dist, cy + dy * dist), (cx + dx * (dist - 8), cy + dy * (dist - 8))], fill=color, width=3)
    else:
        draw.line([(cx - radius - 8, cy), (cx - in_r, cy)], fill=color, width=1)
        draw.line([(cx + in_r, cy), (cx + radius + 8, cy)], fill=color, width=1)
        draw.line([(cx, cy - radius - 8), (cx, cy - in_r)], fill=color, width=1)
        draw.line([(cx, cy + in_r), (cx, cy + radius + 8)], fill=color, width=1)

def render_frame(f_idx):
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    
    # 1. Subtle camera zoom on background
    zoom = 1.03 - 0.03 * (min(f_idx, 60) / 60.0)
    if zoom > 1.001:
        zw = int(WIDTH * zoom)
        zh = int(HEIGHT * zoom)
        zoomed = raw_bg.resize((zw, zh), Image.Resampling.BILINEAR)
        x_off = (zw - WIDTH) // 2
        y_off = (zh - HEIGHT) // 2
        frame = zoomed.crop((x_off, y_off, x_off + WIDTH, y_off + HEIGHT))
    else:
        frame = raw_bg.copy()
    
    # 2. Scanning Laser line (frames 0 to 45)
    if f_idx < 45:
        scan_y = int((f_idx / 45.0) * HEIGHT)
        scan_alpha = int(180 * (1.0 - f_idx / 55.0))
        draw.line([(0, scan_y), (WIDTH, scan_y)], fill=(0, 240, 255, scan_alpha), width=2)
        for dy in range(1, 10):
            a = max(0, scan_alpha - dy * 18)
            draw.line([(0, scan_y - dy), (WIDTH, scan_y - dy)], fill=(0, 240, 255, a), width=1)
            draw.line([(0, scan_y + dy), (WIDTH, scan_y + dy)], fill=(0, 240, 255, a), width=1)

    # 3. Reticle and Lock-on
    is_locked = f_idx >= 40
    ret_color = (255, 30, 80, 240) if is_locked else (0, 240, 255, 220)
    
    if f_idx >= 8:
        rot_angle = (f_idx * 5) % 360
        ret_rad = 54
        if f_idx < 40:
            shrink = (40 - f_idx) / 32.0
            ret_rad = int(54 + shrink * 70)
        else:
            pulse = math.sin((f_idx - 40) * 0.4) * 3
            ret_rad = int(54 + pulse)
            
        draw_reticle(draw, VISOR_X, VISOR_Y, ret_rad, rot_angle, ret_color, locked=is_locked)
        
        box_w = 120
        box_h = 100
        bx0 = VISOR_X - box_w // 2
        by0 = VISOR_Y - box_h // 2
        bx1 = bx0 + box_w
        by1 = by0 + box_h
        draw_corner_brackets(draw, bx0, by0, bx1, by1, length=14, color=ret_color, width=2)
        
        hud_x = bx1 + 10
        hud_y = by0
        if is_locked:
            draw.text((hud_x, hud_y), "TARGET: LOCKED", fill=(255, 30, 80, 255), font=font_hud)
            draw.text((hud_x, hud_y + 16), "BONE: HEAD [100%]", fill=(255, 230, 50, 255), font=font_hud)
            draw.text((hud_x, hud_y + 32), "DIST: 38.4m", fill=(0, 240, 255, 240), font=font_small)
            draw.text((hud_x, hud_y + 46), "AIMBOT: ACTIVE", fill=(0, 255, 140, 255), font=font_small)
        else:
            draw.text((hud_x, hud_y), "ACQUIRING...", fill=(0, 240, 255, 220), font=font_hud)
            draw.text((hud_x, hud_y + 16), f"DIST: {45 - (f_idx-8)*0.2:.1f}m", fill=(200, 220, 255, 200), font=font_small)
            draw.text((hud_x, hud_y + 30), "SCANNING BONES...", fill=(180, 180, 180, 180), font=font_small)

    # 4. Top Status Header
    top_y = 60
    draw.text((36, top_y), "/// INNOVA CHEAT PROTOCOL ///", fill=(0, 240, 255, 230), font=font_hud)
    fps_text = f"FPS: {FPS} | LATENCY: 8ms"
    draw.text((WIDTH - 36 - 160, top_y), fps_text, fill=(0, 240, 255, 180), font=font_small)
    draw.line([(36, top_y + 22), (WIDTH - 36, top_y + 22)], fill=(0, 240, 255, 80), width=1)
    
    # 5. Center Branding Card (frames 35 onwards)
    if f_idx >= 32:
        card_alpha = min(255, int((f_idx - 32) * 22))
        card_w = 640
        card_h = 240
        cx0 = (WIDTH - card_w) // 2
        cy0 = HEIGHT - 360
        cx1 = cx0 + card_w
        cy1 = cy0 + card_h
        
        bg_card = Image.new("RGBA", (card_w, card_h), (8, 12, 22, int(card_alpha * 0.88)))
        frame.paste(bg_card, (cx0, cy0), bg_card)
        
        bracket_col = (255, 30, 80, card_alpha) if (f_idx % 10 < 5) else (0, 240, 255, card_alpha)
        draw_corner_brackets(draw, cx0, cy0, cx1, cy1, length=24, color=bracket_col, width=2)
        draw.rectangle([cx0, cy0, cx1, cy1], outline=(0, 240, 255, int(card_alpha * 0.3)), width=1)
        
        title_text = "I N N O V A  C H E A T"
        t_box = font_title.getbbox(title_text)
        tw = t_box[2] - t_box[0]
        tx = (WIDTH - tw) // 2
        ty = cy0 + 26
        
        glow_color = (0, 240, 255, int(card_alpha * 0.5))
        for g in range(1, 4):
            draw.text((tx - g, ty), title_text, fill=glow_color, font=font_title)
            draw.text((tx + g, ty), title_text, fill=glow_color, font=font_title)
            draw.text((tx, ty - g), title_text, fill=glow_color, font=font_title)
            draw.text((tx, ty + g), title_text, fill=glow_color, font=font_title)
        draw.text((tx, ty), title_text, fill=(255, 255, 255, card_alpha), font=font_title)
        
        sub_text = "TACTICAL ASSIST & MEMORY CORE"
        s_box = font_sub.getbbox(sub_text)
        sw = s_box[2] - s_box[0]
        draw.text(((WIDTH - sw) // 2, ty + 50), sub_text, fill=(0, 240, 255, int(card_alpha * 0.9)), font=font_sub)
        
        div_y = ty + 78
        draw.line([(cx0 + 40, div_y), (cx1 - 40, div_y)], fill=(255, 30, 80, int(card_alpha * 0.6)), width=1)
        
        eq_y = div_y + 14
        eq_count = 32
        eq_w = (card_w - 120) // eq_count
        for b in range(eq_count):
            bh = int(12 + 18 * abs(math.sin(f_idx * 0.35 + b * 0.4)))
            bx = cx0 + 60 + b * eq_w
            b_col = (0, 240, 255, int(card_alpha * 0.85)) if b % 2 == 0 else (255, 30, 80, int(card_alpha * 0.85))
            draw.rectangle([bx, eq_y + (28 - bh), bx + eq_w - 2, eq_y + 28], fill=b_col)
            
        if f_idx >= 88:
            gate_text = "► CHUYỂN TIẾP ĐẾN XÁC THỰC KEY..."
            gate_col = (255, 230, 50, card_alpha)
        else:
            gate_text = "● HỆ THỐNG ĐÃ KÍCH HOẠT SẴN SÀNG"
            gate_col = (0, 255, 140, card_alpha)
        g_box = font_bold.getbbox(gate_text)
        gw = g_box[2] - g_box[0]
        draw.text(((WIDTH - gw) // 2, cy1 - 40), gate_text, fill=gate_col, font=font_bold)

    frame = Image.alpha_composite(frame, overlay)
    
    # 6. Glitch around lock on (frames 41-45)
    if 41 <= f_idx <= 45:
        rgb = np.array(frame.convert("RGB"))
        shift = 6 if f_idx % 2 == 0 else -6
        r_chan = np.roll(rgb[:, :, 0], shift, axis=1)
        b_chan = np.roll(rgb[:, :, 2], -shift, axis=1)
        rgb[:, :, 0] = r_chan
        rgb[:, :, 2] = b_chan
        frame = Image.fromarray(rgb).convert("RGBA")

    # 7. Fade In (frames 0 to 12) & Fade Out (frames 96 to 114)
    fade_alpha = 1.0
    if f_idx < 12:
        fade_alpha = f_idx / 12.0
    elif f_idx >= 94:
        fade_alpha = max(0.0, 1.0 - (f_idx - 94) / 20.0)
        
    if fade_alpha < 0.999:
        black = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, int((1.0 - fade_alpha) * 255)))
        frame = Image.alpha_composite(frame, black)

    return frame.convert("RGB")

def build_video():
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
    print("Using ffmpeg:", ffmpeg_exe)
    
    cmd = [
        ffmpeg_exe,
        "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-s", f"{WIDTH}x{HEIGHT}",
        "-pix_fmt", "rgb24",
        "-r", str(FPS),
        "-i", "-",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-preset", "fast",
        "-crf", "18",
        "-profile:v", "baseline",
        "-level", "3.1",
        "-movflags", "+faststart",
        OUTPUT_MP4
    ]
    
    print(f"Rendering {TOTAL_FRAMES} frames ({TOTAL_FRAMES/FPS:.1f}s) to {OUTPUT_MP4}...")
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
    
    for i in range(TOTAL_FRAMES):
        if i % 15 == 0:
            print(f"Rendering frame {i}/{TOTAL_FRAMES} ({i*100//TOTAL_FRAMES}%)...")
        frame_rgb = render_frame(i)
        proc.stdin.write(frame_rgb.tobytes())
        
    proc.stdin.close()
    stdout, stderr = proc.communicate()
    
    if proc.returncode != 0:
        err = stderr.decode(errors="ignore")
        print("FFMPEG error:", err)
        raise RuntimeError("FFMPEG failed")
        
    size = os.path.getsize(OUTPUT_MP4)
    print(f"Video created successfully! Size: {size} bytes ({size/1024/1024:.2f} MB)")
    
    # Copy to iOS project resource directory
    shutil.copy2(OUTPUT_MP4, OUTPUT_RESOURCE)
    print(f"Copied to iOS resource bundle: {OUTPUT_RESOURCE}")

if __name__ == "__main__":
    build_video()
