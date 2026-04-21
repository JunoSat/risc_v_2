import math

lut = []
for i in range(32):
    val = int(round(math.atan(2**-i) * (2**28)))
    lut.append(f"            5'd{i:02}: atan_lut_val = 32'h{val:08X};")

with open("lut.txt", "w") as f:
    f.write("\n".join(lut))
