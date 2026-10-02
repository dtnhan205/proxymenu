import os
import math
import shutil
import subprocess
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

BG_PATH = r"C:\Users\nhand\.gemini\antigravity-ide\brain\ac937181-c879-48b1-81e0-8dcbafb32db5\intro_cheat_bg_1790957667645.jpg"
OUTPUT_DIR = r"D:\DEVELOPER\proxy\proxymenu\tools"
OUTPUT_MP4 = os.path.join(OUTPUT_DIR, "intro.mp4")
OUTPUT_RESOURCE = r"D:\DEVELOPER\proxy\proxymenu\AppNew\ThreeOneOSFive\intro.mp4"

WIDTH = 720
HEIGHT = 1280
FPS = 30
TOTAL_FRAMES = 114  # 3.8 seconds

# Load fonts
FONT_DIR = os.path.join(os.environ.get("WINDIR", "C:\\Windows"), "Fonts")
font_title = ImageFont.truetype(os.path.join(FONT_DIR, "bahnschrift.ttf"), 38)
font_card_sub = ImageFont.truetype(os.path.join(FONT_DIR, "bahnschrift.ttf"), 15)
font_mono_bold = ImageFont.truetype(os.path.join(FONT_DIR, "consolab.ttf"), 13)
font_mono = ImageFont.truetype(os.path.join(FONT_DIR, "consola.ttf"), 12)
font_mono_small = ImageFont.truetype(os.path.join(FONT_DIR, "consola.ttf"), 11)
font_badge = ImageFont.truetype(os.path.join(FONT_DIR, "arialbd.ttf"), 11)
font_hud = ImageFont.truetype(os.path.join(FONT_DIR, "consolab.ttf"), 12)

# Load and prepare base background
raw_bg = Image.open(BG_PATH).convert("RGBA").resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)

# Operative Keypoints
HEAD_POS = (400, 325)
SPINE_TOP = (410, 410)
SPINE_MID = (420, 520)
SPINE_BOT = (430, 650)
SH_L = (335, 430)
SH_R = (510, 420)
EL_L = (300, 490)
EL_R = (580, 495)
WR_L = (345, 525)
WR_R = (460, 515)
HIP_L = (385, 760)
HIP_R = (485, 760)
KN_L = (370, 890)
KN_R = (490, 890)

BONE_SKELETON = [
    (HEAD_POS, SPINE_TOP),
    (SPINE_TOP, SPINE_MID),
    (SPINE_MID, SPINE_BOT),
    (SPINE_TOP, SH_L),
    (SH_L, EL_L),
    (EL_L, WR_L),
    (SPINE_TOP, SH_R),
    (SH_R, EL_R),
    (EL_R, WR_R),
    (SPINE_BOT, HIP_L),
    (HIP_L, KN_L),
    (SPINE_BOT, HIP_R),
    (HIP_R, KN_R),
]

JOINTS = [
    HEAD_POS, SPINE_TOP, SPINE_MID, SPINE_BOT,
    SH_L, SH_R, EL_L, EL_R, WR_L, WR_R,
    HIP_L, HIP_R, KN_L, KN_R
]

CROSSHAIR_POS = (WIDTH // 2, 560)

def draw_corner_brackets(draw, x0, y0, x1, y1, length=24, color=(0, 240, 255, 255), width=2):
    draw.line([(x0, y0), (x0 + length, y0)], fill=color, width=width)
    draw.line([(x0, y0), (x0, y0 + length)], fill=color, width=width)
    draw.line([(x1, y0), (x1 - length, y0)], fill=color, width=width)
    draw.line([(x1, y0), (x1, y0 + length)], fill=color, width=width)
    draw.line([(x0, y1), (x0 + length, y1)], fill=color, width=width)
    draw.line([(x0, y1), (x0, y1 - length)], fill=color, width=width)
    draw.line([(x1, y1), (x1 - length, y1)], fill=color, width=width)
    draw.line([(x1, y1), (x1, y1 - length)], fill=color, width=width)

def render_frame(f_idx):
    overlay = Image.new("RGBA", (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # 1. Smooth Camera Zoom (slow push-in)
    zoom = 1.03 - 0.03 * (min(f_idx, 75) / 75.0)
    if zoom > 1.001:
        zw = int(WIDTH * zoom)
        zh = int(HEIGHT * zoom)
        zoomed = raw_bg.resize((zw, zh), Image.Resampling.BILINEAR)
        x_off = (zw - WIDTH) // 2
        y_off = (zh - HEIGHT) // 2
        frame = zoomed.crop((x_off, y_off, x_off + WIDTH, y_off + HEIGHT))
    else:
        frame = raw_bg.copy()

    is_locked = f_idx >= 42
    main_col = (255, 35, 75, 255) if is_locked else (0, 245, 255, 230)
    sub_col = (255, 60, 95, 200) if is_locked else (0, 255, 170, 200)

    # 2. Scanning Laser Grid (frames 0 to 40)
    if f_idx < 40:
        scan_y = int((f_idx / 40.0) * HEIGHT)
        scan_alpha = int(180 * (1.0 - f_idx / 48.0))
        draw.line([(0, scan_y), (WIDTH, scan_y)], fill=(0, 245, 255, scan_alpha), width=2)
        for dy in range(1, 8):
            a = max(0, scan_alpha - dy * 22)
            draw.line([(0, scan_y - dy), (WIDTH, scan_y - dy)], fill=(0, 245, 255, a), width=1)
            draw.line([(0, scan_y + dy), (WIDTH, scan_y + dy)], fill=(0, 245, 255, a), width=1)

    # 3. Top Left Terminal - Memory Injection Logs
    if f_idx >= 2:
        log_alpha = min(240, int((f_idx - 2) * 20))
        term_x = 24
        term_y = 52
        term_w = 316

        all_logs = [
            "[+] INNOVA VIP CORE v3.5 ACTIVE",
            "[+] HOOKING GameAssembly.dll... [OK]",
            "[+] BYPASS AC: SafeGuard KERNEL PASSED",
            "[+] ESP 3D BONES & HEALTH [ON]",
            "[+] SILENT AIMBOT: FOV 160 | SMOOTH 0",
            "[+] TARGET: LOCKED (PING: 12ms)"
        ]

        visible_lines = min(len(all_logs), 1 + (f_idx - 2) // 7)
        cur_logs = all_logs[:visible_lines]
        term_h = len(cur_logs) * 16 + 22

        term_bg = Image.new("RGBA", (term_w, term_h), (6, 10, 16, int(log_alpha * 0.88)))
        frame.paste(term_bg, (term_x, term_y), term_bg)
        draw.rectangle([term_x, term_y, term_x + term_w, term_y + term_h],
                       outline=(0, 240, 255, int(log_alpha * 0.45)), width=1)
        draw.rectangle([term_x, term_y, term_x + term_w, term_y + 16],
                       fill=(0, 240, 255, int(log_alpha * 0.25)))
        draw.text((term_x + 6, term_y + 2), "TERMINAL: INJECTION LOGS",
                  fill=(0, 240, 255, log_alpha), font=font_mono_small)

        for idx, l in enumerate(cur_logs):
            c = (0, 255, 140, log_alpha) if ("OK" in l or "ON" in l or "ACTIVE" in l or "PASSED" in l) else (200, 230, 255, log_alpha)
            if "LOCKED" in l:
                c = (255, 50, 80, log_alpha)
            text_str = l
            if idx == len(cur_logs) - 1 and (f_idx % 8 < 4):
                text_str += " _"
            draw.text((term_x + 8, term_y + 20 + idx * 16), text_str, fill=c, font=font_mono_small)

    # 4. Top Right Tactical Radar
    if f_idx >= 4:
        rad_alpha = min(255, int((f_idx - 4) * 20))
        rcx, rcy, rcr = 636, 106, 50

        draw.ellipse([rcx - rcr, rcy - rcr, rcx + rcr, rcy + rcr],
                     fill=(8, 14, 22, int(rad_alpha * 0.82)),
                     outline=(0, 240, 255, int(rad_alpha * 0.6)), width=2)
        draw.ellipse([rcx - rcr // 2, rcy - rcr // 2, rcx + rcr // 2, rcy + rcr // 2],
                     outline=(0, 240, 255, int(rad_alpha * 0.3)), width=1)
        draw.line([(rcx - rcr, rcy), (rcx + rcr, rcy)], fill=(0, 240, 255, int(rad_alpha * 0.35)), width=1)
        draw.line([(rcx, rcy - rcr), (rcx, rcy + rcr)], fill=(0, 240, 255, int(rad_alpha * 0.35)), width=1)

        sweep_ang = math.radians((f_idx * 14) % 360)
        draw.line([(rcx, rcy), (rcx + int(math.cos(sweep_ang) * rcr), rcy + int(math.sin(sweep_ang) * rcr))],
                  fill=(0, 255, 200, rad_alpha), width=2)

        blip_x = rcx + 10
        blip_y = rcy - 12
        blip_pulse = 2 if (f_idx % 12 < 6) else 0
        draw.ellipse([blip_x - 3 - blip_pulse, blip_y - 3 - blip_pulse,
                      blip_x + 3 + blip_pulse, blip_y + 3 + blip_pulse],
                     fill=(255, 30, 75, rad_alpha))
        draw.text((rcx - 28, rcy + rcr + 4), "RADAR 360°", fill=(0, 240, 255, int(rad_alpha * 0.8)), font=font_mono_small)

    # 5. ESP Wireframe Bones & Joints (frames 14 onwards)
    if f_idx >= 14:
        bone_alpha = min(240, int((f_idx - 14) * 20))
        bone_c = (*sub_col[:3], bone_alpha)

        for pt1, pt2 in BONE_SKELETON:
            draw.line([pt1, pt2], fill=bone_c, width=2)

        for jpt in JOINTS:
            draw.ellipse([jpt[0] - 3, jpt[1] - 3, jpt[0] + 3, jpt[1] + 3],
                         fill=(*main_col[:3], bone_alpha))

        draw.ellipse([HEAD_POS[0] - 22, HEAD_POS[1] - 22, HEAD_POS[0] + 22, HEAD_POS[1] + 22],
                     outline=bone_c, width=2)

    # 6. ESP Bounding Box & Health / Armor Bar (frames 18 onwards)
    if f_idx >= 18:
        box_alpha = min(255, int((f_idx - 18) * 18))
        target_bx0, target_by0, target_bx1, target_by1 = 230, 195, 620, 920

        if f_idx < 32:
            progress = (f_idx - 18) / 14.0
            mid_x = (target_bx0 + target_bx1) // 2
            mid_y = (target_by0 + target_by1) // 2
            bx0 = int(mid_x + (target_bx0 - mid_x) * progress)
            by0 = int(mid_y + (target_by0 - mid_y) * progress)
            bx1 = int(mid_x + (target_bx1 - mid_x) * progress)
            by1 = int(mid_y + (target_by1 - mid_y) * progress)
        else:
            bx0, by0, bx1, by1 = target_bx0, target_by0, target_bx1, target_by1

        box_col = (*main_col[:3], box_alpha)
        # Bounding box brackets
        draw_corner_brackets(draw, bx0, by0, bx1, by1, length=28, color=box_col, width=2)
        draw.rectangle([bx0, by0, bx1, by1], outline=(*main_col[:3], int(box_alpha * 0.25)), width=1)

        if f_idx >= 28:
            # Top tag header above box
            tag_w = 264
            draw.rectangle([bx0, by0 - 24, bx0 + tag_w, by0 - 4], fill=(10, 16, 26, int(box_alpha * 0.9)))
            tag_title = "TARGET #1 [ENEMY] 32.4m" if is_locked else "SCANNING TARGET #1..."
            draw.text((bx0 + 6, by0 - 22), tag_title, fill=box_col, font=font_mono_bold)

            # Health Bar (Green, with dark outline)
            hp_h = by1 - by0
            charge = min(1.0, (f_idx - 28) / 14.0)
            fill_top = by1 - int(hp_h * charge)
            
            # Health container
            draw.rectangle([bx0 - 9, by0, bx0 - 4, by1], fill=(10, 14, 20, int(box_alpha * 0.9)),
                           outline=(0, 0, 0, int(box_alpha * 0.8)), width=1)
            # Health fill (Vivid Green)
            if fill_top < by1 - 2:
                draw.rectangle([bx0 - 8, max(by0, fill_top), bx0 - 5, by1 - 1], fill=(0, 255, 120, box_alpha))
            draw.text((bx0 - 30, by0 - 20), f"{int(charge * 100)}", fill=(0, 255, 120, box_alpha), font=font_mono_small)

            # Armor Bar (Cyan, alongside HP)
            draw.rectangle([bx0 - 16, by0, bx0 - 11, by1], fill=(10, 14, 20, int(box_alpha * 0.9)),
                           outline=(0, 0, 0, int(box_alpha * 0.8)), width=1)
            armor_fill_top = by1 - int(hp_h * charge * 0.85)
            if armor_fill_top < by1 - 2:
                draw.rectangle([bx0 - 15, max(by0, armor_fill_top), bx0 - 12, by1 - 1], fill=(0, 220, 255, box_alpha))

            # Bottom weapon info tag
            draw.text((bx0 + 4, by1 + 4), "WEAPON: M4A1-EVO [BURST] | HP: 100 | AP: 85",
                      fill=(*main_col[:3], int(box_alpha * 0.85)), font=font_mono_small)

    # 7. Center Crosshair & Aimbot Vector / Tracer (frames 22 onwards)
    if f_idx >= 22:
        cross_alpha = min(220, int((f_idx - 22) * 16))
        cx, cy = CROSSHAIR_POS
        # Center Crosshair
        draw.line([(cx - 10, cy), (cx - 3, cy)], fill=(255, 255, 255, cross_alpha), width=1)
        draw.line([(cx + 3, cy), (cx + 10, cy)], fill=(255, 255, 255, cross_alpha), width=1)
        draw.line([(cx, cy - 10), (cx, cy - 3)], fill=(255, 255, 255, cross_alpha), width=1)
        draw.line([(cx, cy + 3), (cx, cy + 10)], fill=(255, 255, 255, cross_alpha), width=1)
        draw.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(*main_col[:3], cross_alpha))

        # Aimbot Vector Line: from crosshair to enemy head
        draw.line([CROSSHAIR_POS, HEAD_POS], fill=(*main_col[:3], int(cross_alpha * 0.75)), width=2)
        draw.ellipse([HEAD_POS[0] - 4, HEAD_POS[1] - 4, HEAD_POS[0] + 4, HEAD_POS[1] + 4],
                     fill=(*main_col[:3], cross_alpha))

    # 8. Silent Aimbot FOV Circle & Lock Reticle
    if f_idx >= 8:
        aim_alpha = min(255, int((f_idx - 8) * 15))

        # FOV Circle
        fov_r = 160
        draw.ellipse([WIDTH // 2 - fov_r, 480 - fov_r, WIDTH // 2 + fov_r, 480 + fov_r],
                     outline=(255, 255, 255, int(aim_alpha * 0.22)), width=1)

        # Locking reticle on head
        if f_idx < 42:
            shrink = (42 - f_idx) / 34.0
            ret_r = int(38 + shrink * 60)
        else:
            pulse = math.sin((f_idx - 42) * 0.5) * 3
            ret_r = int(38 + pulse)

        rot_ang = (f_idx * 6) % 360
        ret_c = (*main_col[:3], aim_alpha)
        for i in range(4):
            sa = rot_ang + i * 90 + 15
            ea = rot_ang + i * 90 + 75
            draw.arc([HEAD_POS[0] - ret_r, HEAD_POS[1] - ret_r, HEAD_POS[0] + ret_r, HEAD_POS[1] + ret_r],
                     start=sa, end=ea, fill=ret_c, width=2)

        draw.line([(HEAD_POS[0] - ret_r - 6, HEAD_POS[1]), (HEAD_POS[0] - 10, HEAD_POS[1])], fill=ret_c, width=2)
        draw.line([(HEAD_POS[0] + 10, HEAD_POS[1]), (HEAD_POS[0] + ret_r + 6, HEAD_POS[1])], fill=ret_c, width=2)
        draw.line([(HEAD_POS[0], HEAD_POS[1] - ret_r - 6), (HEAD_POS[0], HEAD_POS[1] - 10)], fill=ret_c, width=2)
        draw.line([(HEAD_POS[0], HEAD_POS[1] + 10), (HEAD_POS[0], HEAD_POS[1] + ret_r + 6)], fill=ret_c, width=2)
        draw.ellipse([HEAD_POS[0] - 3, HEAD_POS[1] - 3, HEAD_POS[0] + 3, HEAD_POS[1] + 3], fill=ret_c)

        # Aimbot Info Flyout Panel
        if f_idx >= 36:
            fly_alpha = min(255, int((f_idx - 36) * 25))
            fly_x = 618
            fly_y = HEAD_POS[1] - 30
            fly_w = 90
            fly_h = 66

            draw.line([HEAD_POS, (HEAD_POS[0] + 40, HEAD_POS[1]), (fly_x, fly_y + 12)],
                      fill=(*main_col[:3], int(fly_alpha * 0.7)), width=1)
            draw.rectangle([fly_x, fly_y, fly_x + fly_w, fly_y + fly_h],
                           fill=(10, 16, 26, int(fly_alpha * 0.92)),
                           outline=(*main_col[:3], fly_alpha), width=1)

            draw.text((fly_x + 6, fly_y + 4), "LOCK: HEAD", fill=(255, 50, 80, fly_alpha), font=font_mono_bold)
            draw.text((fly_x + 6, fly_y + 19), "BONE: #6", fill=(255, 220, 0, fly_alpha), font=font_mono_small)
            draw.text((fly_x + 6, fly_y + 33), "HIT%: 99.8%", fill=(0, 255, 140, fly_alpha), font=font_mono_small)
            draw.text((fly_x + 6, fly_y + 47), "AIM: SILENT", fill=(0, 240, 255, fly_alpha), font=font_mono_small)

    # 9. Center Branding Card (Frames 34 onwards)
    if f_idx >= 34:
        card_alpha = min(255, int((f_idx - 34) * 22))
        cw, ch = 664, 250
        cx0 = (WIDTH - cw) // 2
        cy0 = HEIGHT - 335
        cx1 = cx0 + cw
        cy1 = cy0 + ch

        card_bg = Image.new("RGBA", (cw, ch), (6, 10, 18, int(card_alpha * 0.92)))
        frame.paste(card_bg, (cx0, cy0), card_bg)

        brk_col = (255, 35, 75, card_alpha) if (f_idx % 12 < 6) else (0, 245, 255, card_alpha)
        draw_corner_brackets(draw, cx0, cy0, cx1, cy1, length=24, color=brk_col, width=2)
        draw.rectangle([cx0, cy0, cx1, cy1], outline=(0, 240, 255, int(card_alpha * 0.35)), width=1)

        # Top badges on card
        draw.rectangle([cx0 + 20, cy0 + 14, cx0 + 130, cy0 + 34],
                       fill=(0, 180, 90, int(card_alpha * 0.3)),
                       outline=(0, 255, 140, int(card_alpha * 0.8)))
        draw.text((cx0 + 28, cy0 + 18), "● UNDETECTED", fill=(0, 255, 140, card_alpha), font=font_badge)

        draw.rectangle([cx0 + 140, cy0 + 14, cx0 + 265, cy0 + 34],
                       fill=(200, 140, 0, int(card_alpha * 0.25)),
                       outline=(255, 200, 40, int(card_alpha * 0.8)))
        draw.text((cx0 + 150, cy0 + 18), "★ VIP ANTIBAN", fill=(255, 220, 50, card_alpha), font=font_badge)

        draw.text((cx1 - 150, cy0 + 18), "BUILD: 2026.10-PRO", fill=(160, 180, 210, int(card_alpha * 0.8)), font=font_mono_small)

        # Title "INNOVA CHEAT"
        title_text = "I N N O V A  C H E A T"
        tb = font_title.getbbox(title_text)
        tw = tb[2] - tb[0]
        tx = (WIDTH - tw) // 2
        ty = cy0 + 46

        # Neon Glow Dropshadow
        for g in range(1, 4):
            draw.text((tx - g, ty), title_text, fill=(255, 30, 80, int(card_alpha * 0.4)), font=font_title)
            draw.text((tx + g, ty), title_text, fill=(0, 240, 255, int(card_alpha * 0.4)), font=font_title)
        draw.text((tx, ty), title_text, fill=(255, 255, 255, card_alpha), font=font_title)

        sub_t = "PREMIUM ESP & SILENT AIMBOT PROTOCOL"
        sb = font_card_sub.getbbox(sub_t)
        sw = sb[2] - sb[0]
        draw.text(((WIDTH - sw) // 2, ty + 46), sub_t, fill=(0, 240, 255, int(card_alpha * 0.95)), font=font_card_sub)

        # Dynamic Audio Frequency Equalizer
        eq_y = ty + 74
        eq_n = 36
        bw = (cw - 80) // eq_n
        for i in range(eq_n):
            bh = int(8 + 20 * abs(math.sin(f_idx * 0.45 + i * 0.35)))
            bx = cx0 + 40 + i * bw
            b_col = (255, 35, 75, int(card_alpha * 0.9)) if i % 2 == 0 else (0, 240, 255, int(card_alpha * 0.9))
            draw.rectangle([bx, eq_y + (26 - bh), bx + bw - 2, eq_y + 26], fill=b_col)

        # Footer Action Text
        if f_idx >= 85:
            foot_text = "► ĐANG MỞ GIAO DIỆN CHÍNH... ◄"
            foot_col = (255, 230, 50, card_alpha)
        else:
            foot_text = "► SẴN SÀNG KÍCH HOẠT MENU ◄"
            foot_col = (0, 255, 140, card_alpha)

        fb = font_mono_bold.getbbox(foot_text)
        draw.text(((WIDTH - (fb[2] - fb[0])) // 2, cy1 - 34), foot_text, fill=foot_col, font=font_mono_bold)

    frame = Image.alpha_composite(frame, overlay)

    # 10. Glitch & Screen Shake on Lock (Frames 42 to 47)
    if 42 <= f_idx <= 47:
        rgb = np.array(frame.convert("RGB"))
        shift = 8 if f_idx % 2 == 0 else -8
        r_chan = np.roll(rgb[:, :, 0], shift, axis=1)
        b_chan = np.roll(rgb[:, :, 2], -shift, axis=1)
        rgb[:, :, 0] = r_chan
        rgb[:, :, 2] = b_chan
        for strip_y in range(120, HEIGHT - 100, 180):
            strip_h = 14
            rgb[strip_y:strip_y + strip_h, :, :] = np.roll(rgb[strip_y:strip_y + strip_h, :, :], shift * 2, axis=1)
        frame = Image.fromarray(rgb).convert("RGBA")

    # 11. Fade In (frames 0 to 10) & Fade Out (frames 98 to 114)
    fade_alpha = 1.0
    if f_idx < 10:
        fade_alpha = f_idx / 10.0
    elif f_idx >= 96:
        fade_alpha = max(0.0, 1.0 - (f_idx - 96) / 18.0)

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
