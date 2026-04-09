import sys
import time

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("pyserial not installed")
    sys.exit(1)

ports = serial.tools.list_ports.comports()
print("Found ports:")
for port, desc, hwid in sorted(ports):
    print(f"{port}: {desc} [{hwid}]")

def try_read_port(port_name):
    print(f"\\n--- Trying to read from {port_name} at 115200 baud ---")
    try:
        ser = serial.Serial(port_name, 115200, timeout=1)
        print(f"Successfully opened {port_name}. Reading for 2 seconds...")
        
        start_time = time.time()
        read_data = b''
        while time.time() - start_time < 2:
            if ser.in_waiting > 0:
                chunk = ser.read(ser.in_waiting)
                read_data += chunk
                
        ser.close()
        
        if len(read_data) > 0:
            print(f"SUCCESS! Read {len(read_data)} bytes from {port_name}.")
            print("Preview of data:")
            print(read_data[:100])
        else:
            print(f"No data received on {port_name}.")
            
    except Exception as e:
        print(f"Failed to open {port_name}: {e}")

for port, _, _ in sorted(ports):
    try_read_port(port)

