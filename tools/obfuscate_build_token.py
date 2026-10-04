import os
import sys
import re
import random

target_file = os.path.join(os.path.dirname(__file__), "..", "AppNew", "ThreeOneOSFive", "helpers", "IntegrityChecker.swift")
target_file = os.path.abspath(target_file)

def generate_key(length=16):
    return [random.randint(0x10, 0xEF) for _ in range(length)]

def xor_encode(text, key):
    raw = text.encode("utf-8")
    return [raw[i] ^ key[i % len(key)] for i in range(len(raw))]

def xor_decode(enc_bytes, key):
    raw = bytes([enc_bytes[i] ^ key[i % len(key)] for i in range(len(enc_bytes))])
    return raw.decode("utf-8", errors="ignore")

def format_hex_array(arr, indent=8):
    lines = []
    chunk_size = 8
    indent_str = " " * indent
    for i in range(0, len(arr), chunk_size):
        chunk = arr[i:i + chunk_size]
        lines.append(indent_str + ", ".join(f"0x{b:02X}" for b in chunk))
    return "[\n" + ",\n".join(lines) + "\n" + (" " * (indent - 4)) + "]"

def extract_hex_list(text_block):
    matches = re.findall(r'0x[0-9a-fA-F]+', text_block)
    return [int(x, 16) for x in matches]

def main():
    if not os.path.exists(target_file):
        print(f"Error: Could not find {target_file}")
        sys.exit(1)

    with open(target_file, "r", encoding="utf-8") as f:
        content = f.read()

    # Mode 1: Restore sourceBuildToken from obfuscated bytes
    if "--restore" in sys.argv:
        m_bytes = re.search(r'private static let buildTokenBytes:\s*\[UInt8\]\s*=\s*\[(.*?)\]', content, re.DOTALL)
        m_key = re.search(r'private static let buildTokenKey:\s*\[UInt8\]\s*=\s*\[(.*?)\]', content, re.DOTALL)
        if not m_bytes or not m_key:
            print("Error: Could not find buildTokenBytes or buildTokenKey in IntegrityChecker.swift")
            sys.exit(1)
        b_list = extract_hex_list(m_bytes.group(1))
        k_list = extract_hex_list(m_key.group(1))
        if not b_list or not k_list:
            print("Error: Empty buildTokenBytes or buildTokenKey.")
            sys.exit(1)
        decoded = xor_decode(b_list, k_list)
        print(f"Decoded token from bytes: '{decoded}'")
        content = re.sub(r'sourceBuildToken\s*:\s*String\s*=\s*"[^"]*"', f'sourceBuildToken: String = "{decoded}"', content)
        with open(target_file, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Successfully restored sourceBuildToken = \"{decoded}\" in {target_file}")
        return

    # Mode 2: Obfuscate (Dev or Release)
    # Determine token: from cli argument or extract sourceBuildToken
    token = None
    for arg in sys.argv[1:]:
        if not arg.startswith("--"):
            token = arg.strip()
            break

    if not token:
        m = re.search(r'sourceBuildToken\s*:\s*String\s*=\s*"([^"]+)"', content)
        if m:
            token = m.group(1).strip()
        else:
            # Fallback to decode existing bytes if sourceBuildToken is empty
            m_bytes = re.search(r'private static let buildTokenBytes:\s*\[UInt8\]\s*=\s*\[(.*?)\]', content, re.DOTALL)
            m_key = re.search(r'private static let buildTokenKey:\s*\[UInt8\]\s*=\s*\[(.*?)\]', content, re.DOTALL)
            if m_bytes and m_key:
                b_list = extract_hex_list(m_bytes.group(1))
                k_list = extract_hex_list(m_key.group(1))
                if b_list and k_list:
                    token = xor_decode(b_list, k_list)

    if not token:
        print("Error: Could not determine token to obfuscate.")
        sys.exit(1)

    print(f"Obfuscating Build Token: '{token}'")
    key = generate_key(16)
    enc_bytes = xor_encode(token, key)

    key_formatted = format_hex_array(key)
    bytes_formatted = format_hex_array(enc_bytes)

    # Replace buildTokenBytes and buildTokenKey in file
    bytes_pattern = r'private static let buildTokenBytes:\s*\[UInt8\]\s*=\s*\[.*?\]'
    key_pattern = r'private static let buildTokenKey:\s*\[UInt8\]\s*=\s*\[.*?\]'

    content = re.sub(bytes_pattern, f'private static let buildTokenBytes: [UInt8] = {bytes_formatted}', content, flags=re.DOTALL)
    content = re.sub(key_pattern, f'private static let buildTokenKey: [UInt8] = {key_formatted}', content, flags=re.DOTALL)

    if "--release" in sys.argv:
        # Blank the plaintext token for production release binary
        content = re.sub(r'sourceBuildToken\s*:\s*String\s*=\s*"[^"]*"', 'sourceBuildToken: String = ""', content)
        print("Release mode (--release): Cleared sourceBuildToken plaintext from source code.")
    else:
        # Keep or update sourceBuildToken
        content = re.sub(r'sourceBuildToken\s*:\s*String\s*=\s*"[^"]*"', f'sourceBuildToken: String = "{token}"', content)
        print(f"Dev mode: Preserved sourceBuildToken = \"{token}\".")

    with open(target_file, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Successfully updated {target_file} with obfuscated bytes for token: {token}")

if __name__ == "__main__":
    main()
