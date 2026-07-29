// Copyright 2024 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Hsiao ECC package
// Based in part on work by lowRISC

package hsiao_ecc_pkg;

  function automatic int unsigned min_ecc(int unsigned data_width);
    for (int unsigned i = 0; i < 10; i++) begin
      if (2**i >= data_width + i + 1) begin
        return i + 1;
      end
    end
    // min_ecc = $clog2(data_width)+2;
  endfunction

  /// Static parameters for synthesizability (avoiding dynamic arrays)
  /// Maximum reasonable Data Width
  localparam int unsigned MaxDataWidth = 1024;
  /// Maximum Width for Parity Bits. For DW=1024 12 bits are needed, but more are always allowed.
  /// We limit to 20 for now.
  localparam int unsigned MaxParityWidth = 20;
  /// Maximum total Width (data + parity)
  localparam int unsigned MaxTotalWidth = MaxDataWidth + MaxParityWidth;
  /// Maximum allowed result for n_choose_k to limit excessive array sizes (20 choose 3).
  localparam int unsigned MaxChoose = 1140;

  function automatic int unsigned max_vec(bit [MaxParityWidth-1:0][31:0] vec, int unsigned size);
    max_vec = 0;
    for (int unsigned i = 0; i < size; i++) begin
      max_vec = vec[i] > max_vec ? vec[i] : max_vec;
    end
  endfunction

  function automatic int unsigned min_vec(bit [MaxParityWidth-1:0][31:0] vec, int unsigned size);
    min_vec = vec[0];
    for (int unsigned i = 0; i < size; i++) begin
      min_vec = vec[i] < min_vec ? vec[i] : min_vec;
    end
  endfunction

  function automatic int unsigned factorial(int unsigned i);
    // if (i == 1) begin
    //   factorial = 1;
    // end else begin
    //   factorial = i * factorial(i-1);
    // end
    // return factorial;
    factorial = 1;
    for (int unsigned j = i; j > 0; j--) begin
      factorial = factorial * j;
    end
  endfunction

  function automatic int unsigned n_choose_k(int unsigned n, int unsigned k);
    n_choose_k = factorial(n)/(factorial(k)*factorial(n-k));
  endfunction

  function automatic int unsigned ideal_fanin(int unsigned k, int unsigned m);
    int unsigned fanin = 0;
    int unsigned needed = k;
    for (int unsigned select = 3; select < m+1; select += 2) begin
      int unsigned combinations = n_choose_k(m, select);
      if (combinations <= needed) begin
        fanin += (combinations*select+(m-1))/m; // ceil(combinations*select/m)
        needed -= combinations;
      end else begin
        fanin += (needed*select+(m-1))/m; // ceil(needed*select/m)
        needed = 0;
      end
      if (needed == 0) break;
    end
    return fanin;
  endfunction

  typedef bit [MaxParityWidth-1:0][MaxTotalWidth-1:0] parity_vec_t;
  typedef bit [MaxTotalWidth-1:0][MaxParityWidth-1:0] parity_vec_trans_t;

  /// Function to generate the Hsiao Code Matrix
  /// k: data bits
  /// m: code bits
  ///
  /// Goal is to find an optimal Hsiao Code Matrix:
  ///   | 1 0 0 0 x x x x |
  ///   | 0 1 0 0 x x x x |
  ///   | 0 0 1 0 x x x x |
  ///   | 0 0 0 1 x x x x |
  /// Then message times matrix => original message with parity
  function automatic parity_vec_t hsiao_matrix(int unsigned k, int unsigned m);
    parity_vec_t existing;
    // Packed instead of unpacked: functionally identical (2-state, 32-bit unsigned,
    // small values) but dodges a Verilator 5.040 const-eval ICE on unpacked-array
    // writes inside nested loops (V3Ast.cpp:453 "Adding to non-empty, non-list op1").
    bit [MaxChoose*MaxParityWidth-1:0][31:0] combs;
    int unsigned total_combinations;

    int unsigned needed = k;
    int unsigned max_fanin = ideal_fanin(k, m);
    int unsigned count_index = 0;
    bit comb_added = 0;
    int unsigned tmp_sum = 0;
    // Packed (see combs comment above) to dodge the same Verilator const-eval ICE.
    bit [MaxParityWidth-1:0][31:0] existing_fanins;
    bit [MaxParityWidth-1:0][31:0] tmp_fanins;
    int unsigned min_fanin         = 0;
    int unsigned work_fanin        = 0;
    bit [MaxChoose-1:0] comb_used;

    if (k > MaxDataWidth)
      $fatal(1, "Data Width too large, please adjust package or ECC parameters");
    if (m > MaxParityWidth)
      $fatal(1, "Parity Width too large, please adjust package or ECC parameters");

    for (int unsigned i = 0; i < m; i++) begin
      for (int unsigned j = 0; j < k+m; j++) begin
        existing[i][j] = '0;
      end
    end


    for (int unsigned step = 3; step < m+1; step += 2) begin

      // Calculate combinations
      if (n_choose_k(m, step) > MaxChoose)
        $fatal(1, "Too many combinations, please adjust ECC package MaxChoose");

      for (int unsigned i = 0; i < step; i++) begin
        combs[(0*MaxParityWidth)+i] = i;
      end
      total_combinations = n_choose_k(m, step);
      for (int unsigned i = 1; i < total_combinations; i++) begin
        for (int j = step-1; j >= 0; j--) begin
          if (combs[((i-1)*MaxParityWidth)+j] + step-j < m) begin
            combs[(i*MaxParityWidth)+j] = combs[((i-1)*MaxParityWidth)+j] + 1;
            for (int unsigned k = 0; k < step; k++) begin
              if (k >= j) begin
                combs[(i*MaxParityWidth)+k] = combs[(i*MaxParityWidth)+j] + k-j;
              end else begin
                combs[(i*MaxParityWidth)+k] = combs[((i-1)*MaxParityWidth)+k];
              end
            end
            break;
          end
        end
      end

      if (n_choose_k(m, step) < needed) begin
        // Add all these combinations
        for (int unsigned j = 0; j < n_choose_k(m, step); j++) begin
          for (int unsigned l = 0; l < step; l++) begin
            existing[combs[(j*MaxParityWidth)+l]][count_index] = 1'b1;
          end
          needed--;
          count_index++;
        end
      end else begin
        // Use subset

        for (int unsigned i = 0; i < n_choose_k(m, step); i++) begin
          comb_used[i] = '0;
        end

        while (needed > 0) begin

          for (int unsigned i = 0; i < m; i++) begin
            existing_fanins[i] = 0;
            for (int unsigned j = 0; j < count_index; j++) begin
              if (existing[i][j]) existing_fanins[i]++;
            end
          end

          comb_added = 0;

          min_fanin = min_vec(existing_fanins, m);

          // First add to increase minimum while keeping max low
          for (int unsigned i = 0; i < n_choose_k(m, step); i++) begin
            if (comb_used[i]) continue;

            for (int unsigned i = 0; i < m; i++) begin
              tmp_fanins[i] = existing_fanins[i];
            end

            for (int unsigned l = 0; l < step; l++) begin
              tmp_fanins[combs[(i*MaxParityWidth)+l]]++;
            end

            if (min_vec(tmp_fanins, m) > min_fanin && max_vec(tmp_fanins, m) <= work_fanin) begin
              comb_added = 1;
              for (int unsigned l = 0; l < step; l++) begin
                existing[combs[(i*MaxParityWidth)+l]][count_index] = 1'b1;
              end
              comb_used[i] = 1;
              needed--;
              count_index++;
              break;
            end
          end

          if (comb_added) continue;

          // Then add to increase maximum if previous did not work
          for (int unsigned i = 0; i < n_choose_k(m, step); i++) begin
            if (comb_used[i]) continue;

            for (int unsigned i = 0; i < m; i++) begin
              tmp_fanins[i] = existing_fanins[i];
            end

            for (int unsigned l = 0; l < step; l++) begin
              tmp_fanins[combs[(i*MaxParityWidth)+l]]++;
            end

            if (max_vec(tmp_fanins, m) <= work_fanin) begin
              comb_added = 1;
              for (int unsigned l = 0; l < step; l++) begin
                existing[combs[(i*MaxParityWidth)+l]][count_index] = 1'b1;
              end
              comb_used[i] = 1;
              needed--;
              count_index++;
              break;
            end
          end

          if (!comb_added) begin
            work_fanin += 1;
          end
        end
        break;
      end
    end

    if (count_index != k) $error("did not fill all parity bits!");

    for (int unsigned i = 0; i < m; i++) begin
      existing[i][k+i] = 1'b1;
    end

    hsiao_matrix = existing;
  endfunction

  function automatic parity_vec_trans_t transpose(
    parity_vec_t matrix,
    int unsigned m,
    int unsigned n
  );
    for (int unsigned i = 0; i < m; i++) begin
      for (int unsigned j = 0; j < n; j++) begin
        transpose[j][i] = matrix[i][j];
      end
    end
  endfunction

endpackage
