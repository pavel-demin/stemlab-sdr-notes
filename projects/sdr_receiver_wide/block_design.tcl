# Create clk_wiz
cell xilinx.com:ip:clk_wiz pll_0 {
  PRIMITIVE PLL
  PRIM_IN_FREQ.VALUE_SRC USER
  PRIM_IN_FREQ 122.88
  PRIM_SOURCE Differential_clock_capable_pin
  CLKOUT1_USED true
  CLKOUT1_REQUESTED_OUT_FREQ 122.88
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

# CFG

# Create axi_cfg_register
cell pavel-demin:user:axi_cfg_register cfg_0 {
  CFG_DATA_WIDTH 96
  AXI_ADDR_WIDTH 32
  AXI_DATA_WIDTH 32
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_0 {
  DIN_WIDTH 96 DIN_FROM 0 DIN_TO 0
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_1 {
  DIN_WIDTH 96 DIN_FROM 1 DIN_TO 1
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_2 {
  DIN_WIDTH 96 DIN_FROM 63 DIN_TO 32
} {
  din cfg_0/cfg_data
}

# Create port_slicer
cell pavel-demin:user:port_slicer slice_3 {
  DIN_WIDTH 96 DIN_FROM 95 DIN_TO 64
} {
  din cfg_0/cfg_data
}

# RX

# Create axis_lfsr
cell pavel-demin:user:axis_lfsr lfsr_0 {} {
  aclk pll_0/clk_out1
  aresetn slice_0/dout
}

for {set i 0} {$i <= 1} {incr i} {

  # Create axis_constant
  cell pavel-demin:user:axis_constant phase_$i {
    AXIS_TDATA_WIDTH 32
  } {
    cfg_data slice_[expr $i + 2]/dout
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

  # Create cic_compiler
  cell xilinx.com:ip:cic_compiler cic_$i {
    INPUT_DATA_WIDTH.VALUE_SRC USER
    FILTER_TYPE Decimation
    NUMBER_OF_STAGES 6
    SAMPLE_RATE_CHANGES Fixed
    FIXED_OR_INITIAL_RATE 10
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
    aclk pll_0/clk_out1
    aresetn slice_0/dout
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
  COEFFICIENTVECTOR {-1.6450564000e-08, -4.7041856143e-08, -6.7234545817e-10, 3.0754917262e-08, 1.8338805080e-08, 3.2544648778e-08, -5.9962343327e-09, -1.5135573988e-07, -8.2947475333e-08, 3.1261941406e-07, 3.0439239557e-07, -4.7123791776e-07, -7.1009343856e-07, 5.4380514639e-07, 1.3278578834e-06, -4.1113462899e-07, -2.1392828506e-06, -6.8349571143e-08, 3.0591412085e-06, 1.0325809716e-06, -3.9232201580e-06, -2.5792275551e-06, 4.4910228621e-06, 4.7236243304e-06, -4.4685248687e-06, -7.3598600787e-06, 3.5527991014e-06, 1.0235716663e-05, -1.4956883733e-06, -1.2952621703e-05, -1.8220726158e-06, 1.4999348963e-05, 6.3201067065e-06, -1.5823277788e-05, -1.1668919583e-05, 1.4934671323e-05, 1.7278308601e-05, -1.2035368804e-05, -2.2346578689e-05, 7.1392457914e-06, 2.5964980846e-05, -6.7019535621e-07, -2.7286461178e-05, -6.5032802593e-06, 2.5733719544e-05, 1.3119897243e-05, -2.1215786785e-05, -1.7680774856e-05, 1.4308431292e-05, 1.8706335977e-05, -6.3492657286e-06, -1.5072317381e-05, -5.9893660781e-07, 6.3783842771e-06, 3.9483883459e-06, 6.7161571699e-06, -9.5807991350e-07, -2.2267632368e-05, -1.0748342564e-05, 3.7007298506e-05, 3.2567420361e-05, -4.6571487645e-05, -6.4343257045e-05, 4.5963909988e-05, 1.0387175590e-04, -3.0320557479e-05, -1.4668663598e-04, -4.1590650284e-06, 1.8619203074e-04, 5.9215877897e-05, -2.1422057631e-04, -1.3364276424e-04, 2.2202110331e-04, 2.2269231533e-04, -2.0160512973e-04, -3.1796361150e-04, 1.4729579095e-04, 4.0790466883e-04, -5.7251598110e-05, -4.7899113399e-04, -6.5314200499e-05, 5.1753295312e-04, 2.1150481268e-04, -5.1195471979e-04, -3.6700377621e-04, 4.5514474451e-04, 5.1318941716e-04, -3.4678402948e-04, -6.2949199542e-04, 1.9482511667e-04, 6.9648129877e-04, -1.5987766240e-05, -6.9954876580e-04, -1.6517199820e-04, 6.3264044414e-04, 3.1877925723e-04, -5.0142971802e-04, -4.1369980888e-04, 3.2526866361e-04, 4.2283451251e-04, -1.3731428725e-04, -3.2908482153e-04, -1.7622881834e-05, 1.3119616163e-04, 8.7701493124e-05, 1.5146068050e-04, -2.1012262757e-05, -4.7620216544e-04, -2.2583216435e-04, 7.7684226748e-04, 6.7752477536e-04, -9.6783660490e-04, -1.3309867289e-03, 9.5139375746e-04, 2.1472322201e-03, -6.2853838233e-04, -3.0463489954e-03, -8.7027996308e-05, 3.9066090067e-03, 1.2533869133e-03, -4.5685801289e-03, -2.8847256552e-03, 4.8445971551e-03, 4.9372584021e-03, -4.5333448266e-03, -7.2984600927e-03, 3.4386469871e-03, 9.7810211747e-03, -1.3909537862e-03, -1.2122315241e-02, -1.7304353146e-03, 1.3988992385e-02, 5.9754370477e-03, -1.4987990776e-02, -1.1308160803e-02, 1.4674186082e-02, 1.7591692830e-02, -1.2558278699e-02, -2.4581181417e-02, 8.0981752845e-03, 3.1917837574e-02, -6.5709246023e-04, -3.9115531640e-02, -1.0614090028e-02, 4.5512171900e-02, 2.7076987664e-02, -5.0095088605e-02, -5.1407657772e-02, 5.0837646419e-02, 9.0066685433e-02, -4.1594941687e-02, -1.6297158092e-01, -1.0193463347e-02, 3.5590182386e-01, 5.5367820008e-01, 3.5590182386e-01, -1.0193463347e-02, -1.6297158092e-01, -4.1594941687e-02, 9.0066685433e-02, 5.0837646419e-02, -5.1407657772e-02, -5.0095088605e-02, 2.7076987664e-02, 4.5512171900e-02, -1.0614090028e-02, -3.9115531640e-02, -6.5709246023e-04, 3.1917837574e-02, 8.0981752845e-03, -2.4581181417e-02, -1.2558278699e-02, 1.7591692830e-02, 1.4674186082e-02, -1.1308160803e-02, -1.4987990776e-02, 5.9754370477e-03, 1.3988992385e-02, -1.7304353146e-03, -1.2122315241e-02, -1.3909537862e-03, 9.7810211747e-03, 3.4386469871e-03, -7.2984600927e-03, -4.5333448266e-03, 4.9372584021e-03, 4.8445971551e-03, -2.8847256552e-03, -4.5685801289e-03, 1.2533869133e-03, 3.9066090067e-03, -8.7027996309e-05, -3.0463489954e-03, -6.2853838233e-04, 2.1472322201e-03, 9.5139375746e-04, -1.3309867289e-03, -9.6783660490e-04, 6.7752477536e-04, 7.7684226748e-04, -2.2583216435e-04, -4.7620216544e-04, -2.1012262757e-05, 1.5146068050e-04, 8.7701493124e-05, 1.3119616163e-04, -1.7622881834e-05, -3.2908482153e-04, -1.3731428725e-04, 4.2283451251e-04, 3.2526866361e-04, -4.1369980888e-04, -5.0142971802e-04, 3.1877925723e-04, 6.3264044414e-04, -1.6517199820e-04, -6.9954876580e-04, -1.5987766240e-05, 6.9648129877e-04, 1.9482511667e-04, -6.2949199542e-04, -3.4678402948e-04, 5.1318941716e-04, 4.5514474451e-04, -3.6700377621e-04, -5.1195471979e-04, 2.1150481268e-04, 5.1753295312e-04, -6.5314200499e-05, -4.7899113399e-04, -5.7251598110e-05, 4.0790466883e-04, 1.4729579095e-04, -3.1796361150e-04, -2.0160512973e-04, 2.2269231533e-04, 2.2202110331e-04, -1.3364276424e-04, -2.1422057631e-04, 5.9215877897e-05, 1.8619203074e-04, -4.1590650284e-06, -1.4668663598e-04, -3.0320557479e-05, 1.0387175590e-04, 4.5963909988e-05, -6.4343257045e-05, -4.6571487645e-05, 3.2567420361e-05, 3.7007298506e-05, -1.0748342564e-05, -2.2267632368e-05, -9.5807991350e-07, 6.7161571699e-06, 3.9483883459e-06, 6.3783842771e-06, -5.9893660781e-07, -1.5072317381e-05, -6.3492657286e-06, 1.8706335977e-05, 1.4308431292e-05, -1.7680774856e-05, -2.1215786785e-05, 1.3119897243e-05, 2.5733719544e-05, -6.5032802593e-06, -2.7286461178e-05, -6.7019535621e-07, 2.5964980846e-05, 7.1392457914e-06, -2.2346578689e-05, -1.2035368804e-05, 1.7278308601e-05, 1.4934671323e-05, -1.1668919583e-05, -1.5823277788e-05, 6.3201067065e-06, 1.4999348963e-05, -1.8220726158e-06, -1.2952621703e-05, -1.4956883733e-06, 1.0235716663e-05, 3.5527991014e-06, -7.3598600787e-06, -4.4685248687e-06, 4.7236243304e-06, 4.4910228621e-06, -2.5792275551e-06, -3.9232201580e-06, 1.0325809716e-06, 3.0591412085e-06, -6.8349571143e-08, -2.1392828506e-06, -4.1113462899e-07, 1.3278578834e-06, 5.4380514639e-07, -7.1009343856e-07, -4.7123791776e-07, 3.0439239557e-07, 3.1261941406e-07, -8.2947475333e-08, -1.5135573988e-07, -5.9962343327e-09, 3.2544648778e-08, 1.8338805080e-08, 3.0754917262e-08, -6.7234545817e-10, -4.7041856143e-08, -1.6450564000e-08}
  COEFFICIENT_WIDTH 24
  QUANTIZATION Quantize_Only
  BESTPRECISION true
  FILTER_TYPE Decimation
  DECIMATION_RATE 2
  NUMBER_CHANNELS 1
  NUMBER_PATHS 4
  SAMPLE_FREQUENCY 12.288
  CLOCK_FREQUENCY 122.88
  OUTPUT_ROUNDING_MODE Convergent_Rounding_to_Even
  OUTPUT_WIDTH 16
  HAS_ARESETN true
} {
  S_AXIS_DATA comb_0/M_AXIS
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
  S_AXIS fir_0/M_AXIS_DATA
  M_AXI ps_0/S_AXI_HP0
  cfg_data const_1/dout
  aclk pll_0/clk_out1
  aresetn slice_1/dout
}

# STS

# Create dna_reader
cell pavel-demin:user:dna_reader dna_0 {} {
  aclk pll_0/clk_out1
  aresetn rst_0/peripheral_aresetn
}

# Create xlconcat
cell xilinx.com:ip:xlconcat concat_0 {
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
  sts_data concat_0/dout
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
