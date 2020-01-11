# Create clk_wiz
cell xilinx.com:ip:clk_wiz pll_0 {
  PRIMITIVE PLL
  PRIM_IN_FREQ.VALUE_SRC USER
  PRIM_IN_FREQ 122.88
  PRIM_SOURCE Differential_clock_capable_pin
  CLKOUT1_USED true
  CLKOUT1_REQUESTED_OUT_FREQ 122.88
  CLKOUT2_USED true
  CLKOUT2_REQUESTED_OUT_FREQ 245.76
  CLKOUT2_REQUESTED_PHASE -112.5
  CLKOUT3_USED true
  CLKOUT3_REQUESTED_OUT_FREQ 245.76
  CLKOUT3_REQUESTED_PHASE -67.5
  USE_RESET false
} {
  clk_in1_p adc_clk_p_i
  clk_in1_n adc_clk_n_i
}

# Create processing_system7
cell xilinx.com:ip:processing_system7 ps_0 {
  PCW_IMPORT_BOARD_PRESET cfg/stemlab_sdr.xml
  PCW_USE_S_AXI_HP0 1
} {
  M_AXI_GP0_ACLK pll_0/clk_out1
  S_AXI_HP0_ACLK pll_0/clk_out1
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {
  make_external {FIXED_IO, DDR}
  Master Disable
  Slave Disable
} [get_bd_cells ps_0]

# Create xlconstant
cell xilinx.com:ip:xlconstant const_0

# Create proc_sys_reset
cell xilinx.com:ip:proc_sys_reset rst_0 {} {
  ext_reset_in const_0/dout
}

# ADC

# Create axis_stemlab_sdr_adc
cell pavel-demin:user:axis_stemlab_sdr_adc adc_0 {
  ADC_DATA_WIDTH 16
} {
  aclk pll_0/clk_out1
  adc_dat_a adc_dat_a_i
  adc_dat_b adc_dat_b_i
  adc_csn adc_csn_o
}

# DAC

# Create axis_stemlab_sdr_dac
cell pavel-demin:user:axis_stemlab_sdr_dac dac_0 {
  DAC_DATA_WIDTH 14
} {
  aclk pll_0/clk_out1
  ddr_clk pll_0/clk_out2
  wrt_clk pll_0/clk_out3
  locked pll_0/locked
  dac_clk dac_clk_o
  dac_rst dac_rst_o
  dac_sel dac_sel_o
  dac_wrt dac_wrt_o
  dac_dat dac_dat_o
  s_axis_tvalid const_0/dout
}

# CFG

# Create axi_cfg_register
cell pavel-demin:user:axi_cfg_register cfg_0 {
  CFG_DATA_WIDTH 192
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_0 {
  DIN_WIDTH 192 DIN_FROM 0 DIN_TO 0
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_1 {
  DIN_WIDTH 192 DIN_FROM 1 DIN_TO 1
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_2 {
  DIN_WIDTH 192 DIN_FROM 31 DIN_TO 16
} {
  din cfg_0/cfg_data
}

# DDS

for {set i 0} {$i <= 3} {incr i} {

  # Create port_slicer
  cell pavel-demin:user:port_slicer slice_[expr $i + 3] {
    DIN_WIDTH 192 DIN_FROM [expr 32 * $i + 63] DIN_TO [expr 32 * $i + 32]
  } {
    din cfg_0/cfg_data
  }

  # Create axis_constant
  cell pavel-demin:user:axis_constant phase_$i {
    AXIS_TDATA_WIDTH 32
  } {
    cfg_data slice_[expr $i + 3]/dout
    aclk pll_0/clk_out1
  }

  # Create dds_compiler
  cell xilinx.com:ip:dds_compiler dds_$i {
    DDS_CLOCK_RATE 122.88
    SPURIOUS_FREE_DYNAMIC_RANGE 138
    FREQUENCY_RESOLUTION 0.2
    PHASE_INCREMENT Streaming
    HAS_PHASE_OUT false
    PHASE_WIDTH 30
    OUTPUT_WIDTH 24
    DSP48_USE Minimal
    NEGATIVE_SINE true
  } {
    S_AXIS_PHASE phase_$i/M_AXIS
    aclk pll_0/clk_out1
  }

}

# RX

# Create axis_lfsr
cell pavel-demin:user:axis_lfsr lfsr_0 {} {
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

for {set i 0} {$i <= 3} {incr i} {

  # Create port_slicer
  cell pavel-demin:user:port_slicer adc_slice_$i {
    DIN_WIDTH 32 DIN_FROM [expr 16 * ($i / 2) + 15] DIN_TO [expr 16 * ($i / 2)]
  } {
    din adc_0/m_axis_tdata
  }

  # Create port_slicer
  cell pavel-demin:user:port_slicer dds_slice_$i {
    DIN_WIDTH 48 DIN_FROM [expr 24 * ($i % 2) + 23] DIN_TO [expr 24 * ($i % 2)]
  } {
    din dds_[expr $i / 2]/m_axis_data_tdata
  }

  # Create xbip_dsp48_macro
  cell xilinx.com:ip:xbip_dsp48_macro mult_$i {
    INSTRUCTION1 RNDSIMPLE(A*B+CARRYIN)
    A_WIDTH.VALUE_SRC USER
    B_WIDTH.VALUE_SRC USER
    OUTPUT_PROPERTIES User_Defined
    A_WIDTH 24
    B_WIDTH 16
    P_WIDTH 25
  } {
    A dds_slice_$i/dout
    B adc_slice_$i/dout
    CARRYIN lfsr_0/m_axis_tdata
    CLK pll_0/clk_out1
  }

  # Create axis_variable
  cell pavel-demin:user:axis_variable rate_$i {
    AXIS_TDATA_WIDTH 16
  } {
    cfg_data slice_2/dout
    aclk pll_0/clk_out1
    aresetn rst_0/peripheral_aresetn
  }

  # Create cic_compiler
  cell xilinx.com:ip:cic_compiler cic_$i {
    INPUT_DATA_WIDTH.VALUE_SRC USER
    FILTER_TYPE Decimation
    NUMBER_OF_STAGES 6
    SAMPLE_RATE_CHANGES Programmable
    MINIMUM_RATE 8
    MAXIMUM_RATE 64
    FIXED_OR_INITIAL_RATE 8
    INPUT_SAMPLE_FREQUENCY 122.88
    CLOCK_FREQUENCY 122.88
    INPUT_DATA_WIDTH 24
    QUANTIZATION Truncation
    OUTPUT_DATA_WIDTH 32
    USE_XTREME_DSP_SLICE false
    HAS_ARESETN true
  } {
    s_axis_data_tdata mult_$i/P
    s_axis_data_tvalid const_0/dout
    S_AXIS_CONFIG rate_$i/M_AXIS
    aclk pll_0/clk_out1
    aresetn rst_0/peripheral_aresetn
  }

}

# Create axis_combiner
cell  xilinx.com:ip:axis_combiner comb_0 {
  TDATA_NUM_BYTES.VALUE_SRC USER
  TDATA_NUM_BYTES 4
  NUM_SI 4
} {
  S00_AXIS cic_0/M_AXIS_DATA
  S01_AXIS cic_1/M_AXIS_DATA
  S02_AXIS cic_2/M_AXIS_DATA
  S03_AXIS cic_3/M_AXIS_DATA
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# Create fir_compiler
cell xilinx.com:ip:fir_compiler fir_0 {
  DATA_WIDTH.VALUE_SRC USER
  DATA_WIDTH 32
  COEFFICIENTVECTOR {-1.6436084501e-08, -4.6886269341e-08, -6.0448666913e-10, 3.0655537993e-08, 1.8177701338e-08, 3.2431498400e-08, -5.8262514347e-09, -1.5084308482e-07, -8.2895796792e-08, 3.1155640781e-07, 3.0371226691e-07, -4.6960940237e-07, -7.0821329704e-07, 5.4185157412e-07, 1.3241154897e-06, -4.0946326379e-07, -2.1330680525e-06, -6.8694811492e-08, 3.0501029519e-06, 1.0301308083e-06, -3.9115112348e-06, -2.5722128588e-06, 4.4775358362e-06, 4.7102327729e-06, -4.4550563057e-06, -7.3386136885e-06, 3.5420738458e-06, 1.0205926688e-05, -1.4911844662e-06, -1.2914842157e-05, -1.8165305210e-06, 1.4955723312e-05, 6.3009743948e-06, -1.5777661755e-05, -1.1633714627e-05, 1.4892428540e-05, 1.7226430175e-05, -1.2002753772e-05, -2.2279958122e-05, 7.1224231640e-06, 2.5888413825e-05, -6.7394611940e-07, -2.7207406616e-05, -6.4769602241e-06, 2.5661443280e-05, 1.3073033760e-05, -2.1159824892e-05, -1.7620162943e-05, 1.4276487829e-05, 1.8643480366e-05, -6.3448123764e-06, -1.5022318306e-05, -5.7894544142e-07, 6.3576674724e-06, 3.9151736093e-06, 6.6931635928e-06, -9.3153186966e-07, -2.2192529367e-05, -1.0740798132e-05, 3.6881876571e-05, 3.2493905094e-05, -4.6411111980e-05, -6.4172235115e-05, 4.5799542926e-05, 1.0357844904e-04, -3.0198341198e-05, -1.4626008522e-04, -4.1811411779e-06, 1.8564172645e-04, 5.9074417757e-05, -2.1358133100e-04, -1.3327817299e-04, 2.2135482537e-04, 2.2205984524e-04, -2.0099837643e-04, -3.1704473951e-04, 1.4685247316e-04, 4.0671687528e-04, -5.7080920747e-05, -4.7759395965e-04, -6.5113601228e-05, 5.1602835146e-04, 2.1086264240e-04, -5.1048024140e-04, -3.6589488723e-04, 4.5385958831e-04, 5.1164742037e-04, -3.4584742171e-04, -6.2761511086e-04, 1.9437028836e-04, 6.9442856818e-04, -1.6094425442e-05, -6.9752473144e-04, -1.6450224594e-04, 6.3086811692e-04, 3.1763954728e-04, -5.0011361138e-04, -4.1228187817e-04, 3.2455175016e-04, 4.2141592871e-04, -1.3723462061e-04, -3.2799750129e-04, -1.7168716354e-05, 1.3077660982e-04, 8.6980333499e-05, 1.5093595124e-04, -2.0454551804e-05, -4.7458948996e-04, -2.2565876020e-04, 7.7420502465e-04, 6.7597501219e-04, -9.6450461069e-04, -1.3274244124e-03, 9.4800096338e-04, 2.1411424520e-03, -6.2602561560e-04, -3.0374659283e-03, -8.7454136117e-05, 3.8950458382e-03, 1.2503441706e-03, -4.5549454575e-03, -2.8767956292e-03, 4.8300806458e-03, 4.9231703935e-03, -4.5197558102e-03, -7.2773088400e-03, 3.4283923321e-03, 9.7525036551e-03, -1.3869458999e-03, -1.2086969677e-02, -1.7249448324e-03, 1.3948422789e-02, 5.9571009457e-03, -1.4945051481e-02, -1.1273829513e-02, 1.4633150167e-02, 1.7538781950e-02, -1.2524973782e-02, -2.4508094061e-02, 8.0801380076e-03, 3.1824475644e-02, -6.6383036058e-04, -3.9004003350e-02, -1.0570544425e-02, 4.5388020146e-02, 2.6980846294e-02, -4.9970058275e-02, -5.1236693858e-02, 5.0737631742e-02, 8.9787173448e-02, -4.1589200753e-02, -1.6254208995e-01, -9.8522292010e-03, 3.5564436029e-01, 5.5306276319e-01, 3.5564436029e-01, -9.8522292010e-03, -1.6254208995e-01, -4.1589200753e-02, 8.9787173448e-02, 5.0737631742e-02, -5.1236693858e-02, -4.9970058275e-02, 2.6980846294e-02, 4.5388020146e-02, -1.0570544425e-02, -3.9004003350e-02, -6.6383036058e-04, 3.1824475644e-02, 8.0801380076e-03, -2.4508094061e-02, -1.2524973782e-02, 1.7538781950e-02, 1.4633150167e-02, -1.1273829513e-02, -1.4945051481e-02, 5.9571009457e-03, 1.3948422789e-02, -1.7249448324e-03, -1.2086969677e-02, -1.3869458999e-03, 9.7525036551e-03, 3.4283923321e-03, -7.2773088400e-03, -4.5197558102e-03, 4.9231703935e-03, 4.8300806458e-03, -2.8767956292e-03, -4.5549454575e-03, 1.2503441706e-03, 3.8950458382e-03, -8.7454136117e-05, -3.0374659283e-03, -6.2602561560e-04, 2.1411424520e-03, 9.4800096338e-04, -1.3274244124e-03, -9.6450461069e-04, 6.7597501219e-04, 7.7420502465e-04, -2.2565876020e-04, -4.7458948996e-04, -2.0454551804e-05, 1.5093595124e-04, 8.6980333499e-05, 1.3077660982e-04, -1.7168716354e-05, -3.2799750129e-04, -1.3723462061e-04, 4.2141592871e-04, 3.2455175016e-04, -4.1228187817e-04, -5.0011361138e-04, 3.1763954728e-04, 6.3086811692e-04, -1.6450224594e-04, -6.9752473144e-04, -1.6094425442e-05, 6.9442856818e-04, 1.9437028836e-04, -6.2761511086e-04, -3.4584742171e-04, 5.1164742037e-04, 4.5385958831e-04, -3.6589488723e-04, -5.1048024140e-04, 2.1086264240e-04, 5.1602835146e-04, -6.5113601228e-05, -4.7759395965e-04, -5.7080920747e-05, 4.0671687528e-04, 1.4685247316e-04, -3.1704473951e-04, -2.0099837643e-04, 2.2205984524e-04, 2.2135482537e-04, -1.3327817299e-04, -2.1358133100e-04, 5.9074417757e-05, 1.8564172645e-04, -4.1811411779e-06, -1.4626008522e-04, -3.0198341198e-05, 1.0357844904e-04, 4.5799542926e-05, -6.4172235115e-05, -4.6411111980e-05, 3.2493905094e-05, 3.6881876571e-05, -1.0740798132e-05, -2.2192529367e-05, -9.3153186966e-07, 6.6931635928e-06, 3.9151736093e-06, 6.3576674724e-06, -5.7894544142e-07, -1.5022318306e-05, -6.3448123764e-06, 1.8643480366e-05, 1.4276487829e-05, -1.7620162943e-05, -2.1159824892e-05, 1.3073033760e-05, 2.5661443280e-05, -6.4769602241e-06, -2.7207406616e-05, -6.7394611940e-07, 2.5888413825e-05, 7.1224231640e-06, -2.2279958122e-05, -1.2002753772e-05, 1.7226430175e-05, 1.4892428540e-05, -1.1633714627e-05, -1.5777661755e-05, 6.3009743948e-06, 1.4955723312e-05, -1.8165305210e-06, -1.2914842157e-05, -1.4911844662e-06, 1.0205926688e-05, 3.5420738458e-06, -7.3386136885e-06, -4.4550563057e-06, 4.7102327729e-06, 4.4775358362e-06, -2.5722128588e-06, -3.9115112348e-06, 1.0301308083e-06, 3.0501029519e-06, -6.8694811492e-08, -2.1330680525e-06, -4.0946326379e-07, 1.3241154897e-06, 5.4185157412e-07, -7.0821329704e-07, -4.6960940237e-07, 3.0371226691e-07, 3.1155640781e-07, -8.2895796792e-08, -1.5084308482e-07, -5.8262514347e-09, 3.2431498400e-08, 1.8177701338e-08, 3.0655537993e-08, -6.0448666913e-10, -4.6886269341e-08, -1.6436084501e-08}
  COEFFICIENT_WIDTH 24
  QUANTIZATION Quantize_Only
  BESTPRECISION true
  FILTER_TYPE Decimation
  DECIMATION_RATE 2
  NUMBER_CHANNELS 1
  NUMBER_PATHS 4
  SAMPLE_FREQUENCY 15.36
  CLOCK_FREQUENCY 122.88
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 18
  HAS_ARESETN true
} {
  S_AXIS_DATA comb_0/M_AXIS
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# Create axis_subset_converter
cell xilinx.com:ip:axis_subset_converter subset_0 {
  S_TDATA_NUM_BYTES.VALUE_SRC USER
  M_TDATA_NUM_BYTES.VALUE_SRC USER
  S_TDATA_NUM_BYTES 12
  M_TDATA_NUM_BYTES 8
  TDATA_REMAP {tdata[87:72],tdata[63:48],tdata[39:24],tdata[15:0]}
} {
  S_AXIS fir_0/M_AXIS_DATA
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

# DMA

# Create xlconstant
cell xilinx.com:ip:xlconstant const_1 {
  CONST_WIDTH 32
  CONST_VAL 503316480
}

# Create axis_ram_writer
cell pavel-demin:user:axis_ram_writer writer_0 {
  ADDR_WIDTH 20
} {
  S_AXIS subset_0/M_AXIS
  M_AXI ps_0/S_AXI_HP0
  cfg_data const_1/dout
  aclk pll_0/clk_out1
  aresetn slice_1/dout
}

# GEN

for {set i 0} {$i <= 1} {incr i} {

  # Create port_slicer
  cell pavel-demin:user:port_slicer slice_[expr $i + 7] {
    DIN_WIDTH 192 DIN_FROM [expr 16 * $i + 175] DIN_TO [expr 16 * $i + 160]
  } {
    din cfg_0/cfg_data
  }

  # Create xbip_dsp48_macro
  cell xilinx.com:ip:xbip_dsp48_macro mult_[expr $i + 4] {
    INSTRUCTION1 RNDSIMPLE(A*B+CARRYIN)
    A_WIDTH.VALUE_SRC USER
    B_WIDTH.VALUE_SRC USER
    OUTPUT_PROPERTIES User_Defined
    A_WIDTH 24
    B_WIDTH 16
    P_WIDTH 15
  } {
    A dds_[expr $i + 2]/m_axis_data_tdata
    B slice_[expr $i + 7]/dout
    CARRYIN lfsr_0/m_axis_tdata
    CLK pll_0/clk_out1
  }

}

# Create xlconcat
cell xilinx.com:ip:xlconcat concat_0 {
  NUM_PORTS 2
  IN0_WIDTH 16
  IN1_WIDTH 16
} {
  In0 mult_4/P
  In1 mult_5/P
  dout dac_0/s_axis_tdata
}

# STS

# Create dna_reader
cell pavel-demin:user:dna_reader dna_0 {} {
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create xlconcat
cell xilinx.com:ip:xlconcat concat_1 {
  NUM_PORTS 3
  IN0_WIDTH 32
  IN1_WIDTH 64
  IN2_WIDTH 32
} {
  In0 const_0/dout
  In1 dna_0/dna_data
  In2 writer_0/sts_data
}

# Create axi_sts_register
cell pavel-demin:user:axi_sts_register sts_0 {
  STS_DATA_WIDTH 128
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
} {
  sts_data concat_1/dout
}

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins sts_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]
set_property OFFSET 0x40000000 [get_bd_addr_segs ps_0/Data/SEG_sts_0_reg0]

# Create all required interconnections
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config {
  Master /ps_0/M_AXI_GP0
  Clk Auto
} [get_bd_intf_pins cfg_0/S_AXI]

set_property RANGE 4K [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]
set_property OFFSET 0x40001000 [get_bd_addr_segs ps_0/Data/SEG_cfg_0_reg0]

assign_bd_address [get_bd_addr_segs ps_0/S_AXI_HP0/HP0_DDR_LOWOCM]
