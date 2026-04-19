import serial
import sys
import os
import struct
import threading
import time

if len(sys.argv) < 2:
    print("Usage: python terminal.py <COM_PORT> [log_file.txt]")
    sys.exit(1)

port = sys.argv[1]
log_file_path = sys.argv[2] if len(sys.argv) > 2 else "computations_log.txt"

print(f"Opening port {port} at 115200 baud...")

try:
    ser = serial.Serial(port, 115200, timeout=0.1)
except Exception as e:
    print(f"Error opening serial port: {e}")
    sys.exit(1)

# Start RX Thread IMMEDIATELY to prevent FTDI buffer overflow!
mute_rx = True

def rx_thread():
    global mute_rx
    with open(log_file_path, 'a', encoding='utf-8') as logf:
        logf.write("\n--- NEW SESSION ---\n")
        while True:
            try:
                data = ser.read(1024)
                if data:
                    # Look for Handshake Trigger (SOH = \x01)
                    if mute_rx and b'\x01' in data:
                        mute_rx = False
                        # Strip everything before and including the \x01 to avoid showing garbage
                        idx = data.find(b'\x01')
                        data = data[idx+1:]
                        if not data: continue

                    if not mute_rx:
                        text = data.decode('utf-8', errors='replace')
                        try:
                            sys.stdout.write(text)
                            sys.stdout.flush()
                        except UnicodeEncodeError:
                            sys.stdout.write(text.encode('ascii', errors='replace').decode('ascii'))
                            sys.stdout.flush()
                        logf.write(text)
                        logf.flush()
            except Exception as e:
                print(f"\n[RX Error: {e}]")
                break

t = threading.Thread(target=rx_thread, daemon=True)
t.start()

# Step 1: Push Bootloader Image
bin_path = "program.bin"
if not os.path.exists(bin_path):
    print(f"Error: {bin_path} not found! Please build first.")
    sys.exit(1)

file_size = os.path.getsize(bin_path)
padded_size = file_size
while padded_size % 4 != 0:
    padded_size += 1

print(f"Loading {bin_path} ({file_size} bytes -> Padded: {padded_size} bytes)...")

# Read the actual file first!
with open(bin_path, 'rb') as f:
    payload = f.read()

# Pad the payload array with zeroes to reach a 4-byte alignment
padding_bytes = padded_size - file_size
if padding_bytes > 0:
    payload += (b'\x00' * padding_bytes)

# Write Header (DEADBEEF)
ser.write(bytes([0xDE, 0xAD, 0xBE, 0xEF]))

# Write Size (Little Endian 32-bit)
ser.write(struct.pack('<I', padded_size))

# Write Payload in chunks to prevent FTDI buffer overflow
chunk_size = 256
for i in range(0, len(payload), chunk_size):
    chunk = payload[i:i+chunk_size]
    ser.write(chunk)
    # Wait 5ms between chunks to let the FPGA bootloader catch up
    time.sleep(0.005)

# Triple-Flush Logic to clear all Reflection Echo
print("Payload dispatched. Synchronizing with hardware...")
time.sleep(0.1)
ser.reset_input_buffer()
time.sleep(0.1)
ser.reset_input_buffer()

print("Dropping into interactive shell...")
print("==========================================================")
print("             FPGA HARDWARE CALCULATOR                     ")
print("==========================================================")
print("Type expressions (e.g. 'add 5.2 3.1')")
print("All log output will be saved to: ", log_file_path)

# TX Thread (Main Thread)
try:
    while True:
        line = sys.stdin.readline()
        if line:
            # Need to send \r to trigger the C parser's newline check
            clean_line = line.strip() + '\r'
            ser.write(clean_line.encode('utf-8'))
except KeyboardInterrupt:
    print("\nExiting...")
    os._exit(0)