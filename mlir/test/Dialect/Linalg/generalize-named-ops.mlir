// RUN: mlir-opt %s -split-input-file -linalg-generalize-named-ops | FileCheck %s

func.func @generalize_matmul_buffer(%A : memref<16x8xf32>, %B: memref<8x32xf32>, %C: memref<16x32xf32>) {
  linalg.matmul ins(%A, %B: memref<16x8xf32>, memref<8x32xf32>)
               outs(%C: memref<16x32xf32>)
  return
}


// CHECK: #[[A_MAP:.+]] = affine_map<(d0, d1, d2) -> (d0, d2)>
// CHECK: #[[B_MAP:.+]] = affine_map<(d0, d1, d2) -> (d2, d1)>
// CHECK: #[[C_MAP:.+]] = affine_map<(d0, d1, d2) -> (d0, d1)>

// CHECK: func @generalize_matmul_buffer
// CHECK-SAME: %[[A:.+]]: memref<16x8xf32>
// CHECK-SAME: %[[B:.+]]: memref<8x32xf32>
// CHECK-SAME: %[[C:.+]]: memref<16x32xf32>

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[A_MAP]], #[[B_MAP]], #[[C_MAP]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "reduction"]
// CHECK-SAME:  ins(%[[A]], %[[B]]
// CHECK-SAME: outs(%[[C]]

// CHECK: ^{{.*}}(%[[A_ARG:.+]]: f32, %[[B_ARG:.+]]: f32, %[[C_ARG:.+]]: f32)
// CHECK:   %[[MUL:.+]] = arith.mulf %[[A_ARG]], %[[B_ARG]] : f32
// CHECK:   %[[ADD:.+]] = arith.addf %[[C_ARG]], %[[MUL]] : f32
// CHECK:   linalg.yield %[[ADD]] : f32

// -----

func.func @generalize_matmul_tensor(%A : tensor<16x8xf32>, %B: tensor<8x32xf32>, %C: tensor<16x32xf32>) -> tensor<16x32xf32> {
  %0 = linalg.matmul ins(%A, %B: tensor<16x8xf32>, tensor<8x32xf32>)
                    outs(%C: tensor<16x32xf32>) -> tensor<16x32xf32>
  return %0: tensor<16x32xf32>
}

// CHECK: func @generalize_matmul_tensor

// CHECK: linalg.generic
// CHECK-SAME:  ins(%{{.+}}, %{{.+}} : tensor<16x8xf32>, tensor<8x32xf32>)
// CHECK-SAME: outs(%{{.+}} : tensor<16x32xf32>)

// CHECK:      ^{{.*}}(%[[A_ARG:.+]]: f32, %[[B_ARG:.+]]: f32, %[[C_ARG:.+]]: f32)
// CHECK-NEXT:   %[[MUL:.+]] = arith.mulf %[[A_ARG]], %[[B_ARG]] : f32
// CHECK-NEXT:   %[[ADD:.+]] = arith.addf %[[C_ARG]], %[[MUL]] : f32
// CHECK-NEXT:   linalg.yield %[[ADD]] : f32
// CHECK-NEXT: -> tensor<16x32xf32>

// -----

func.func @generalize_matmul_tensor_complex(%A : tensor<16x8xcomplex<f32>>,
                                            %B: tensor<8x32xcomplex<f32>>,
                                            %C: tensor<16x32xcomplex<f32>>)
          -> tensor<16x32xcomplex<f32>> {
  %0 = linalg.matmul ins(%A, %B: tensor<16x8xcomplex<f32>>, tensor<8x32xcomplex<f32>>)
                    outs(%C: tensor<16x32xcomplex<f32>>) -> tensor<16x32xcomplex<f32>>
  return %0: tensor<16x32xcomplex<f32>>
}

// CHECK: func @generalize_matmul_tensor_complex

// CHECK: linalg.generic
// CHECK-SAME:  ins(%{{.+}}, %{{.+}} : tensor<16x8xcomplex<f32>>, tensor<8x32xcomplex<f32>>)
// CHECK-SAME: outs(%{{.+}} : tensor<16x32xcomplex<f32>>)

// CHECK:      ^{{.*}}(%[[A_ARG:.+]]: complex<f32>, %[[B_ARG:.+]]: complex<f32>, %[[C_ARG:.+]]: complex<f32>)
// CHECK-NEXT:   %[[MUL:.+]] = complex.mul %[[A_ARG]], %[[B_ARG]] : complex<f32>
// CHECK-NEXT:   %[[ADD:.+]] = complex.add %[[C_ARG]], %[[MUL]] : complex<f32>
// CHECK-NEXT:   linalg.yield %[[ADD]] : complex<f32>
// CHECK-NEXT: -> tensor<16x32xcomplex<f32>>

// -----

func.func @depthwise_conv_2d_nhwc_hwcm(%input: memref<2x4x5x2xf32>, %filter: memref<2x2x2x3xf32>, %output: memref<2x3x4x2x3xf32>) {
  linalg.depthwise_conv_2d_nhwc_hwcm
     { dilations = dense<1> : tensor<2xi64>, strides = dense<1> : tensor<2xi64> }
     ins(%input, %filter : memref<2x4x5x2xf32>, memref<2x2x2x3xf32>)
    outs(%output : memref<2x3x4x2x3xf32>)
  return
}

// CHECK-DAG: #[[MAP0:.+]] = affine_map<(d0, d1, d2, d3, d4, d5, d6) -> (d0, d1 + d5, d2 + d6, d3)>
// CHECK-DAG: #[[MAP1:.+]] = affine_map<(d0, d1, d2, d3, d4, d5, d6) -> (d5, d6, d3, d4)>
// CHECK-DAG: #[[MAP2:.+]] = affine_map<(d0, d1, d2, d3, d4, d5, d6) -> (d0, d1, d2, d3, d4)>

// CHECK: func @depthwise_conv_2d_nhwc_hwcm

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP0]], #[[MAP1]], #[[MAP2]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel", "parallel", "parallel", "reduction", "reduction"]}
// CHECK-SAME: ins(%{{.+}}, %{{.+}} : memref<2x4x5x2xf32>, memref<2x2x2x3xf32>)
// CHECK-SAME: outs(%{{.+}} : memref<2x3x4x2x3xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK-NEXT:      %[[MUL:.+]] = arith.mulf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK-NEXT:      %[[ADD:.+]] = arith.addf %[[BBARG2]], %[[MUL]] : f32
// CHECK-NEXT:      linalg.yield %[[ADD]] : f32

// -----

func.func @depthwise_conv_2d_nhwc_hwcm(%input: memref<2x4x5x2xf32>, %filter: memref<2x2x2x3xf32>, %output: memref<2x2x3x2x3xf32>) {
  linalg.depthwise_conv_2d_nhwc_hwcm
     { dilations = dense<2> : tensor<2xi64>, strides = dense<1> : tensor<2xi64> }
     ins(%input, %filter : memref<2x4x5x2xf32>, memref<2x2x2x3xf32>)
    outs(%output : memref<2x2x3x2x3xf32>)
  return
}

// CHECK-DAG: #[[MAP0:.+]] = affine_map<(d0, d1, d2, d3, d4, d5, d6) -> (d0, d1 + d5 * 2, d2 + d6 * 2, d3)>
// CHECK-DAG: #[[MAP1:.+]] = affine_map<(d0, d1, d2, d3, d4, d5, d6) -> (d5, d6, d3, d4)>
// CHECK-DAG: #[[MAP2:.+]] = affine_map<(d0, d1, d2, d3, d4, d5, d6) -> (d0, d1, d2, d3, d4)>

// CHECK: func @depthwise_conv_2d_nhwc_hwcm

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP0]], #[[MAP1]], #[[MAP2]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel", "parallel", "parallel", "reduction", "reduction"]}
// CHECK-SAME: ins(%{{.+}}, %{{.+}} : memref<2x4x5x2xf32>, memref<2x2x2x3xf32>)
// CHECK-SAME: outs(%{{.+}} : memref<2x2x3x2x3xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK-NEXT:      %[[MUL:.+]] = arith.mulf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK-NEXT:      %[[ADD:.+]] = arith.addf %[[BBARG2]], %[[MUL]] : f32
// CHECK-NEXT:      linalg.yield %[[ADD]] : f32

// -----

func.func @depthwise_conv_2d_nhwc_hwc(%input: memref<1x113x113x96xf32>, %filter: memref<3x3x96xf32>, %output: memref<1x56x56x96xf32>) {
  linalg.depthwise_conv_2d_nhwc_hwc {dilations = dense<1> : vector<2xi64>, strides = dense<2> : vector<2xi64>}
    ins(%input, %filter: memref<1x113x113x96xf32>, memref<3x3x96xf32>)
    outs(%output: memref<1x56x56x96xf32>)
  return
}

// CHECK-DAG: #[[MAP0:.+]] = affine_map<(d0, d1, d2, d3, d4, d5) -> (d0, d1 * 2 + d4, d2 * 2 + d5, d3)>
// CHECK-DAG: #[[MAP1:.+]] = affine_map<(d0, d1, d2, d3, d4, d5) -> (d4, d5, d3)>
// CHECK-DAG: #[[MAP2:.+]] = affine_map<(d0, d1, d2, d3, d4, d5) -> (d0, d1, d2, d3)>

// CHECK: func @depthwise_conv_2d_nhwc_hwc

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP0]], #[[MAP1]], #[[MAP2]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel", "parallel", "reduction", "reduction"]}
// CHECK-SAME: ins(%{{.+}}, %{{.+}} : memref<1x113x113x96xf32>, memref<3x3x96xf32>)
// CHECK-SAME: outs(%{{.+}} : memref<1x56x56x96xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK-NEXT:      %[[MUL:.+]] = arith.mulf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK-NEXT:      %[[ADD:.+]] = arith.addf %[[BBARG2]], %[[MUL]] : f32
// CHECK-NEXT:      linalg.yield %[[ADD]] : f32

// -----

func.func @conv_1d_nwc_wcf(%input: memref<?x?x?xf32>, %filter: memref<?x?x?xf32>, %output: memref<?x?x?xf32>) {
  linalg.conv_1d_nwc_wcf {dilations = dense<1> : tensor<1xi64>,
                                       strides = dense<1> : tensor<1xi64>}
     ins (%input, %filter: memref<?x?x?xf32>, memref<?x?x?xf32>)
    outs (%output: memref<?x?x?xf32>)
  return
}
// CHECK-DAG: #[[MAP0:.+]] = affine_map<(d0, d1, d2, d3, d4) -> (d0, d1 + d3, d4)>
// CHECK-DAG: #[[MAP1:.+]] = affine_map<(d0, d1, d2, d3, d4) -> (d3, d4, d2)>
// CHECK-DAG: #[[MAP2:.+]] = affine_map<(d0, d1, d2, d3, d4) -> (d0, d1, d2)>

// CHECK: func @conv_1d_nwc_wcf

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP0]], #[[MAP1]], #[[MAP2]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel", "reduction", "reduction"]}
// CHECK-SAME: ins(%{{.+}}, %{{.+}} : memref<?x?x?xf32>, memref<?x?x?xf32>)
// CHECK-SAME: outs(%{{.+}} : memref<?x?x?xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK-NEXT:      %[[MUL:.+]] = arith.mulf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK-NEXT:      %[[ADD:.+]] = arith.addf %[[BBARG2]], %[[MUL]] : f32
// CHECK-NEXT:      linalg.yield %[[ADD]] : f32

// -----

func.func @conv_1d_ncw_fcw(%input: memref<?x?x?xf32>, %filter: memref<?x?x?xf32>, %output: memref<?x?x?xf32>) {
  linalg.conv_1d_ncw_fcw {dilations = dense<1> : tensor<1xi64>,
                                       strides = dense<1> : tensor<1xi64>}
     ins (%input, %filter: memref<?x?x?xf32>, memref<?x?x?xf32>)
    outs (%output: memref<?x?x?xf32>)
  return
}
// CHECK-DAG: #[[MAP0:.+]] = affine_map<(d0, d1, d2, d3, d4) -> (d0, d3, d2 + d4)>
// CHECK-DAG: #[[MAP1:.+]] = affine_map<(d0, d1, d2, d3, d4) -> (d1, d3, d4)>
// CHECK-DAG: #[[MAP2:.+]] = affine_map<(d0, d1, d2, d3, d4) -> (d0, d1, d2)>

// CHECK: func @conv_1d_ncw_fcw

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP0]], #[[MAP1]], #[[MAP2]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel", "reduction", "reduction"]}
// CHECK-SAME: ins(%{{.+}}, %{{.+}} : memref<?x?x?xf32>, memref<?x?x?xf32>)
// CHECK-SAME: outs(%{{.+}} : memref<?x?x?xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK-NEXT:      %[[MUL:.+]] = arith.mulf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK-NEXT:      %[[ADD:.+]] = arith.addf %[[BBARG2]], %[[MUL]] : f32
// CHECK-NEXT:      linalg.yield %[[ADD]] : f32

// -----

func.func @generalize_fill(%output: memref<?x?xf32>, %value : f32) {
  linalg.fill ins(%value : f32) outs(%output : memref<?x?xf32>)
  return
}

// CHECK-DAG: #[[MAP0:.+]] = affine_map<(d0, d1) -> ()>
// CHECK-DAG: #[[MAP1:.+]] = affine_map<(d0, d1) -> (d0, d1)>

// CHECK: func @generalize_fill
// CHECK-SAME: (%[[ARG0:.+]]: memref<?x?xf32>, %[[VAL:.+]]: f32)

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP0]], #[[MAP1]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel"]}
// CHECK-SAME: ins(%[[VAL]] : f32)
// CHECK-SAME: outs(%{{.+}} : memref<?x?xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32)
// CHECK-NEXT:      linalg.yield %[[BBARG0]] : f32

// -----

func.func @generalize_batch_matm_vec(%lhs : memref<?x?x?xi8>, %rhs: memref<?x?xi8>,  %out: memref<?x?xf32>) {
  linalg.batch_matvec ins(%lhs, %rhs: memref<?x?x?xi8>, memref<?x?xi8>)
                     outs(%out: memref<?x?xf32>)
  return
}
// CHECK: #[[MAP0:.+]] = affine_map<(d0, d1, d2) -> (d0, d1, d2)>
// CHECK: #[[MAP1:.+]] = affine_map<(d0, d1, d2) -> (d0, d2)>
// CHECK: #[[MAP2:.+]] = affine_map<(d0, d1, d2) -> (d0, d1)>

// CHECK: @generalize_batch_matm_vec

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP0]], #[[MAP1]], #[[MAP2]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "reduction"]}
// CHECK-SAME: ins(%{{.+}}, %{{.+}} : memref<?x?x?xi8>, memref<?x?xi8>)
// CHECK-SAME: outs(%{{.+}} : memref<?x?xf32>)
// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: i8, %[[BBARG1:.+]]: i8, %[[BBARG2:.+]]: f32)
// CHECK:            %[[BBARG0_F32:.+]] = arith.sitofp %[[BBARG0]] : i8 to f32
// CHECK:            %[[BBARG1_F32:.+]] = arith.sitofp %[[BBARG1]] : i8 to f32
// CHECK:            %[[MUL:.+]] = arith.mulf %[[BBARG0_F32]], %[[BBARG1_F32]]
// CHECK:            %[[ADD:.+]] = arith.addf %[[BBARG2]], %[[MUL]]
// CHECK:            linalg.yield %[[ADD]] : f32

// -----

func.func @batch_reduce_gemm(%lhs: memref<7x8x9xf32>, %rhs: memref<7x9x8xf32>, %out: memref<8x8xf32>) {
  linalg.batch_reduce_matmul ins(%lhs, %rhs: memref<7x8x9xf32>, memref<7x9x8xf32>)
                             outs(%out: memref<8x8xf32>)
  return
}

// CHECK-DAG: #[[MAP0:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d1, d3)>
// CHECK-DAG: #[[MAP1:.+]] = affine_map<(d0, d1, d2, d3) -> (d0, d3, d2)>
// CHECK-DAG: #[[MAP2:.+]] = affine_map<(d0, d1, d2, d3) -> (d1, d2)>

// CHECK: @batch_reduce_gemm

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP0]], #[[MAP1]], #[[MAP2]]]
// CHECK-SAME: iterator_types = ["reduction", "parallel", "parallel", "reduction"]}
// CHECK-SAME: ins(%{{.+}}, %{{.+}} : memref<7x8x9xf32>, memref<7x9x8xf32>)
// CHECK-SAME: outs(%{{.+}} : memref<8x8xf32>
// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK:         %[[MUL:.+]] = arith.mulf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK:         %[[ADD:.+]] = arith.addf %[[BBARG2]], %[[MUL]] : f32
// CHECK:         linalg.yield %[[ADD]] : f32

// -----

// CHECK-LABEL: generalize_linalg_map
func.func @generalize_linalg_map(%arg0: memref<1x8x8x8xf32>) {
  %cst = arith.constant 0.000000e+00 : f32
  // CHECK: linalg.map
  // CHECK-NOT: linalg.generic
  linalg.map outs(%arg0 : memref<1x8x8x8xf32>)
    () {
      linalg.yield %cst : f32
    }
  return
}

// -----

func.func @generalize_add(%lhs: memref<7x14x21xf32>, %rhs: memref<7x14x21xf32>,
                          %out: memref<7x14x21xf32>) {
  linalg.add ins(%lhs, %rhs : memref<7x14x21xf32>, memref<7x14x21xf32>)
             outs(%out : memref<7x14x21xf32>)
  return
}

// CHECK-DAG: #[[MAP:.+]] = affine_map<(d0, d1, d2) -> (d0, d1, d2)>

// CHECK: func @generalize_add
// CHECK-SAME: (%[[LHS:.+]]: memref<7x14x21xf32>, %[[RHS:.+]]: memref<7x14x21xf32>,
// CHECK-SAME:  %[[OUT:.+]]: memref<7x14x21xf32>)

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP]], #[[MAP]], #[[MAP]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel"]}
// CHECK-SAME:  ins(%[[LHS]], %[[RHS]] : memref<7x14x21xf32>, memref<7x14x21xf32>)
// CHECK-SAME: outs(%[[OUT]] : memref<7x14x21xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK-NEXT:      %[[SUM:.+]] = arith.addf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK-NEXT:      linalg.yield %[[SUM]] : f32

// -----

func.func @generalize_sub(%lhs: memref<7x14x21xf32>, %rhs: memref<7x14x21xf32>,
                          %out: memref<7x14x21xf32>) {
  linalg.sub ins(%lhs, %rhs : memref<7x14x21xf32>, memref<7x14x21xf32>)
             outs(%out : memref<7x14x21xf32>)
  return
}

// CHECK-DAG: #[[MAP:.+]] = affine_map<(d0, d1, d2) -> (d0, d1, d2)>

// CHECK: func @generalize_sub
// CHECK-SAME: (%[[LHS:.+]]: memref<7x14x21xf32>, %[[RHS:.+]]: memref<7x14x21xf32>,
// CHECK-SAME:  %[[OUT:.+]]: memref<7x14x21xf32>)

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP]], #[[MAP]], #[[MAP]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel"]}
// CHECK-SAME:  ins(%[[LHS]], %[[RHS]] : memref<7x14x21xf32>, memref<7x14x21xf32>)
// CHECK-SAME: outs(%[[OUT]] : memref<7x14x21xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK-NEXT:      %[[SUM:.+]] = arith.subf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK-NEXT:      linalg.yield %[[SUM]] : f32

// -----

func.func @generalize_mul(%lhs: memref<7x14x21xf32>, %rhs: memref<7x14x21xf32>,
                          %out: memref<7x14x21xf32>) {
  linalg.mul ins(%lhs, %rhs : memref<7x14x21xf32>, memref<7x14x21xf32>)
             outs(%out : memref<7x14x21xf32>)
  return
}

// CHECK-DAG: #[[MAP:.+]] = affine_map<(d0, d1, d2) -> (d0, d1, d2)>

// CHECK: func @generalize_mul
// CHECK-SAME: (%[[LHS:.+]]: memref<7x14x21xf32>, %[[RHS:.+]]: memref<7x14x21xf32>,
// CHECK-SAME:  %[[OUT:.+]]: memref<7x14x21xf32>)

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP]], #[[MAP]], #[[MAP]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel"]}
// CHECK-SAME:  ins(%[[LHS]], %[[RHS]] : memref<7x14x21xf32>, memref<7x14x21xf32>)
// CHECK-SAME: outs(%[[OUT]] : memref<7x14x21xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK-NEXT:      %[[SUM:.+]] = arith.mulf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK-NEXT:      linalg.yield %[[SUM]] : f32

// -----

func.func @generalize_div(%lhs: memref<7x14x21xf32>, %rhs: memref<7x14x21xf32>,
                          %out: memref<7x14x21xf32>) {
  linalg.div ins(%lhs, %rhs : memref<7x14x21xf32>, memref<7x14x21xf32>)
             outs(%out : memref<7x14x21xf32>)
  return
}

// CHECK-DAG: #[[MAP:.+]] = affine_map<(d0, d1, d2) -> (d0, d1, d2)>

// CHECK: func @generalize_div
// CHECK-SAME: (%[[LHS:.+]]: memref<7x14x21xf32>, %[[RHS:.+]]: memref<7x14x21xf32>,
// CHECK-SAME:  %[[OUT:.+]]: memref<7x14x21xf32>)

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP]], #[[MAP]], #[[MAP]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel"]}
// CHECK-SAME:  ins(%[[LHS]], %[[RHS]] : memref<7x14x21xf32>, memref<7x14x21xf32>)
// CHECK-SAME: outs(%[[OUT]] : memref<7x14x21xf32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: f32, %[[BBARG1:.+]]: f32, %[[BBARG2:.+]]: f32)
// CHECK-NEXT:      %[[SUM:.+]] = arith.divf %[[BBARG0]], %[[BBARG1]] : f32
// CHECK-NEXT:      linalg.yield %[[SUM]] : f32

// -----

func.func @generalize_divu(%lhs: memref<7x14x21xi32>, %rhs: memref<7x14x21xi32>,
                          %out: memref<7x14x21xi32>) {
  linalg.div_unsigned ins(%lhs, %rhs : memref<7x14x21xi32>, memref<7x14x21xi32>)
             outs(%out : memref<7x14x21xi32>)
  return
}

// CHECK-DAG: #[[MAP:.+]] = affine_map<(d0, d1, d2) -> (d0, d1, d2)>

// CHECK: func @generalize_divu
// CHECK-SAME: (%[[LHS:.+]]: memref<7x14x21xi32>, %[[RHS:.+]]: memref<7x14x21xi32>,
// CHECK-SAME:  %[[OUT:.+]]: memref<7x14x21xi32>)

// CHECK: linalg.generic
// CHECK-SAME: indexing_maps = [#[[MAP]], #[[MAP]], #[[MAP]]]
// CHECK-SAME: iterator_types = ["parallel", "parallel", "parallel"]}
// CHECK-SAME:  ins(%[[LHS]], %[[RHS]] : memref<7x14x21xi32>, memref<7x14x21xi32>)
// CHECK-SAME: outs(%[[OUT]] : memref<7x14x21xi32>)

// CHECK:         ^{{.+}}(%[[BBARG0:.+]]: i32, %[[BBARG1:.+]]: i32, %[[BBARG2:.+]]: i32)
// CHECK-NEXT:      %[[SUM:.+]] = arith.divui %[[BBARG0]], %[[BBARG1]] : i32
// CHECK-NEXT:      linalg.yield %[[SUM]] : i32
