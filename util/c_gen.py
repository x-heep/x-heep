# Write a C header file with array definitions for the input matrix, the output
# matrix, and the instruction stream.

import os
import sys
import numpy as np


class CFileGen:
    """
    A class for generating C code files containing binary data, matrices, and code.

    Attributes:
        binaries (List[Tuple[str, str]]): A list of binary files to dump in the generated C file.
        codes (List[Tuple[str, np.ndarray]]): A list of commands or instruction sequences to include in the generated C file.
        input_matrices (List[Tuple[str, np.ndarray]]): A list of input matrices to include in the generated C file.
        output_matrices (List[Tuple[str, np.ndarray]]): A list of output matrices to include in the generated C file.
        macros (List[Tuple[str, int, Optional[str]]]): A list of macros to include in the generated C file.
        macros_hex (List[Tuple[str, str, Optional[str]]]): A list of string macros to include in the generated C file (e.g., hex values).
        macros_raw (List[Tuple[str, str, Optional[str]]]): A list of macros in raw format to include in the generated C file.
        attributes (List[str]): A list of C attributes to apply to the generated C arrays.
    """

    def __init__(self) -> None:
        self.binaries = []
        self.codes = []
        self.input_matrices = []
        self.output_matrices = []
        self.macros = []
        self.macros_hex = []
        self.macros_raw = []
        self.attributes = []
        self.storage_class = ""

    # Add a new binary file
    def add_binary(
        self, name: str, file: str, prefix_pad: int = 0, suffix_pad: int = 0
    ) -> None:
        if prefix_pad < 0 or suffix_pad < 0:
            raise ValueError("prefix_pad and suffix_pad must be non-negative")
        self.binaries.append((name, file, prefix_pad, suffix_pad))

    # Add a new list of commands
    def add_code(self, name: str, matrix: np.ndarray) -> None:
        self.codes.append((name, matrix))

    # Add a new input matrix definition
    def add_input_matrix(self, name: str, matrix: np.ndarray) -> None:
        self.input_matrices.append((name, matrix))

    # Add a new output matrix definition
    def add_output_matrix(self, name: str, matrix: np.ndarray) -> None:
        self.output_matrices.append((name, matrix))

    # Add a macro
    def add_macro(self, name: str, value: int, comment: str = None) -> None:
        self.macros.append((name, value, comment))

    def add_macro_hex(self, name: str, value: str, comment: str = None) -> None:
        self.macros_hex.append((name, value, comment))

    def add_macro_raw(self, name: str) -> None:
        self.macros_raw.append(name)

    def add_macros_from_source(self, src_file: str) -> None:
        # Open source file and parse macros
        with open(src_file, "r") as src:
            for line in src:
                if line.startswith("#define"):
                    self.add_macro_raw(line)

    # Define variable attributes
    def add_attribute(self, value: str) -> None:
        self.attributes.append(value)

    def set_storage_class(self, value: str) -> None:
        self.storage_class = value.strip()

    def format_array_decl(self, base_type: str, name: str) -> str:
        parts = []
        if self.storage_class:
            parts.append(self.storage_class)
        parts.append(base_type)
        declaration = " ".join(parts)
        if len(self.attributes) > 0:
            declaration += f" __attribute__(({','.join(self.attributes)}))"
        declaration += f" {name}"
        return declaration

    # Convert signed dtype to unsigned dtype
    def signed2unsigned(self, dtype: np.dtype) -> np.dtype:
        return {
            "int8": np.uint8,
            "int16": np.uint16,
            "int32": np.uint32,
        }[str(dtype)]

    # Convert numpy dtype to C type
    def dtype_to_ctype(self, dtype: np.dtype) -> str:
        return {
            "int8": "int8_t",
            "int16": "int16_t",
            "int32": "int32_t",
            "uint8": "uint8_t",
            "uint16": "uint16_t",
            "uint32": "uint32_t",
        }[str(dtype)]

    # Format binary file content as C array
    def format_binary(
        self, name: str, file: str, prefix_pad: int = 0, suffix_pad: int = 0
    ) -> str:
        # Read binary file
        with open(file, "rb") as f:
            content = f.read()

        if prefix_pad > 0:
            content = (b"\x00" * prefix_pad) + content
        if suffix_pad > 0:
            content += b"\x00" * suffix_pad

        # Pad data to 4-byte alignment (possibly zero padding)
        data_len = len(content) // 4
        if len(content) % 4 != 0:
            data_len += 1
            content += b"\x00" * (4 - (len(content) % 4))

        # Write C data content
        declaration = self.format_array_decl("uint32_t", f"{name}[]")
        array_contents = f"{declaration} = {{\n"
        for i in range(data_len):
            element = int.from_bytes(content[i * 4 : (i + 1) * 4], byteorder="little")
            array_contents += f"    0x{element:08X}"
            if i != data_len - 1:
                array_contents += ",\n"
        array_contents += "\n};\n"
        return array_contents

    # Format matrix size macros
    def format_matrix_size(self, matrix: np.ndarray, name: str) -> str:
        size_contents = f"#define {name.upper()}_SIZE {matrix.size * matrix.itemsize}\n"
        size_contents += f"#define {name.upper()}_ROWS {matrix.shape[0]}\n"
        size_contents += f"#define {name.upper()}_COLS {matrix.shape[1] if len(matrix.shape) > 1 else 1}\n"
        return size_contents

    # Format code size macros
    def format_code_size(self, code: str, name: str) -> str:
        size_contents = f"#define {name.upper()}_SIZE {len(code)*4}\n"
        return size_contents

    # Format matrix for C
    def format_matrix(self, matrix: np.ndarray, name: str) -> str:
        # Determine the number of bits based on the dtype
        dtype: np.dtype = matrix.dtype
        num_bits = dtype.itemsize * 8

        array_ctype = self.dtype_to_ctype(dtype)
        utype = self.signed2unsigned(dtype)
        matrix = matrix.astype(utype)

        # Convert the signed array to 2's complement hexadecimal values
        rows = []
        for row in matrix:
            hex_values = [f"{element:#0{2+num_bits//4}x}" for element in row]
            rows.append(hex_values)

        # Format the matrix
        declaration = self.format_array_decl(array_ctype, f"{name} []")
        matrix_contents = f"{declaration} = {{\n"
        if len(rows) > 1:
            matrix_contents += ",\n".join([f"    {', '.join(row)}" for row in rows])
        else:
            matrix_contents += f"    {', '.join(rows[0])}"
        matrix_contents += "\n};\n\n"

        return matrix_contents

    def format_code(self, code: str, name: str) -> str:
        # Format the array
        declaration = self.format_array_decl("uint32_t", f"{name}[]")
        code_contents = f"{declaration} = {{"
        for i, insn in enumerate(code):
            if i % 8 == 0:
                code_contents += "\n    "
            code_contents += f"{insn:>10}"
            if i < len(code) - 1:
                code_contents += ", "
        code_contents += "\n};\n"
        return code_contents

    # Write the header file
    def gen_header(self, header_macro: str = None) -> str:
        if header_macro is not None:
            # Header guard
            header_contents = f"#ifndef {header_macro}\n#define {header_macro}\n\n"
            # Include stdint.h
            header_contents += "#include <stdint.h>\n\n"

        # Macros
        if len(self.macros) > 0 or len(self.macros_hex) > 0 or len(self.macros_raw) > 0:
            header_contents += "// Macros\n"
            header_contents += "// ------\n"
        for name, value, comment in self.macros:
            header_contents += f"#define {name.upper()} {value}"
            if comment is not None:
                header_contents += f" // {comment}\n"
            else:
                header_contents += "\n"
        for name, value, comment in self.macros_hex:
            header_contents += f"#define {name.upper()} 0x{value:08X}"
            if comment is not None:
                header_contents += f" // {comment}\n"
            else:
                header_contents += "\n"
        for name in self.macros_raw:
            header_contents += name
        if len(self.macros) > 0 or len(self.macros_hex) > 0 or len(self.macros_raw) > 0:
            header_contents += "\n"

        # Macros with array sizes
        if len(self.binaries) > 0:
            header_contents += "// Binary size\n"
            header_contents += "// -----------\n"
            for name, file, prefix_pad, suffix_pad in self.binaries:
                file_size = os.path.getsize(file) + prefix_pad + suffix_pad
                if file_size % 4 != 0:
                    file_size += 4 - (file_size % 4)
                header_contents += f"#define {name.upper()}_SIZE {file_size}\n"
            header_contents += "\n"

        if len(self.input_matrices) > 0:
            header_contents += "// Input matrix size\n"
            for name, matrix in self.input_matrices:
                header_contents += self.format_matrix_size(matrix, name)
            header_contents += "\n"

        if len(self.output_matrices) > 0:
            header_contents += "// Output matrix size\n"
            for name, matrix in self.output_matrices:
                header_contents += self.format_matrix_size(matrix, name)
            header_contents += "\n"

        if len(self.codes) > 0:
            header_contents += "// Code size\n"
            for name, code in self.codes:
                header_contents += self.format_code_size(code, name)
            header_contents += "\n"

        # Write binary files
        if len(self.binaries) > 0:
            header_contents += "// Binary files\n"
            header_contents += "// ------------\n"
            for name, file, prefix_pad, suffix_pad in self.binaries:
                header_contents += self.format_binary(
                    name, file, prefix_pad, suffix_pad
                )
            header_contents += "\n"

        # Write code arrays
        if len(self.codes) > 0:
            header_contents += "// Code\n"
            header_contents += "// ----\n"
            for name, code in self.codes:
                header_contents += self.format_code(code, name)
            header_contents += "\n"

        # Write input matrices
        if len(self.input_matrices) > 0:
            header_contents += "// Input matrices\n"
            header_contents += "// --------------\n"
            for name, matrix in self.input_matrices:
                header_contents += self.format_matrix(matrix, name)

        # Write output matrices
        if len(self.output_matrices) > 0:
            header_contents += "// Output matrices\n"
            header_contents += "// ---------------\n"
            for name, matrix in self.output_matrices:
                header_contents += self.format_matrix(matrix, name)

        if header_macro is not None:
            header_contents += f"#endif // {header_macro}\n"

        # Return the header contents
        return header_contents

    def write_header(self, directory: str, file_name: str) -> None:
        # Header file path
        header_path = os.path.join(directory, file_name)
        header_base = os.path.basename(header_path)
        header_macro = header_base.upper().replace(".", "_") + "_"

        # Generate header
        header_contents = self.gen_header(header_macro)

        # Write header file
        with open(header_path, "w") as header_file:
            header_file.write(header_contents)

    def append_header(self, file, header_macro: str = None):
        # Generate header
        header_contents = self.gen_header(header_macro)

        # Write header file
        file.write(header_contents)


# When launched as a standalone script, convert a binary file (e.g., compiled firmware) into a C header
if __name__ == "__main__":
    # Check the number of arguments
    if len(sys.argv) < 3:
        print(
            "Usage: python c_gen.py <header_file> <bin_file> [--prefix-pad <bytes>] [--prefix-pad=<bytes>] [--suffix-pad <bytes>] [--suffix-pad=<bytes>] [--static] [--attribute <attr>] [--attribute=<attr>] [<src_file> ...]"
        )
        sys.exit(1)

    # Parse required arguments
    header_file = sys.argv[1]
    bin_file = sys.argv[2]
    prefix_pad = 0
    attributes = []
    storage_class = ""
    src_files = []
    suffix_pad = 0

    # Parse optional arguments
    remaining_args = sys.argv[3:]
    i = 0
    while i < len(remaining_args):
        arg = remaining_args[i]
        if arg.startswith("--prefix-pad="):
            value = arg.split("=", 1)[1]
            try:
                prefix_pad = int(value, 0)
            except ValueError:
                print(f"Invalid value for --prefix-pad: '{value}'")
                sys.exit(1)
        elif arg == "--prefix-pad":
            if i + 1 >= len(remaining_args):
                print("Missing value for --prefix-pad")
                sys.exit(1)
            value = remaining_args[i + 1]
            try:
                prefix_pad = int(value, 0)
            except ValueError:
                print(f"Invalid value for --prefix-pad: '{value}'")
                sys.exit(1)
            i += 1
        elif arg.startswith("--attribute="):
            attributes.append(arg.split("=", 1)[1])
        elif arg == "--attribute":
            if i + 1 >= len(remaining_args):
                print("Missing value for --attribute")
                sys.exit(1)
            attributes.append(remaining_args[i + 1])
            i += 1
        elif arg.startswith("--suffix-pad="):
            value = arg.split("=", 1)[1]
            try:
                suffix_pad = int(value, 0)
            except ValueError:
                print(f"Invalid value for --suffix-pad: '{value}'")
                sys.exit(1)
        elif arg == "--suffix-pad":
            if i + 1 >= len(remaining_args):
                print("Missing value for --suffix-pad")
                sys.exit(1)
            value = remaining_args[i + 1]
            try:
                suffix_pad = int(value, 0)
            except ValueError:
                print(f"Invalid value for --suffix-pad: '{value}'")
                sys.exit(1)
            i += 1
        elif arg == "--static":
            storage_class = "static"
        else:
            src_files.append(arg)
        i += 1

    if prefix_pad < 0:
        print("Value for --prefix-pad must be non-negative")
        sys.exit(1)
    if suffix_pad < 0:
        print("Value for --suffix-pad must be non-negative")
        sys.exit(1)

    # Determine kernel name
    header_name = os.path.splitext(os.path.basename(header_file))[0]
    out_dir = os.path.dirname(header_file)
    header_file = f"{header_name}.h"

    # Generate C header from input binary file
    header_gen = CFileGen()
    if storage_class:
        header_gen.set_storage_class(storage_class)
    for attribute in attributes:
        header_gen.add_attribute(attribute)
    header_gen.add_binary(header_name, bin_file, prefix_pad, suffix_pad)

    # Extract #define's from source file (e.g., the file that the firmware was compiled from)
    for src_file in src_files:
        print(f"Adding macros from source file '{src_file}'...")
        header_gen.add_macros_from_source(src_file)

    # Write header file
    print(f"Writing header file '{os.path.join(out_dir, header_file)}'...")
    header_gen.write_header(out_dir, header_file)
