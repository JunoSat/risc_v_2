import serial
import sys
import os
import struct
import threading

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

# Write Header (DEADBEEF)
ser.write(bytes([0xDE, 0xAD, 0xBE, 0xEF]))
# Write Size (Little Endian 32-bit)
ser.write(struct.pack('<I', padded_size))

# Write Payload in chunks to prevent FTDI buffer overflow
import time
with open(bin_path, 'rb') as f:
    payload = f.read()
    payload += bytes(padded_size - file_size) # Pack empty zeros
    
    # Send in 256-byte chunks with a tiny delay
    chunk_size = 256
    for i in range(0, len(payload), chunk_size):
        chunk = payload[i:i+chunk_size]
        ser.write(chunk)
        # Wait 5ms between chunks
        time.sleep(0.005)

print("✅ Payload dispatched successfully. Dropping into interactive shell...")
print("==========================================================")
print("             FPGA HARDWARE CALCULATOR                     ")
print("==========================================================")
print("Type expressions (e.g. 'add 5.2 3.1')")
print("All log output will be saved to: ", log_file_path)

# Step 2: Interactive Terminal + Logger
def rx_thread():
    with open(log_file_path, 'a') as logf:
        logf.write("\n--- NEW SESSION ---\n")
        while True:
            try:
                data = ser.read(1024)
                if data:
                    text = data.decode('utf-8', errors='replace')
                    sys.stdout.write(text)
                    sys.stdout.flush()
                    logf.write(text)
                    logf.flush()
            except Exception as e:
                print(f"\n[RX Error: {e}]")
                break

t = threading.Thread(target=rx_thread, daemon=True)
t.start()

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
finally:
    ser.close()
