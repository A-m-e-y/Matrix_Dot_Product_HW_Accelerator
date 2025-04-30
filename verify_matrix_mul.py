import struct

def hex_to_float(hex_str):
    return struct.unpack('!f', bytes.fromhex(hex_str))[0]

def parse_matrix_dump(filename):
    with open(filename, 'r') as f:
        lines = [line.strip() for line in f.readlines() if line.strip()]

    idx = 0
    matrices = {}

    M, K = map(int, lines[idx].replace('M:', '').replace('K:', '').split(','))
    idx += 1
    A = [hex_to_float(lines[idx + i]) for i in range(M * K)]
    idx += M * K
    matrices['A'] = (M, K, A)

    K2, N = map(int, lines[idx].replace('K:', '').replace('N:', '').split(','))
    idx += 1
    B = [hex_to_float(lines[idx + i]) for i in range(K * N)]
    idx += K * N
    matrices['B'] = (K, N, B)

    M2, N2 = map(int, lines[idx].replace('M:', '').replace('N:', '').split(','))
    idx += 1
    C = [hex_to_float(lines[idx + i]) for i in range(M * N)]
    matrices['C'] = (M, N, C)

    return matrices

def matmul(A, B, M, K, N):
    result = []
    for i in range(M):
        for j in range(N):
            acc = 0.0
            for k in range(K):
                acc += A[i*K + k] * B[k*N + j]
            result.append(acc)
    return result

def print_matrix(data, rows, cols, label):
    print(f"\n{label} ({rows}x{cols}):")
    for i in range(rows):
        row = data[i*cols:(i+1)*cols]
        print("  " + "  ".join(f"{x:8.3f}" for x in row))

def compare_results(sw_C, dut_C, M, N):
    print(f"\n{'='*40}\nComparing DUT vs SW result:")
    passed = True
    for i in range(M):
        for j in range(N):
            idx = i * N + j
            sw_val = sw_C[idx]
            dut_val = dut_C[idx]
            match = abs(sw_val - dut_val) < 1e-3
            result_str = "✅" if match else "❌"
            if not match:
                passed = False
            print(f"C[{i}][{j}] => DUT: {dut_val:.6f} | SW: {sw_val:.6f} --> {result_str}")
    print("✅ ALL PASS" if passed else "❌ MISMATCH DETECTED")
    return passed

if __name__ == "__main__":
    matrices = parse_matrix_dump("matrix_result_dump.txt")
    M, K, A = matrices['A']
    K, N, B = matrices['B']
    M, N, C = matrices['C']

    sw_C = matmul(A, B, M, K, N)

    print_matrix(A, M, K, "Matrix A")
    print_matrix(B, K, N, "Matrix B")
    print_matrix(C, M, N, "Matrix C (DUT)")
    print_matrix(sw_C, M, N, "Matrix C (Software)")

    compare_results(sw_C, C, M, N)
