// Copyright © 2023 Manuel Rodríguez & Zero-Day Labs, Lda.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// Licensed under the Solderpad Hardware License v 2.1 (the “License”); 
// you may not use this file except in compliance with the License, 
// or, at your option, the Apache License version 2.0. 
// You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/.
// Unless required by applicable law or agreed to in writing, 
// any work distributed under the License is distributed on an “AS IS” BASIS, 
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
// See the License for the specific language governing permissions and limitations under the License.
//
// Author: Manuel Rodríguez <manuel.cederog@gmail.com>
// Date: 13/10/2022
//
// Description: IOMMU memory-mapped register interface package.
//              Defines data structures and other register-related data.
//
// Disclaimer:  This file was generated using LowRISC `reggen` tool. Edit at your own risk.


`include "include/assertions.svh"
`include "packages/iommu_reg_pkg.sv"
`include "packages/iommu_field_pkg.sv"
`include "register_interface/typedef.svh"

module iommu_regmap_wrapper #(
  parameter int 			        ADDR_WIDTH = 32,
  parameter int 			        DATA_WIDTH = 32,

  // Interrupt Generation Support
  parameter rv_iommu::igs_t   IGS = rv_iommu::WSI_ONLY,
  // Number of Interrupt Vectors supported (1, 2, 4, 8, 16)
  parameter int unsigned      N_INT_VEC = 16,
  // Number of Performance monitoring event counters (set to zero to disable HPM)
  parameter int unsigned      N_IOHPMCTR = 0, // max 31

  parameter type 			        reg_req_t = logic,
  parameter type 			        reg_rsp_t = logic,

  // DO NOT MODIFY MANUALLY
  parameter int unsigned 	STRB_WIDTH = (DATA_WIDTH / 8),
  parameter int unsigned  LOG2_INTVEC = $clog2(N_INT_VEC)
  ) (
  input logic clk_i,
  input logic rst_ni,
  // From SW
  input  reg_req_t 						reg_req_i,
  output reg_rsp_t 						reg_rsp_o,
  // To HW
  output iommu_reg_pkg::iommu_reg2hw_t 	reg2hw, // Write
  input  iommu_reg_pkg::iommu_hw2reg_t 	hw2reg, // Read

  // Config
  input logic devmode_i // If 1, explicit error return for unmapped register access
);

  import iommu_reg_pkg::* ;
  import iommu_field_pkg::* ;

  localparam logic [N_IOHPMCTR-1:0] IOCOUNTINH_RESVAL = '1;

  // register signals
  // EXP: Register signals to connect the SW register interface port to the register file.
  logic           			  reg_we;
  logic           			  reg_re;
  logic [12-1:0]          reg_addr;
  logic [DATA_WIDTH-1:0]  reg_wdata;
  logic [STRB_WIDTH-1:0] 	reg_be;
  logic [DATA_WIDTH-1:0]  reg_rdata;
  logic           			  reg_error;
  logic           			  reg_ready;

  logic addrmiss;
  logic [210:0] wr_err;
  logic [DATA_WIDTH-1:0] reg_rdata_next;

  reg_req_t  reg_intf_req;
  reg_rsp_t  reg_intf_rsp;


  assign reg_intf_req = reg_req_i;
  assign reg_rsp_o = reg_intf_rsp;


  assign reg_we = reg_intf_req.valid & reg_intf_req.write;
  assign reg_re = reg_intf_req.valid & ~reg_intf_req.write;
  assign reg_addr = reg_intf_req.addr[11:0];	// only compare the offsets. Regmap is 4kiB alligned.
  assign reg_wdata = reg_intf_req.wdata;
  assign reg_be = reg_intf_req.wstrb;
  assign reg_intf_rsp.rdata = reg_rdata;
  assign reg_intf_rsp.error = reg_error;
  // assign reg_intf_rsp.ready = reg_we | reg_re;
  assign reg_intf_rsp.ready = 1'b1;

  assign reg_rdata = reg_re ? reg_rdata_next : '0;
  assign reg_error = (devmode_i & addrmiss) | (reg_we & |wr_err);   // when in development mode, address misses are not silent

  // caps (low)
  logic [7:0] 	capabilities_version_qs;
  logic 		    capabilities_sv32_qs;
  logic 		    capabilities_sv39_qs;
  logic 		    capabilities_sv48_qs;
  logic 		    capabilities_sv57_qs;
  logic 		    capabilities_svpbmt_qs;
  logic 		    capabilities_sv32x4_qs;
  logic 		    capabilities_sv39x4_qs;
  logic 		    capabilities_sv48x4_qs;
  logic 		    capabilities_sv57x4_qs;
  logic 		    capabilities_amo_mrif_qs;
  logic 		    capabilities_msi_flat_qs;
  logic 		    capabilities_msi_mrif_qs;
  logic 		    capabilities_amo_hwad_qs;
  logic 		    capabilities_ats_qs;
  logic 		    capabilities_t2gpa_qs;
  logic 		    capabilities_endi_qs;
  logic [1:0] 	capabilities_igs_qs;
  logic 		    capabilities_hpm_qs;
  logic 		    capabilities_dbg_qs;

  // caps (high)
  logic [5:0] 	capabilities_pas_qs;
  logic 		    capabilities_pd8_qs;
  logic 		    capabilities_pd17_qs;
  logic 		    capabilities_pd20_qs;

  // fctl
  logic 		fctl_be_qs;
//   logic fctl_be_wd;
//   logic fctl_be_we;
  logic 		fctl_wsi_qs;
  logic 		fctl_wsi_wd;
  logic 		fctl_wsi_we;
  logic 		fctl_gxl_qs;
  logic 		fctl_gxl_wd;
  logic 		fctl_gxl_we;

  // ddtp (low)
  logic [3:0] 	ddtp_iommu_mode_qs;
  logic [3:0] 	ddtp_iommu_mode_wd;
  logic 		    ddtp_iommu_mode_we;
  logic 		    ddtp_busy_qs;
  logic [21:0] 	ddtp_ppn_l_qs;
  logic [21:0] 	ddtp_ppn_l_wd;
  logic 		    ddtp_ppn_l_we;

  // ddtp (high)
  logic [21:0] 	ddtp_ppn_h_qs;
  logic [21:0] 	ddtp_ppn_h_wd;
  logic 		    ddtp_ppn_h_we;

  // cqb (low)
  logic [4:0] 	cqb_log2sz_1_qs;
  logic [4:0] 	cqb_log2sz_1_wd;
  logic 		    cqb_log2sz_1_we;
  logic [21:0] 	cqb_ppn_l_qs;
  logic [21:0] 	cqb_ppn_l_wd;
  logic 		    cqb_ppn_l_we;

  // cqb (high)
  logic [21:0] 	cqb_ppn_h_qs;
  logic [21:0] 	cqb_ppn_h_wd;
  logic 		    cqb_ppn_h_we;

  // cqh
  logic [31:0] 	cqh_qs;

  // cqt
  logic [31:0] 	cqt_qs;
  logic [31:0] 	cqt_wd;
  logic         cqt_we;

  // fqb (low)
  logic [4:0] 	fqb_log2sz_1_qs;
  logic [4:0] 	fqb_log2sz_1_wd;
  logic 		    fqb_log2sz_1_we;
  logic [21:0] 	fqb_ppn_l_qs;
  logic [21:0] 	fqb_ppn_l_wd;
  logic 		    fqb_ppn_l_we;

  // fqb (high)
  logic [21:0] 	fqb_ppn_h_qs;
  logic [21:0] 	fqb_ppn_h_wd;
  logic 		    fqb_ppn_h_we;

  // fqh
  logic [31:0] 	fqh_qs;
  logic [31:0] 	fqh_wd;
  logic fqh_we;

  // fqt
  logic [31:0] 	fqt_qs;

  // cqcsr
  logic 		cqcsr_cqen_qs;
  logic 		cqcsr_cqen_wd;
  logic 		cqcsr_cqen_we;
  logic 		cqcsr_cie_qs;
  logic 		cqcsr_cie_wd;
  logic 		cqcsr_cie_we;
  logic 		cqcsr_cqmf_qs;
  logic 		cqcsr_cqmf_wd;
  logic 		cqcsr_cqmf_we;
  logic 		cqcsr_cmd_to_qs;
  logic 		cqcsr_cmd_to_wd;
  logic 		cqcsr_cmd_to_we;
  logic 		cqcsr_cmd_ill_qs;
  logic 		cqcsr_cmd_ill_wd;
  logic 		cqcsr_cmd_ill_we;
  logic 		cqcsr_fence_w_ip_qs;
  logic 		cqcsr_fence_w_ip_wd;
  logic 		cqcsr_fence_w_ip_we;
  logic 		cqcsr_cqon_qs;
  logic 		cqcsr_busy_qs;

  // fqcsr
  logic 		fqcsr_fqen_qs;
  logic 		fqcsr_fqen_wd;
  logic 		fqcsr_fqen_we;
  logic 		fqcsr_fie_qs;
  logic 		fqcsr_fie_wd;
  logic 		fqcsr_fie_we;
  logic 		fqcsr_fqmf_qs;
  logic 		fqcsr_fqmf_wd;
  logic 		fqcsr_fqmf_we;
  logic 		fqcsr_fqof_qs;
  logic 		fqcsr_fqof_wd;
  logic 		fqcsr_fqof_we;
  logic 		fqcsr_fqon_qs;
  logic 		fqcsr_busy_qs;

  // iocountinh
  logic 		              iocountinh_cy_qs;
  logic 		              iocountinh_cy_wd;
  logic 		              iocountinh_cy_we;
  logic [31-1:0]	        iocountinh_hpm_qs;
  logic [31-1:0]	        iocountinh_hpm_wd;
  logic 		              iocountinh_hpm_we;

  // iohpmcycles (low)
  logic [31:0]	iohpmcycles_counter_l_qs;
  logic [31:0]	iohpmcycles_counter_l_wd;
  logic 		    iohpmcycles_counter_l_we;

  // iohpmcycles (high)
  logic [30:0]	iohpmcycles_counter_h_qs;
  logic [30:0]	iohpmcycles_counter_h_wd;
  logic 		    iohpmcycles_counter_h_we;
  logic 		    iohpmcycles_of_qs;
  logic 		    iohpmcycles_of_wd;
  logic 		    iohpmcycles_of_we;

  // iohpmctr (low)
  logic [31:0]	iohpmctr_counter_l_qs   [31];
  logic [31:0]	iohpmctr_counter_l_wd   [31];
  logic 		    iohpmctr_counter_l_we   [31];

  // iohpmctr (high)
  logic [31:0]	iohpmctr_counter_h_qs   [31];
  logic [31:0]	iohpmctr_counter_h_wd   [31];
  logic 		    iohpmctr_counter_h_we   [31];

  // iohpmevt (low)
  logic [14:0]	iohpmevt_eventid_qs     [31];
  logic [14:0]	iohpmevt_eventid_wd     [31];
  logic 		    iohpmevt_eventid_we     [31];
  logic 	      iohpmevt_dmask_qs       [31];
  logic 	      iohpmevt_dmask_wd       [31];
  logic 		    iohpmevt_dmask_we       [31];
  logic [15:0]	iohpmevt_pid_pscid_l_qs [31];
  logic [15:0]	iohpmevt_pid_pscid_l_wd [31];
  logic 		    iohpmevt_pid_pscid_l_we [31];

  // iohpmevt (high)
  logic [3:0]	  iohpmevt_pid_pscid_h_qs [31];
  logic [3:0]	  iohpmevt_pid_pscid_h_wd [31];
  logic 		    iohpmevt_pid_pscid_h_we [31];
  logic [23:0]	iohpmevt_did_gscid_qs   [31];
  logic [23:0]	iohpmevt_did_gscid_wd   [31];
  logic 		    iohpmevt_did_gscid_we   [31];
  logic 	      iohpmevt_pv_pscv_qs     [31];
  logic 	      iohpmevt_pv_pscv_wd     [31];
  logic 		    iohpmevt_pv_pscv_we     [31];
  logic 	      iohpmevt_dv_gscv_qs     [31];
  logic 	      iohpmevt_dv_gscv_wd     [31];
  logic 		    iohpmevt_dv_gscv_we     [31];
  logic 	      iohpmevt_idt_qs         [31];
  logic 	      iohpmevt_idt_wd         [31];
  logic 		    iohpmevt_idt_we         [31];
  logic 	      iohpmevt_of_qs          [31];
  logic 	      iohpmevt_of_wd          [31];
  logic 		    iohpmevt_of_we          [31];
  
  // ipsr
  logic 		ipsr_cip_qs;
  logic 		ipsr_cip_wd;
  logic 		ipsr_cip_we;
  logic 		ipsr_fip_qs;
  logic 		ipsr_fip_wd;
  logic 		ipsr_fip_we;
  logic 		ipsr_pmip_qs;
  logic 		ipsr_pmip_wd;
  logic 		ipsr_pmip_we;
  logic 		ipsr_pip_qs;
  logic 		ipsr_pip_wd;
  logic 		ipsr_pip_we;

  // icvec (low)
  logic [(LOG2_INTVEC-1):0] 	icvec_civ_qs;
  logic [(LOG2_INTVEC-1):0] 	icvec_civ_wd;
  logic 		                  icvec_civ_we;
  logic [(LOG2_INTVEC-1):0] 	icvec_fiv_qs;
  logic [(LOG2_INTVEC-1):0] 	icvec_fiv_wd;
  logic 		                  icvec_fiv_we;
  logic [(LOG2_INTVEC-1):0] 	icvec_pmiv_qs;
  logic [(LOG2_INTVEC-1):0] 	icvec_pmiv_wd;
  logic 		                  icvec_pmiv_we;
  logic [(LOG2_INTVEC-1):0] 	icvec_piv_qs;
  logic [(LOG2_INTVEC-1):0] 	icvec_piv_wd;
  logic 		                  icvec_piv_we;

  // MSI configuration table
  logic [29:0]  msi_addr_l_qs   [16];
  logic [29:0]  msi_addr_l_wd   [16];
  logic         msi_addr_l_we   [16];
  logic [23:0]  msi_addr_h_qs   [16];
  logic [23:0]  msi_addr_h_wd   [16];
  logic         msi_addr_h_we   [16];
  logic [31:0]  msi_data_qs     [16];
  logic [31:0]  msi_data_wd     [16];
  logic         msi_data_we     [16];
  logic         msi_vec_ctl_qs  [16];
  logic         msi_vec_ctl_wd  [16];
  logic         msi_vec_ctl_we  [16];

  //--------------------
  //# Register instances
  //--------------------

  // R[capabilities]: V(False)

  //   F[version]: 7:0
  assign reg2hw.capabilities.version.q = 8'h10; // for internal HW reads
  assign capabilities_version_qs = 8'h10;       // for SW reads


  //   F[sv32]: 8:8
  assign reg2hw.capabilities.sv32.q = 1'h0;
  assign capabilities_sv32_qs = 1'h0;


  //   F[sv39]: 9:9
  assign reg2hw.capabilities.sv39.q = 1'h1;
  assign capabilities_sv39_qs = 1'h1;

  //   F[sv48]: 10:10
  assign reg2hw.capabilities.sv48.q = 1'h0;
  assign capabilities_sv48_qs = 1'h0;


  //   F[sv57]: 11:11
  assign reg2hw.capabilities.sv57.q = 1'h0;
  assign capabilities_sv57_qs = 1'h0;


  //   F[svpbmt]: 15:15
  assign reg2hw.capabilities.svpbmt.q = 1'h0;
  assign capabilities_svpbmt_qs = 1'h0;


  //   F[sv32x4]: 16:16
  assign reg2hw.capabilities.sv32x4.q = 1'h0;
  assign capabilities_sv32x4_qs = 1'h0;


  //   F[sv39x4]: 17:17
  assign reg2hw.capabilities.sv39x4.q = 1'h1;
  assign capabilities_sv39x4_qs = 1'h1;


  //   F[sv48x4]: 18:18
  assign reg2hw.capabilities.sv48x4.q = 1'h0;
  assign capabilities_sv48x4_qs = 1'h0;


  //   F[sv57x4]: 19:19
  assign reg2hw.capabilities.sv57x4.q = 1'h0;
  assign capabilities_sv57x4_qs = 1'h0;

  //   F[amo_mrif]: 21:21
  assign reg2hw.capabilities.amo_mrif.q = 1'h0;
  assign capabilities_amo_mrif_qs = 1'h0;

  //   F[msi_flat]: 22:22
  assign reg2hw.capabilities.msi_flat.q = 1'h1;
  assign capabilities_msi_flat_qs = 1'h1;


  //   F[msi_mrif]: 23:23
  assign reg2hw.capabilities.msi_mrif.q = 1'h0;
  assign capabilities_msi_mrif_qs = 1'h0;


  //   F[amo_hwad]: 24:24
  assign reg2hw.capabilities.amo_hwad.q = 1'h0;
  assign capabilities_amo_hwad_qs = 1'h0;


  //   F[ats]: 25:25
  assign reg2hw.capabilities.ats.q = 1'h0;
  assign capabilities_ats_qs = 1'h0;


  //   F[t2gpa]: 26:26
  assign reg2hw.capabilities.t2gpa.q = 1'h0;
  assign capabilities_t2gpa_qs = 1'h0;


  //   F[endi]: 27:27
  assign reg2hw.capabilities.endi.q = 1'h0;
  assign capabilities_endi_qs = 1'h0;


  //   F[igs]: 29:28
  // MSI support only
  if (IGS == rv_iommu::MSI_ONLY) begin
      assign reg2hw.capabilities.igs.q = 2'h0;
      assign capabilities_igs_qs = 2'h0;
  end

  // WSI support only
  else if (IGS == rv_iommu::WSI_ONLY) begin
      assign reg2hw.capabilities.igs.q = 2'h1;
      assign capabilities_igs_qs = 2'h1;
  end

  // MSI and WSI support
  else if (IGS == rv_iommu::BOTH) begin
      assign reg2hw.capabilities.igs.q = 2'h2;
      assign capabilities_igs_qs = 2'h2;
  end

  //   F[hpm]: 30:30
  if (N_IOHPMCTR > 0) begin
    assign reg2hw.capabilities.hpm.q = 1'h1;
    assign capabilities_hpm_qs = 1'h1;
  end
  else begin
    assign reg2hw.capabilities.hpm.q = 1'h0;
    assign capabilities_hpm_qs = 1'h0;
  end


  //   F[dbg]: 31:31
  assign reg2hw.capabilities.dbg.q = 1'h0;
  assign capabilities_dbg_qs = 1'h0;


  //   F[pas]: 37:32
  assign reg2hw.capabilities.pas.q = 6'h38;
  assign capabilities_pas_qs = 6'h38;


  //   F[pd8]: 38:38
  assign reg2hw.capabilities.pd8.q = 1'h1;
  assign capabilities_pd8_qs = 1'h1;


  //   F[pd17]: 39:39
  assign reg2hw.capabilities.pd17.q = 1'h1;
  assign capabilities_pd17_qs = 1'h1;


  //   F[pd20]: 40:40
  assign reg2hw.capabilities.pd20.q = 1'h1;
  assign capabilities_pd20_qs = 1'h1;


  // R[fctl]: V(False)

  //   F[be]: 0:0
	assign fctl_be_qs	= 1'b0;


  //   F[wsi]: 1:1
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRW),
    .RESVAL  ((IGS == rv_iommu::MSI_ONLY) ? (1'h0) : (1'h1))
  ) u_fctl_wsi (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fctl_wsi_we),
    .wd     (fctl_wsi_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fctl.wsi.q ),

    // to register interface (read)
    .qs     (fctl_wsi_qs)
  );


  //   F[gxl]: 2:2
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRW),
    .RESVAL  (1'h0)
  ) u_fctl_gxl (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fctl_gxl_we),
    .wd     (fctl_gxl_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fctl.gxl.q ),

    // to register interface (read)
    .qs     (fctl_gxl_qs)
  );


  // R[ddtp]: V(False)

  //   F[iommu_mode]: 3:0
  iommu_field #(
    .DATA_WIDTH      (4),
    .SwAccess(SwAccessRW),
    .RESVAL  (4'h0)
  ) u_ddtp_iommu_mode (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (ddtp_iommu_mode_we),
    .wd     (ddtp_iommu_mode_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.ddtp.iommu_mode.q ),

    // to register interface (read)
    .qs     (ddtp_iommu_mode_qs)
  );


  //   F[busy]: 4:4
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRO),
    .RESVAL  (1'h0)
  ) u_ddtp_busy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.ddtp.busy.q ),

    // to register interface (read)
    .qs     (ddtp_busy_qs)
  );


  //   F[ppn_low]: 31:10
  iommu_field #(
    .DATA_WIDTH      (22),
    .SwAccess(SwAccessRW),
    .RESVAL  (22'h0)
  ) u_ddtp_ppn_l (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (ddtp_ppn_l_we),
    .wd     (ddtp_ppn_l_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.ddtp.ppn.q[21:0] ),

    // to register interface (read)
    .qs     (ddtp_ppn_l_qs)
  );

  //   F[ppn_high]: 21:0
  iommu_field #(
    .DATA_WIDTH      (22),
    .SwAccess(SwAccessRW),
    .RESVAL  (22'h0)
  ) u_ddtp_ppn_h (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (ddtp_ppn_h_we),
    .wd     (ddtp_ppn_h_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.ddtp.ppn.q[43:22] ),

    // to register interface (read)
    .qs     (ddtp_ppn_h_qs)
  );


  // R[cqb]: V(False)

  //   F[log2sz_1]: 4:0
  iommu_field #(
    .DATA_WIDTH      (5),
    .SwAccess(SwAccessRW),
    .RESVAL  (5'h0)
  ) u_cqb_log2sz_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqb_log2sz_1_we),
    .wd     (cqb_log2sz_1_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqb.log2sz_1.q ),

    // to register interface (read)
    .qs     (cqb_log2sz_1_qs)
  );


  //   F[ppn_low]: 31:10
  iommu_field #(
    .DATA_WIDTH      (22),
    .SwAccess(SwAccessRW),
    .RESVAL  (22'h0)
  ) u_cqb_ppn_l (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqb_ppn_l_we),
    .wd     (cqb_ppn_l_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqb.ppn.q[21:0] ),

    // to register interface (read)
    .qs     (cqb_ppn_l_qs)
  );

  //   F[ppn_high]: 21:0
  iommu_field #(
    .DATA_WIDTH      (22),
    .SwAccess(SwAccessRW),
    .RESVAL  (22'h0)
  ) u_cqb_ppn_h (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqb_ppn_h_we),
    .wd     (cqb_ppn_h_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqb.ppn.q[43:22] ),

    // to register interface (read)
    .qs     (cqb_ppn_h_qs)
  );


  // R[cqh]: V(False)

  iommu_field #(
    .DATA_WIDTH      (32),
    .SwAccess(SwAccessRO),
    .RESVAL  (32'h0)
  ) u_cqh (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.cqh.de),
    .ds     (),
    .d      (hw2reg.cqh.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqh.q ),

    // to register interface (read)
    .qs     (cqh_qs)
  );


  // R[cqt]: V(False)

  iommu_field #(
    .DATA_WIDTH      (32),
    .SwAccess(SwAccessRW),
    .RESVAL  (32'h0)
  ) u_cqt (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqt_we),
    .wd     (cqt_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqt.q ),

    // to register interface (read)
    .qs     (cqt_qs)
  );


  // R[fqb]: V(False)

  //   F[log2sz_1]: 4:0
  iommu_field #(
    .DATA_WIDTH      (5),
    .SwAccess(SwAccessRW),
    .RESVAL  (5'h0)
  ) u_fqb_log2sz_1 (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fqb_log2sz_1_we),
    .wd     (fqb_log2sz_1_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqb.log2sz_1.q ),

    // to register interface (read)
    .qs     (fqb_log2sz_1_qs)
  );


  //   F[ppn]: 31:10
  iommu_field #(
    .DATA_WIDTH      (22),
    .SwAccess(SwAccessRW),
    .RESVAL  (22'h0)
  ) u_fqb_ppn_l (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fqb_ppn_l_we),
    .wd     (fqb_ppn_l_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqb.ppn.q[21:0] ),

    // to register interface (read)
    .qs     (fqb_ppn_l_qs)
  );


  //   F[ppn]: 21:0
  iommu_field #(
    .DATA_WIDTH      (22),
    .SwAccess(SwAccessRW),
    .RESVAL  (22'h0)
  ) u_fqb_ppn_h (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fqb_ppn_h_we),
    .wd     (fqb_ppn_h_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqb.ppn.q[43:22] ),

    // to register interface (read)
    .qs     (fqb_ppn_h_qs)
  );


  // R[fqh]: V(False)

  iommu_field #(
    .DATA_WIDTH      (32),
    .SwAccess(SwAccessRW),
    .RESVAL  (32'h0)
  ) u_fqh (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fqh_we),
    .wd     (fqh_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqh.q ),

    // to register interface (read)
    .qs     (fqh_qs)
  );


  // R[fqt]: V(False)

  iommu_field #(
    .DATA_WIDTH      (32),
    .SwAccess(SwAccessRO),
    .RESVAL  (32'h0)
  ) u_fqt (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.fqt.de),
    .ds     (),
    .d      (hw2reg.fqt.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqt.q ),

    // to register interface (read)
    .qs     (fqt_qs)
  );


  // R[cqcsr]: V(False)

  //   F[cqen]: 0:0
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRW),
    .RESVAL  (1'h0)
  ) u_cqcsr_cqen (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqcsr_cqen_we),
    .wd     (cqcsr_cqen_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqcsr.cqen.q ),

    // to register interface (read)
    .qs     (cqcsr_cqen_qs)
  );


  //   F[cie]: 1:1
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRW),
    .RESVAL  (1'h0)
  ) u_cqcsr_cie (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqcsr_cie_we),
    .wd     (cqcsr_cie_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqcsr.cie.q ),

    // to register interface (read)
    .qs     (cqcsr_cie_qs)
  );


  //   F[cqmf]: 8:8
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessW1C),
    .RESVAL  (1'h0)
  ) u_cqcsr_cqmf (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqcsr_cqmf_we),
    .wd     (cqcsr_cqmf_wd),

    // from internal hardware
    .de     (hw2reg.cqcsr.cqmf.de),
    .ds     (),
    .d      (hw2reg.cqcsr.cqmf.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqcsr.cqmf.q ),

    // to register interface (read)
    .qs     (cqcsr_cqmf_qs)
  );


  //   F[cmd_to]: 9:9
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessW1C),
    .RESVAL  (1'h0)
  ) u_cqcsr_cmd_to (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqcsr_cmd_to_we),
    .wd     (cqcsr_cmd_to_wd),

    // from internal hardware
    .de     (hw2reg.cqcsr.cmd_to.de),
    .ds     (),
    .d      (hw2reg.cqcsr.cmd_to.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqcsr.cmd_to.q ),

    // to register interface (read)
    .qs     (cqcsr_cmd_to_qs)
  );


  //   F[cmd_ill]: 10:10
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessW1C),
    .RESVAL  (1'h0)
  ) u_cqcsr_cmd_ill (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqcsr_cmd_ill_we),
    .wd     (cqcsr_cmd_ill_wd),

    // from internal hardware
    .de     (hw2reg.cqcsr.cmd_ill.de),
    .ds     (),
    .d      (hw2reg.cqcsr.cmd_ill.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqcsr.cmd_ill.q ),

    // to register interface (read)
    .qs     (cqcsr_cmd_ill_qs)
  );


  //   F[fence_w_ip]: 11:11
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessW1C),
    .RESVAL  (1'h0)
  ) u_cqcsr_fence_w_ip (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (cqcsr_fence_w_ip_we),
    .wd     (cqcsr_fence_w_ip_wd),

    // from internal hardware
    .de     (hw2reg.cqcsr.fence_w_ip.de),
    .ds     (),
    .d      (hw2reg.cqcsr.fence_w_ip.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqcsr.fence_w_ip.q ),

    // to register interface (read)
    .qs     (cqcsr_fence_w_ip_qs)
  );


  //   F[cqon]: 16:16
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRO),
    .RESVAL  (1'h0)
  ) u_cqcsr_cqon (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.cqcsr.cqon.de),
    .ds     (),
    .d      (hw2reg.cqcsr.cqon.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqcsr.cqon.q ),

    // to register interface (read)
    .qs     (cqcsr_cqon_qs)
  );


  //   F[busy]: 17:17
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRO),
    .RESVAL  (1'h0)
  ) u_cqcsr_busy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.cqcsr.busy.de),
    .ds     (),
    .d      (hw2reg.cqcsr.busy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.cqcsr.busy.q ),

    // to register interface (read)
    .qs     (cqcsr_busy_qs)
  );


  // R[fqcsr]: V(False)

  //   F[fqen]: 0:0
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRW),
    .RESVAL  (1'h0)
  ) u_fqcsr_fqen (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fqcsr_fqen_we),
    .wd     (fqcsr_fqen_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqcsr.fqen.q ),

    // to register interface (read)
    .qs     (fqcsr_fqen_qs)
  );


  //   F[fie]: 1:1
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRW),
    .RESVAL  (1'h0)
  ) u_fqcsr_fie (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fqcsr_fie_we),
    .wd     (fqcsr_fie_wd),

    // from internal hardware
    .de     ('0),
    .d      ('0),
    .ds     (),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqcsr.fie.q ),

    // to register interface (read)
    .qs     (fqcsr_fie_qs)
  );


  //   F[fqmf]: 8:8
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessW1C),
    .RESVAL  (1'h0)
  ) u_fqcsr_fqmf (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fqcsr_fqmf_we),
    .wd     (fqcsr_fqmf_wd),

    // from internal hardware
    .de     (hw2reg.fqcsr.fqmf.de),
    .ds     (),
    .d      (hw2reg.fqcsr.fqmf.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqcsr.fqmf.q ),

    // to register interface (read)
    .qs     (fqcsr_fqmf_qs)
  );


  //   F[fqof]: 9:9
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessW1C),
    .RESVAL  (1'h0)
  ) u_fqcsr_fqof (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (fqcsr_fqof_we),
    .wd     (fqcsr_fqof_wd),

    // from internal hardware
    .de     (hw2reg.fqcsr.fqof.de),
    .ds     (),
    .d      (hw2reg.fqcsr.fqof.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqcsr.fqof.q ),

    // to register interface (read)
    .qs     (fqcsr_fqof_qs)
  );


  //   F[fqon]: 16:16
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRO),
    .RESVAL  (1'h0)
  ) u_fqcsr_fqon (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.fqcsr.fqon.de),
    .ds     (),
    .d      (hw2reg.fqcsr.fqon.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqcsr.fqon.q ),

    // to register interface (read)
    .qs     (fqcsr_fqon_qs)
  );


  //   F[busy]: 17:17
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessRO),
    .RESVAL  (1'h0)
  ) u_fqcsr_busy (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    .we     (1'b0),
    .wd     ('0  ),

    // from internal hardware
    .de     (hw2reg.fqcsr.busy.de),
    .ds     (),
    .d      (hw2reg.fqcsr.busy.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.fqcsr.busy.q ),

    // to register interface (read)
    .qs     (fqcsr_busy_qs)
  );


  // R[ipsr]: V(False)

  //   F[cip]: 0:0
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessW1C),
    .RESVAL  (1'h0)
  ) u_ipsr_cip (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (ipsr_cip_we),
    .wd     (ipsr_cip_wd),

    // from internal hardware
    .de     (hw2reg.ipsr.cip.de),
    .ds     (),
    .d      (hw2reg.ipsr.cip.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.ipsr.cip.q ),

    // to register interface (read)
    .qs     (ipsr_cip_qs)
  );


  //   F[fip]: 1:1
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessW1C),
    .RESVAL  (1'h0)
  ) u_ipsr_fip (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (ipsr_fip_we),
    .wd     (ipsr_fip_wd),

    // from internal hardware
    .de     (hw2reg.ipsr.fip.de),
    .ds     (),
    .d      (hw2reg.ipsr.fip.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.ipsr.fip.q ),

    // to register interface (read)
    .qs     (ipsr_fip_qs)
  );


  //   F[pmip]: 2:2
  iommu_field #(
    .DATA_WIDTH      (1),
    .SwAccess(SwAccessW1C),
    .RESVAL  (1'h0)
  ) u_ipsr_pmip (
    .clk_i   (clk_i    ),
    .rst_ni  (rst_ni  ),

    // from register interface
    .we     (ipsr_pmip_we),
    .wd     (ipsr_pmip_wd),

    // from internal hardware
    .de     (hw2reg.ipsr.pmip.de),
    .ds     (),
    .d      (hw2reg.ipsr.pmip.d ),

    // to internal hardware
    .qe     (),
    .q      (reg2hw.ipsr.pmip.q ),

    // to register interface (read)
    .qs     (ipsr_pmip_qs)
  );


  //   F[pip]: 3:3
  // iommu_field #(
  //   .DATA_WIDTH      (1),
  //   .SwAccess(SwAccessW1C),
  //   .RESVAL  (1'h0)
  // ) u_ipsr_pip (
  //   .clk_i   (clk_i    ),
  //   .rst_ni  (rst_ni  ),

  //   // from register interface
  //   .we     (ipsr_pip_we),
  //   .wd     (ipsr_pip_wd),

  //   // from internal hardware
  //   .de     (hw2reg.ipsr.pip.de),
  //   .ds     (),
  //   .d      (hw2reg.ipsr.pip.d ),

  //   // to internal hardware
  //   .qe     (),
  //   .q      (reg2hw.ipsr.pip.q ),

  //   // to register interface (read)
  //   .qs     (ipsr_pip_qs)
  // );

  assign ipsr_pip_qs = 1'b0;

  generate
  if (N_IOHPMCTR > 0) begin

    // R[iocountinh]: V(False)

    //   F[cy]: 0:0
    iommu_field #(
      .DATA_WIDTH      (1),
      .SwAccess(SwAccessRW),
      .RESVAL  (1'h1)
    ) u_iocountinh_cy (
      .clk_i   (clk_i    ),
      .rst_ni  (rst_ni  ),

      // from register interface
      .we     (iocountinh_cy_we),
      .wd     (iocountinh_cy_wd),

      // from internal hardware
      .de     ('0),
      .ds     (),
      .d      ('0),

      // to internal hardware
      .qe     (),
      .q      (reg2hw.iocountinh.cy.q ),

      // to register interface (read)
      .qs     (iocountinh_cy_qs)
    );

    //   F[hpm]: 31:1
    iommu_field #(
      .DATA_WIDTH      (N_IOHPMCTR),
      .SwAccess(SwAccessRW),
      .RESVAL  (IOCOUNTINH_RESVAL)
    ) u_iocountinh_hpm (
      .clk_i   (clk_i    ),
      .rst_ni  (rst_ni  ),

      // from register interface
      .we     (iocountinh_hpm_we),
      .wd     (iocountinh_hpm_wd[N_IOHPMCTR-1:0]),

      // from internal hardware
      .de     ('0),
      .ds     (),
      .d      ('0),

      // to internal hardware
      .qe     (),
      .q      (reg2hw.iocountinh.hpm.q[N_IOHPMCTR-1:0]),

      // to register interface (read)
      .qs     (iocountinh_hpm_qs[N_IOHPMCTR-1:0])
    );

    // R[iohpmcycles]: V(False)

    //   F[counter_low]: 31:0
    iommu_field #(
      .DATA_WIDTH      (32),
      .SwAccess(SwAccessRW),
      .RESVAL  (32'h0)
    ) u_iohpmcycles_counter_l (
      .clk_i   (clk_i    ),
      .rst_ni  (rst_ni  ),

      // from register interface
      .we     (iohpmcycles_counter_l_we),
      .wd     (iohpmcycles_counter_l_wd),

      // from internal hardware
      .de     (hw2reg.iohpmcycles.counter.de),
      .ds     (),
      .d      (hw2reg.iohpmcycles.counter.d[31:0] ),

      // to internal hardware
      .qe     (),
      .q      (reg2hw.iohpmcycles.counter.q[31:0] ),

      // to register interface (read)
      .qs     (iohpmcycles_counter_l_qs)
    );

    //   F[counter_high]: 30:0
    iommu_field #(
      .DATA_WIDTH      (31),
      .SwAccess(SwAccessRW),
      .RESVAL  (31'h0)
    ) u_iohpmcycles_counter_h (
      .clk_i   (clk_i    ),
      .rst_ni  (rst_ni  ),

      // from register interface
      .we     (iohpmcycles_counter_h_we),
      .wd     (iohpmcycles_counter_h_wd),

      // from internal hardware
      .de     (hw2reg.iohpmcycles.counter.de),
      .ds     (),
      .d      (hw2reg.iohpmcycles.counter.d[62:32] ),

      // to internal hardware
      .qe     (),
      .q      (reg2hw.iohpmcycles.counter.q[62:32] ),

      // to register interface (read)
      .qs     (iohpmcycles_counter_h_qs)
    );

    //   F[of]: 31:31
    iommu_field #(
      .DATA_WIDTH      (1),
      .SwAccess(SwAccessRW),
      .RESVAL  (1'h0)
    ) u_iohpmcycles_of (
      .clk_i   (clk_i    ),
      .rst_ni  (rst_ni  ),

      // from register interface
      .we     (iohpmcycles_of_we),
      .wd     (iohpmcycles_of_wd),

      // from internal hardware
      .de     (hw2reg.iohpmcycles.of.de),
      .ds     (),
      .d      (hw2reg.iohpmcycles.of.d ),

      // to internal hardware
      .qe     (),
      .q      (reg2hw.iohpmcycles.of.q ),

      // to register interface (read)
      .qs     (iohpmcycles_of_qs)
    );

    for (genvar i = 0; i < N_IOHPMCTR; i++) begin

      // R[iohpmctr]: V(False)

      //   F[counter_low]: 31:0
      iommu_field #(
        .DATA_WIDTH      (32),
        .SwAccess(SwAccessRW),
        .RESVAL  (32'h0)
      ) u_iohpmctr_counter_l (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmctr_counter_l_we[i]),
        .wd     (iohpmctr_counter_l_wd[i]),

        // from internal hardware
        .de     (hw2reg.iohpmctr[i].counter.de),
        .ds     (),
        .d      (hw2reg.iohpmctr[i].counter.d[31:0] ),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmctr[i].counter.q[31:0] ),

        // to register interface (read)
        .qs     (iohpmctr_counter_l_qs[i])
      );

      //   F[counter_high]: 31:0
      iommu_field #(
        .DATA_WIDTH      (32),
        .SwAccess(SwAccessRW),
        .RESVAL  (32'h0)
      ) u_iohpmctr_counter_h (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmctr_counter_h_we[i]),
        .wd     (iohpmctr_counter_h_wd[i]),

        // from internal hardware
        .de     (hw2reg.iohpmctr[i].counter.de),
        .ds     (),
        .d      (hw2reg.iohpmctr[i].counter.d[63:32] ),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmctr[i].counter.q[63:32] ),

        // to register interface (read)
        .qs     (iohpmctr_counter_h_qs[i])
      );

      // R[iohpmevt]: V(False)

      //   F[eventid]: 14:0
      iommu_field #(
        .DATA_WIDTH      (15),
        .SwAccess(SwAccessRW),
        .RESVAL  (15'h0)
      ) u_iohpmevt_eventid (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmevt_eventid_we[i]),
        .wd     (iohpmevt_eventid_wd[i]),

        // from internal hardware
        .de     ('0),
        .ds     (),
        .d      ('0),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmevt[i].eventid.q ),

        // to register interface (read)
        .qs     (iohpmevt_eventid_qs[i])
      );

      //   F[dmask]: 15:15
      iommu_field #(
        .DATA_WIDTH      (1),
        .SwAccess(SwAccessRW),
        .RESVAL  (1'h0)
      ) u_iohpmevt_dmask (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmevt_dmask_we[i]),
        .wd     (iohpmevt_dmask_wd[i]),

        // from internal hardware
        .de     ('0),
        .ds     (),
        .d      ('0),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmevt[i].dmask.q ),

        // to register interface (read)
        .qs     (iohpmevt_dmask_qs[i])
      );

      //   F[pid_pscid_low]: 31:16
      iommu_field #(
        .DATA_WIDTH      (16),
        .SwAccess(SwAccessRW),
        .RESVAL  (16'h0)
      ) u_iohpmevt_pid_pscid_l (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmevt_pid_pscid_l_we[i]),
        .wd     (iohpmevt_pid_pscid_l_wd[i]),

        // from internal hardware
        .de     ('0),
        .ds     (),
        .d      ('0),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmevt[i].pid_pscid.q[15:0] ),

        // to register interface (read)
        .qs     (iohpmevt_pid_pscid_l_qs[i])
      );

      //   F[pid_pscid_high]: 31:16
      iommu_field #(
        .DATA_WIDTH      (4),
        .SwAccess(SwAccessRW),
        .RESVAL  (4'h0)
      ) u_iohpmevt_pid_pscid_h (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmevt_pid_pscid_h_we[i]),
        .wd     (iohpmevt_pid_pscid_h_wd[i]),

        // from internal hardware
        .de     ('0),
        .ds     (),
        .d      ('0),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmevt[i].pid_pscid.q[19:16] ),

        // to register interface (read)
        .qs     (iohpmevt_pid_pscid_h_qs[i])
      );

      //   F[did_gscid]: 59:36
      iommu_field #(
        .DATA_WIDTH      (24),
        .SwAccess(SwAccessRW),
        .RESVAL  (24'h0)
      ) u_iohpmevt_did_gscid (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmevt_did_gscid_we[i]),
        .wd     (iohpmevt_did_gscid_wd[i]),

        // from internal hardware
        .de     ('0),
        .ds     (),
        .d      ('0),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmevt[i].did_gscid.q ),

        // to register interface (read)
        .qs     (iohpmevt_did_gscid_qs[i])
      );

      //   F[pv_pscv]: 60:60
      iommu_field #(
        .DATA_WIDTH      (1),
        .SwAccess(SwAccessRW),
        .RESVAL  (1'h0)
      ) u_iohpmevt_pv_pscv (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmevt_pv_pscv_we[i]),
        .wd     (iohpmevt_pv_pscv_wd[i]),

        // from internal hardware
        .de     ('0),
        .ds     (),
        .d      ('0),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmevt[i].pv_pscv.q ),

        // to register interface (read)
        .qs     (iohpmevt_pv_pscv_qs[i])
      );

      //   F[dv_gscv]: 61:61
      iommu_field #(
        .DATA_WIDTH      (1),
        .SwAccess(SwAccessRW),
        .RESVAL  (1'h0)
      ) u_iohpmevt_dv_gscv (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmevt_dv_gscv_we[i]),
        .wd     (iohpmevt_dv_gscv_wd[i]),

        // from internal hardware
        .de     ('0),
        .ds     (),
        .d      ('0),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmevt[i].dv_gscv.q ),

        // to register interface (read)
        .qs     (iohpmevt_dv_gscv_qs[i])
      );

      //   F[idt]: 62:62
      iommu_field #(
        .DATA_WIDTH      (1),
        .SwAccess(SwAccessRW),
        .RESVAL  (1'h0)
      ) u_iohpmevt_idt (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmevt_idt_we[i]),
        .wd     (iohpmevt_idt_wd[i]),

        // from internal hardware
        .de     ('0),
        .ds     (),
        .d      ('0),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmevt[i].idt.q ),

        // to register interface (read)
        .qs     (iohpmevt_idt_qs[i])
      );

      //   F[of]: 63:63
      iommu_field #(
        .DATA_WIDTH      (1),
        .SwAccess(SwAccessRW),
        .RESVAL  (1'h0)
      ) u_iohpmevt_of (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (iohpmevt_of_we[i]),
        .wd     (iohpmevt_of_wd[i]),

        // from internal hardware
        .de     (hw2reg.iohpmevt[i].of.de),
        .ds     (),
        .d      (hw2reg.iohpmevt[i].of.d),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.iohpmevt[i].of.q ),

        // to register interface (read)
        .qs     (iohpmevt_of_qs[i])
      );
    end
  end

  else begin
    
    assign iocountinh_cy_qs       = '0;
    assign iocountinh_hpm_qs      = '0;

    assign iohpmcycles_counter_l_qs = '0;
    assign iohpmcycles_counter_h_qs = '0;
    assign iohpmcycles_of_qs        = '0;

    assign reg2hw.iocountinh.cy.q       = '0;
    assign reg2hw.iocountinh.hpm.q      = '0;

    assign reg2hw.iohpmcycles.counter.q = '0;
    assign reg2hw.iohpmcycles.of.q      = '0;
  end
  endgenerate

  // Hardwire unused wires to zero
  for (genvar i = N_IOHPMCTR; i < 31; i++) begin

      assign iohpmctr_counter_l_qs[i]    = '0;
      assign iohpmctr_counter_h_qs[i]    = '0;

      assign iohpmevt_eventid_qs[i]      = '0;
      assign iohpmevt_dmask_qs[i]        = '0;
      assign iohpmevt_pid_pscid_l_qs[i]  = '0;

      assign iohpmevt_pid_pscid_h_qs[i]  = '0;
      assign iohpmevt_did_gscid_qs[i]    = '0;
      assign iohpmevt_pv_pscv_qs[i]      = '0;
      assign iohpmevt_dv_gscv_qs[i]      = '0;
      assign iohpmevt_idt_qs[i]          = '0;
      assign iohpmevt_of_qs[i]           = '0;

      assign reg2hw.iohpmctr[i].counter.q   = '0;
      assign reg2hw.iohpmevt[i].eventid.q   = '0;
      assign reg2hw.iohpmevt[i].dmask.q     = '0;
      assign reg2hw.iohpmevt[i].pid_pscid.q = '0;
      assign reg2hw.iohpmevt[i].did_gscid.q = '0;
      assign reg2hw.iohpmevt[i].pv_pscv.q   = '0;
      assign reg2hw.iohpmevt[i].dv_gscv.q   = '0;
      assign reg2hw.iohpmevt[i].idt.q       = '0;
      assign reg2hw.iohpmevt[i].of.q        = '0;
    end

  // R[icvec]: V(False)

  generate
  if (LOG2_INTVEC > 0) begin : gen_icvec
    
    //   F[civ]: 3:0
    iommu_field #(
      .DATA_WIDTH      (LOG2_INTVEC),
      .SwAccess(SwAccessRW),
      .RESVAL  ('0)
    ) u_icvec_civ (
      .clk_i   (clk_i   ),
      .rst_ni  (rst_ni  ),

      // from register interface
      .we     (icvec_civ_we),
      .wd     (icvec_civ_wd),

      // from internal hardware
      .de     ('0),
      .d      ('0),
      .ds     (),

      // to internal hardware
      .qe     (),
      .q      (reg2hw.icvec.civ.q[(LOG2_INTVEC-1):0]),

      // to register interface (read)
      .qs     (icvec_civ_qs)
    );


    //   F[fiv]: 7:4
    iommu_field #(
      .DATA_WIDTH      (LOG2_INTVEC),
      .SwAccess(SwAccessRW),
      .RESVAL  ('0)
    ) u_icvec_fiv (
      .clk_i   (clk_i    ),
      .rst_ni  (rst_ni  ),

      // from register interface
      .we     (icvec_fiv_we),
      .wd     (icvec_fiv_wd),

      // from internal hardware
      .de     ('0),
      .d      ('0),
      .ds     (),

      // to internal hardware
      .qe     (),
      .q      (reg2hw.icvec.fiv.q[(LOG2_INTVEC-1):0]),

      // to register interface (read)
      .qs     (icvec_fiv_qs)
    );


    //   F[pmiv]: 11:8
    iommu_field #(
      .DATA_WIDTH      (LOG2_INTVEC),
      .SwAccess(SwAccessRW),
      .RESVAL  ('0)
    ) u_icvec_pmiv (
      .clk_i   (clk_i    ),
      .rst_ni  (rst_ni  ),

      // from register interface
      .we     (icvec_pmiv_we),
      .wd     (icvec_pmiv_wd),

      // from internal hardware
      .de     ('0),
      .d      ('0),
      .ds     (),

      // to internal hardware
      .qe     (),
      .q      (reg2hw.icvec.pmiv.q[(LOG2_INTVEC-1):0]),

      // to register interface (read)
      .qs     (icvec_pmiv_qs)
    );


    //   F[piv]: 15:12
    // iommu_field #(
    //   .DATA_WIDTH      (LOG2_INTVEC),
    //   .SwAccess(SwAccessRW),
    //   .RESVAL  (4'h0)
    // ) u_icvec_piv (
    //   .clk_i   (clk_i    ),
    //   .rst_ni  (rst_ni  ),

    //   // from register interface
    //   .we     (icvec_piv_we),
    //   .wd     (icvec_piv_wd),

    //   // from internal hardware
    //   .de     (hw2reg.icvec.piv.de),
    //   .ds     (),
    //   .d      (hw2reg.icvec.piv.d ),

    //   // to internal hardware
    //   .qe     (),
    //   .q      (reg2hw.icvec.piv.q ),

    //   // to register interface (read)
    //   .qs     (icvec_piv_qs)
    // );

    assign icvec_piv_qs = '0;
    assign reg2hw.icvec.piv.q = '0;
  end

  else begin : gen_icvec_disabled
    assign icvec_civ_qs = '0;
    assign reg2hw.icvec.civ.q = '0;

    assign icvec_fiv_qs = '0;
    assign reg2hw.icvec.fiv.q = '0;

    assign icvec_pmiv_qs = '0;
    assign reg2hw.icvec.pmiv.q = '0;

    assign icvec_piv_qs = '0;
    assign reg2hw.icvec.piv.q = '0;
  end
  endgenerate
  
  // Generate MSI Configuration Table if IOMMU includes MSI gen support
  generate
  if ((IGS == rv_iommu::MSI_ONLY) || (IGS == rv_iommu::BOTH)) begin : gen_msi_cfg_tbl

    for (genvar i = 0; i < N_INT_VEC; i++) begin
      
      // R[msi_addr_x]: V(False)

      //   F[addr_low]: 31:2
      iommu_field #(
        .DATA_WIDTH      (30),
        .SwAccess(SwAccessRW),
        .RESVAL  (30'h0)
      ) u_msi_addr_x_l (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (msi_addr_l_we[i]),
        .wd     (msi_addr_l_wd[i]),

        // from internal hardware
        .de     ('0),
        .d      ('0),
        .ds     (),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.msi_addr[i].addr.q[29:0] ),

        // to register interface (read)
        .qs     (msi_addr_l_qs[i])
      );


      //   F[addr_high]: 23:0
      iommu_field #(
        .DATA_WIDTH      (24),
        .SwAccess(SwAccessRW),
        .RESVAL  (24'h0)
      ) u_msi_addr_x_h (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (msi_addr_h_we[i]),
        .wd     (msi_addr_h_wd[i]),

        // from internal hardware
        .de     ('0),
        .d      ('0),
        .ds     (),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.msi_addr[i].addr.q[53:30] ),

        // to register interface (read)
        .qs     (msi_addr_h_qs[i])
      );


      // R[msi_data_x]: V(False)

      iommu_field #(
        .DATA_WIDTH      (32),
        .SwAccess(SwAccessRW),
        .RESVAL  (32'h0)
      ) u_msi_data_x (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (msi_data_we[i]),
        .wd     (msi_data_wd[i]),

        // from internal hardware
        .de     ('0),
        .d      ('0),
        .ds     (),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.msi_data[i].data.q ),

        // to register interface (read)
        .qs     (msi_data_qs[i])
      );


      // R[msi_vec_ctl_x]: V(False)

      iommu_field #(
        .DATA_WIDTH      (1),
        .SwAccess(SwAccessRW),
        .RESVAL  (1'h0)
      ) u_msi_vec_ctl_x (
        .clk_i   (clk_i    ),
        .rst_ni  (rst_ni  ),

        // from register interface
        .we     (msi_vec_ctl_we[i]),
        .wd     (msi_vec_ctl_wd[i]),

        // from internal hardware
        .de     ('0),
        .d      ('0),
        .ds     (),

        // to internal hardware
        .qe     (),
        .q      (reg2hw.msi_vec_ctl[i].m.q ),

        // to register interface (read)
        .qs     (msi_vec_ctl_qs[i])
      );
    end
  end
  endgenerate

  // Hardwire unimplemented vectors to zero 
  for (genvar i = N_INT_VEC; i < 16; i++) begin

    assign msi_addr_l_qs[i]   = '0;
    assign msi_addr_h_qs[i]   = '0;
    assign msi_data_qs[i]     = '0;
    assign msi_vec_ctl_qs[i]  = 1'b0;
    
    assign reg2hw.msi_addr[i].addr.q  = '0;
    assign reg2hw.msi_data[i].data.q  = '0;
    assign reg2hw.msi_vec_ctl[i].m.q  = 1'b0;
  end
  

  //-------------------
  //# Address hit logic
  //-------------------
  logic [210:0] addr_hit;

  /*
    Address hit map:
    [ 0]      Capabilities (low)
    [ 1]      Capabilities (high)
    [ 2]      fctl
    [ 3]      ddtp (low)
    [ 4]      ddtp (high)
    [ 5]      cqb (low)
    [ 6]      cqb (high)
    [ 7]      cqh
    [ 8]      cqt
    [ 9]      fqb (low)
    [10]      fqb (high)
    [11]      fqh
    [12]      fqt
    [13]      cqcsr
    [14]      fqcsr
    [15]      ipsr
    [16]      iocntovf
    [17]      iocntinh
    [18]      iohpmcycles (low)
    [19]      iohpmcycles (high)
    [50:20]   iohpmctr_n (low)
    [81:51]   iohpmctr_n (high)
    [112:82]  iohpmevt_n (low)
    [143:113] iohpmevt_n (high)
    [144]     icvec (low)
    [145]     icvec (high)
    [161:146] msi_addr_x (low)
    [177:162] msi_addr_x (high)
    [193:178] msi_data_x
    [209:194] msi_vec_ctl_x
  */

  // Mandatory registers
  assign addr_hit[ 0] = (reg_addr == IOMMU_CAPABILITIES_OFFSET_L);
  assign addr_hit[ 1] = (reg_addr == IOMMU_CAPABILITIES_OFFSET_H);
  assign addr_hit[ 2] = (reg_addr == IOMMU_FCTL_OFFSET);
  assign addr_hit[ 3] = (reg_addr == IOMMU_DDTP_OFFSET_L);
  assign addr_hit[ 4] = (reg_addr == IOMMU_DDTP_OFFSET_H);
  assign addr_hit[ 5] = (reg_addr == IOMMU_CQB_OFFSET_L);
  assign addr_hit[ 6] = (reg_addr == IOMMU_CQB_OFFSET_H);
  assign addr_hit[ 7] = (reg_addr == IOMMU_CQH_OFFSET);
  assign addr_hit[ 8] = (reg_addr == IOMMU_CQT_OFFSET);
  assign addr_hit[ 9] = (reg_addr == IOMMU_FQB_OFFSET_L);
  assign addr_hit[10] = (reg_addr == IOMMU_FQB_OFFSET_H);
  assign addr_hit[11] = (reg_addr == IOMMU_FQH_OFFSET);
  assign addr_hit[12] = (reg_addr == IOMMU_FQT_OFFSET);
  assign addr_hit[13] = (reg_addr == IOMMU_CQCSR_OFFSET);
  assign addr_hit[14] = (reg_addr == IOMMU_FQCSR_OFFSET);
  assign addr_hit[15] = (reg_addr == IOMMU_IPSR_OFFSET);

  // HPM
  assign addr_hit[16] = (N_IOHPMCTR > 0) ? (reg_addr == IOMMU_IOCNTOVF_OFFSET)      : 1'b0;
  assign addr_hit[17] = (N_IOHPMCTR > 0) ? (reg_addr == IOMMU_IOCNTINH_OFFSET)      : 1'b0;
  assign addr_hit[18] = (N_IOHPMCTR > 0) ? (reg_addr == IOMMU_IOHPMCYCLES_OFFSET_L) : 1'b0;
  assign addr_hit[19] = (N_IOHPMCTR > 0) ? (reg_addr == IOMMU_IOHPMCYCLES_OFFSET_H) : 1'b0;

  for (genvar i = 0; i < N_IOHPMCTR; i++) begin
    assign addr_hit[20+i]   = (reg_addr == (IOMMU_IOHPMCTR_OFFSET_L + i*8));
    assign addr_hit[51+i]   = (reg_addr == (IOMMU_IOHPMCTR_OFFSET_H + i*8));
    assign addr_hit[82+i]   = (reg_addr == (IOMMU_IOHPMEVT_OFFSET_L + i*8));
    assign addr_hit[113+i]  = (reg_addr == (IOMMU_IOHPMEVT_OFFSET_H + i*8));
  end

  // Hardwire unused bits to 0
  for (genvar i = N_IOHPMCTR; i < 31; i++) begin
    assign addr_hit[20+i]  = 1'b0;
    assign addr_hit[51+i]  = 1'b0;
    assign addr_hit[82+i]  = 1'b0;
    assign addr_hit[113+i] = 1'b0;
  end

  assign addr_hit[144] = (reg_addr == IOMMU_ICVEC_OFFSET_L);
  assign addr_hit[145] = (reg_addr == IOMMU_ICVEC_OFFSET_H);

  // MSI Config Table
  for (genvar i = 0; i < N_INT_VEC; i++) begin
    assign addr_hit[146+i] = (reg_addr == (IOMMU_MSI_ADDR_OFFSET_L  + i*16));
    assign addr_hit[162+i] = (reg_addr == (IOMMU_MSI_ADDR_OFFSET_H  + i*16));
    assign addr_hit[178+i] = (reg_addr == (IOMMU_MSI_DATA_OFFSET    + i*16));
    assign addr_hit[194+i] = (reg_addr == (IOMMU_MSI_VEC_CTL_OFFSET + i*16));
  end

  // Hardwire unimplemented vectors to zero
  for (genvar i = N_INT_VEC; i < 16; i++) begin
    assign addr_hit[146+i] = 1'b0;
    assign addr_hit[162+i] = 1'b0;
    assign addr_hit[178+i] = 1'b0;
    assign addr_hit[194+i] = 1'b0;
  end

  assign addrmiss = (reg_re || reg_we) ? ~|addr_hit : 1'b0 ;  // a miss occurs when reading or writing and no addr_hit flag is set

  //# Check whether sub-word write is permitted

  // Mandatory registers
  for (genvar i = 0; i < 20; i++) begin
    assign wr_err[i] = (addr_hit[i] & (|(IOMMU_PERMIT[i] & ~reg_be)));
  end

  for (genvar i = 0; i < N_IOHPMCTR; i++) begin
    assign wr_err[20+i]   = (addr_hit[20+i ] & (|(IOMMU_PERMIT[20] & ~reg_be)));
    assign wr_err[51+i]   = (addr_hit[51+i ] & (|(IOMMU_PERMIT[21] & ~reg_be)));
    assign wr_err[82+i]   = (addr_hit[82+i ] & (|(IOMMU_PERMIT[22] & ~reg_be)));
    assign wr_err[113+i]  = (addr_hit[113+i] & (|(IOMMU_PERMIT[23] & ~reg_be)));
  end

  // Hardwire unused bits to 0
  for (genvar i = N_IOHPMCTR; i < 31; i++) begin
    assign wr_err[20+i]   = 1'b0;
    assign wr_err[51+i]   = 1'b0;
    assign wr_err[82+i]   = 1'b0;
    assign wr_err[113+i]  = 1'b0;
  end

  assign wr_err[144] = (addr_hit[144] & (|(IOMMU_PERMIT[24] & ~reg_be)));
  assign wr_err[145] = (addr_hit[145] & (|(IOMMU_PERMIT[25] & ~reg_be)));

  // MSI Config Table
  for (genvar i = 0; i < N_INT_VEC; i++) begin
    
    assign wr_err[146+i] = (addr_hit[146+i] & (|(IOMMU_PERMIT[26] & ~reg_be)));
    assign wr_err[162+i] = (addr_hit[162+i] & (|(IOMMU_PERMIT[27] & ~reg_be)));
    assign wr_err[178+i] = (addr_hit[178+i] & (|(IOMMU_PERMIT[28] & ~reg_be)));
    assign wr_err[194+i] = (addr_hit[194+i] & (|(IOMMU_PERMIT[29] & ~reg_be)));
  end

  // Hardwire unused bits to zero
  for (genvar i = N_INT_VEC; i < 16; i++) begin
    
    assign wr_err[146+i] = 1'b0;
    assign wr_err[162+i] = 1'b0;
    assign wr_err[178+i] = 1'b0;
    assign wr_err[194+i] = 1'b0;
  end

  //------------------
  //# Write data logic
  //------------------

	// Hardwire fctl.BE since we are only using little-endian processing
	// assign fctl_be_we = addr_hit[1] & reg_we & !reg_error;
	// assign fctl_be_wd = reg_wdata[0];

  // fctl
  // Interrupts can not be generated as MSI (0) if caps.IGS != {0,2}, and can not be generated as WSI (1) if caps.IGS != {1,2}
  assign fctl_wsi_we = (addr_hit[2] & reg_we & !reg_error) & 
    (((reg_wdata[1] == 1'b0) & (reg2hw.capabilities.igs.q inside {2'b00, 2'b10})) | 
     ((reg_wdata[1] == 1'b1) & (reg2hw.capabilities.igs.q inside {2'b01, 2'b10})));
  assign fctl_wsi_wd = reg_wdata[1];

  assign fctl_gxl_we = addr_hit[2] & reg_we & !reg_error;
  assign fctl_gxl_wd = reg_wdata[2];

  // ddtp (low)
  // Only values less or equal than 4 can be written to ddtp.iommu_mode
  assign ddtp_iommu_mode_we = addr_hit[3] & reg_we & !reg_error & (reg_wdata[3:0] <= 4);
  assign ddtp_iommu_mode_wd = reg_wdata[3:0];

  assign ddtp_ppn_l_we = addr_hit[3] & reg_we & !reg_error;
  assign ddtp_ppn_l_wd = reg_wdata[31:10];

  // ddtp (high)
  assign ddtp_ppn_h_we = addr_hit[4] & reg_we & !reg_error;
  assign ddtp_ppn_h_wd = reg_wdata[21:0];

  // cqb (low)
  assign cqb_log2sz_1_we = addr_hit[5] & reg_we & !reg_error;
  assign cqb_log2sz_1_wd = reg_wdata[4:0];

  assign cqb_ppn_l_we = addr_hit[5] & reg_we & !reg_error;
  assign cqb_ppn_l_wd = reg_wdata[31:10];

  // cqb (high)
  assign cqb_ppn_h_we = addr_hit[6] & reg_we & !reg_error;
  assign cqb_ppn_h_wd = reg_wdata[21:0];

  // cqt
  // Only LOG2SZ-1:0 bits are writable.
  assign cqt_we = addr_hit[8] & reg_we & !reg_error;
  assign cqt_wd = reg_wdata[31:0] & ({32{1'b1}} >> (31 - reg2hw.cqb.log2sz_1.q));

  // fqb (low)
  assign fqb_log2sz_1_we = addr_hit[9] & reg_we & !reg_error;
  assign fqb_log2sz_1_wd = reg_wdata[4:0];

  assign fqb_ppn_l_we = addr_hit[9] & reg_we & !reg_error;
  assign fqb_ppn_l_wd = reg_wdata[31:10];

  // fqb (high)
  assign fqb_ppn_h_we = addr_hit[10] & reg_we & !reg_error;
  assign fqb_ppn_h_wd = reg_wdata[21:0];

  // fqh
  // Only LOG2SZ-1:0 bits are writable.
  assign fqh_we = addr_hit[11] & reg_we & !reg_error;
  assign fqh_wd = reg_wdata[31:0] & ({32{1'b1}} >> (31 - reg2hw.fqb.log2sz_1.q));

  // cqcsr
  assign cqcsr_cqen_we = addr_hit[13] & reg_we & !reg_error;
  assign cqcsr_cqen_wd = reg_wdata[0];

  assign cqcsr_cie_we = addr_hit[13] & reg_we & !reg_error;
  assign cqcsr_cie_wd = reg_wdata[1];

  assign cqcsr_cqmf_we = addr_hit[13] & reg_we & !reg_error;
  assign cqcsr_cqmf_wd = reg_wdata[8];

  assign cqcsr_cmd_to_we = addr_hit[13] & reg_we & !reg_error;
  assign cqcsr_cmd_to_wd = reg_wdata[9];

  assign cqcsr_cmd_ill_we = addr_hit[13] & reg_we & !reg_error;
  assign cqcsr_cmd_ill_wd = reg_wdata[10];

  assign cqcsr_fence_w_ip_we = addr_hit[13] & reg_we & !reg_error;
  assign cqcsr_fence_w_ip_wd = reg_wdata[11];

  // fqcsr
  assign fqcsr_fqen_we = addr_hit[14] & reg_we & !reg_error;
  assign fqcsr_fqen_wd = reg_wdata[0];

  assign fqcsr_fie_we = addr_hit[14] & reg_we & !reg_error;
  assign fqcsr_fie_wd = reg_wdata[1];

  assign fqcsr_fqmf_we = addr_hit[14] & reg_we & !reg_error;
  assign fqcsr_fqmf_wd = reg_wdata[8];

  assign fqcsr_fqof_we = addr_hit[14] & reg_we & !reg_error;
  assign fqcsr_fqof_wd = reg_wdata[9];

  // ipsr
  assign ipsr_cip_we = addr_hit[15] & reg_we & !reg_error;
  assign ipsr_cip_wd = reg_wdata[0];

  assign ipsr_fip_we = addr_hit[15] & reg_we & !reg_error;
  assign ipsr_fip_wd = reg_wdata[1];

  assign ipsr_pmip_we = addr_hit[15] & reg_we & !reg_error;
  assign ipsr_pmip_wd = reg_wdata[2];

  assign ipsr_pip_we = addr_hit[15] & reg_we & !reg_error;
  assign ipsr_pip_wd = reg_wdata[3];

  // HPM
  generate
  if (N_IOHPMCTR > 0) begin
    
    // iocntinh
    assign iocountinh_cy_we = addr_hit[17] & reg_we & !reg_error;
    assign iocountinh_cy_wd = reg_wdata[0];

    assign iocountinh_hpm_we = addr_hit[17] & reg_we & !reg_error;
    assign iocountinh_hpm_wd[N_IOHPMCTR-1:0] = reg_wdata[N_IOHPMCTR:1];

    // iohpmcycles (low)
    assign iohpmcycles_counter_l_we = addr_hit[18] & reg_we & !reg_error;
    assign iohpmcycles_counter_l_wd = reg_wdata[31:0];

    // iohpmcycles (high)
    assign iohpmcycles_counter_h_we = addr_hit[19] & reg_we & !reg_error;
    assign iohpmcycles_counter_h_wd = reg_wdata[30:0];

    assign iohpmcycles_of_we = addr_hit[19] & reg_we & !reg_error;
    assign iohpmcycles_of_wd = reg_wdata[31];

    for (genvar i = 0; i < N_IOHPMCTR; i++) begin
      
      // iohpmctr_n (low)
      assign iohpmctr_counter_l_we[i]   = addr_hit[20+i] & reg_we & !reg_error;
      assign iohpmctr_counter_l_wd[i]   = reg_wdata[31:0];

      // iohpmctr_n (high)
      assign iohpmctr_counter_h_we[i]   = addr_hit[51+i] & reg_we & !reg_error;
      assign iohpmctr_counter_h_wd[i]   = reg_wdata[31:0];

      // iohpmevt_n (low)
      assign iohpmevt_eventid_we[i]     = addr_hit[82+i] & reg_we & !reg_error;
      assign iohpmevt_eventid_wd[i]     = reg_wdata[14:0];
      assign iohpmevt_dmask_we[i]       = addr_hit[82+i] & reg_we & !reg_error;
      assign iohpmevt_dmask_wd[i]       = reg_wdata[15];
      assign iohpmevt_pid_pscid_l_we[i] = addr_hit[82+i] & reg_we & !reg_error;
      assign iohpmevt_pid_pscid_l_wd[i] = reg_wdata[31:16];

      // iohpmevt_n (high)
      assign iohpmevt_pid_pscid_h_we[i] = addr_hit[113+i] & reg_we & !reg_error;
      assign iohpmevt_pid_pscid_h_wd[i] = reg_wdata[3:0];
      assign iohpmevt_did_gscid_we[i]   = addr_hit[113+i] & reg_we & !reg_error;
      assign iohpmevt_did_gscid_wd[i]   = reg_wdata[27:4];
      assign iohpmevt_pv_pscv_we[i]     = addr_hit[113+i] & reg_we & !reg_error;
      assign iohpmevt_pv_pscv_wd[i]     = reg_wdata[28];
      assign iohpmevt_dv_gscv_we[i]     = addr_hit[113+i] & reg_we & !reg_error;
      assign iohpmevt_dv_gscv_wd[i]     = reg_wdata[29];
      assign iohpmevt_idt_we[i]         = addr_hit[113+i] & reg_we & !reg_error;
      assign iohpmevt_idt_wd[i]         = reg_wdata[30];
      assign iohpmevt_of_we[i]          = addr_hit[113+i] & reg_we & !reg_error;
      assign iohpmevt_of_wd[i]          = reg_wdata[31];
    end
  end

  // No HPM
  else begin
    
    assign iocountinh_cy_we = 1'b0;
    assign iocountinh_cy_wd = '0;
    assign iocountinh_hpm_we = 1'b0;
    assign iocountinh_hpm_wd = '0;

    assign iohpmcycles_counter_l_we = 1'b0;
    assign iohpmcycles_counter_l_wd = '0;
    assign iohpmcycles_counter_h_we = 1'b0;
    assign iohpmcycles_counter_h_wd = '0;
    assign iohpmcycles_of_we = 1'b0;
    assign iohpmcycles_of_wd = '0;
  end
  endgenerate

  // Hardwire unused wires to zero
  for (genvar i = N_IOHPMCTR; i < 31; i++) begin

      assign iohpmctr_counter_l_we[i]   = 1'b0;
      assign iohpmctr_counter_l_wd[i]   = '0;
      assign iohpmctr_counter_h_we[i]   = 1'b0;
      assign iohpmctr_counter_h_wd[i]   = '0;

      assign iohpmevt_eventid_we[i]     = 1'b0;
      assign iohpmevt_eventid_wd[i]     = '0;
      assign iohpmevt_dmask_we[i]       = 1'b0;
      assign iohpmevt_dmask_wd[i]       = '0;
      assign iohpmevt_pid_pscid_l_we[i] = 1'b0;
      assign iohpmevt_pid_pscid_l_wd[i] = '0;

      assign iohpmevt_pid_pscid_h_we[i] = 1'b0;
      assign iohpmevt_pid_pscid_h_wd[i] = '0;
      assign iohpmevt_did_gscid_we[i]   = 1'b0;
      assign iohpmevt_did_gscid_wd[i]   = '0;
      assign iohpmevt_pv_pscv_we[i]     = 1'b0;
      assign iohpmevt_pv_pscv_wd[i]     = '0;
      assign iohpmevt_dv_gscv_we[i]     = 1'b0;
      assign iohpmevt_dv_gscv_wd[i]     = '0;
      assign iohpmevt_idt_we[i]         = 1'b0;
      assign iohpmevt_idt_wd[i]         = '0;
      assign iohpmevt_of_we[i]          = 1'b0;
      assign iohpmevt_of_wd[i]          = '0;
    end

  // icvec
  assign icvec_civ_we = addr_hit[144] & reg_we & !reg_error;
  assign icvec_civ_wd = reg_wdata[(LOG2_INTVEC-1)+0:0];

  assign icvec_fiv_we = addr_hit[144] & reg_we & !reg_error;
  assign icvec_fiv_wd = reg_wdata[(LOG2_INTVEC-1)+4:4];

  assign icvec_pmiv_we = addr_hit[144] & reg_we & !reg_error;
  assign icvec_pmiv_wd = reg_wdata[(LOG2_INTVEC-1)+8:8];

  assign icvec_piv_we = addr_hit[144] & reg_we & !reg_error;
  assign icvec_piv_wd = reg_wdata[(LOG2_INTVEC-1)+12:12];

  // MSI Config Table
  generate
  for (genvar i = 0; i < N_INT_VEC; i++) begin
    
    // msi_addr_x (low)
    assign msi_addr_l_we[i] = addr_hit[146+i] & reg_we & !reg_error;
    assign msi_addr_l_wd[i] = reg_wdata[31:2];

    // msi_addr_x (high)
    assign msi_addr_h_we[i] = addr_hit[162+i] & reg_we & !reg_error;
    assign msi_addr_h_wd[i] = reg_wdata[23:0];

    // msi_data_x
    assign msi_data_we[i] = addr_hit[178+i] & reg_we & !reg_error;
    assign msi_data_wd[i] = reg_wdata[31:0];

    // msi_vec_ctl_x
    assign msi_vec_ctl_we[i] = addr_hit[194+i] & reg_we & !reg_error;
    assign msi_vec_ctl_wd[i] = reg_wdata[0];
  end
  endgenerate

  // Hardwire unused bits to zero
  for (genvar i = N_INT_VEC; i < 0; i++) begin
    
    assign msi_addr_l_we[i] = 1'b0;
    assign msi_addr_l_wd[i] = '0;

    assign msi_addr_h_we[i] = 1'b0;
    assign msi_addr_h_wd[i] = '0;

    assign msi_data_we[i] = 1'b0;
    assign msi_data_wd[i] = '0;

    assign msi_vec_ctl_we[i] = 1'b0;
    assign msi_vec_ctl_wd[i] = '0;
  end

  //------------------
  // # Read data logic
  //------------------
  
  logic   iohpmctr_l_hit_vector, iohpmctr_h_hit_vector;
  logic   iohpmevt_l_hit_vector, iohpmevt_h_hit_vector;
  assign  iohpmctr_l_hit_vector = (N_IOHPMCTR > 0) ? (|addr_hit[(20+N_IOHPMCTR-1):20])   : ('0);
  assign  iohpmctr_h_hit_vector = (N_IOHPMCTR > 0) ? (|addr_hit[(51+N_IOHPMCTR-1):51])   : ('0);
  assign  iohpmevt_l_hit_vector = (N_IOHPMCTR > 0) ? (|addr_hit[(82+N_IOHPMCTR-1):82])   : ('0);
  assign  iohpmevt_h_hit_vector = (N_IOHPMCTR > 0) ? (|addr_hit[(113+N_IOHPMCTR-1):113]) : ('0);

  logic msi_addr_l_hit_vector;
  logic msi_addr_h_hit_vector;
  logic msi_data_hit_vector;
  logic msi_vect_hit_vector;

  assign msi_addr_l_hit_vector = (N_INT_VEC > 0) ? (|addr_hit[(146+N_INT_VEC-1):146]) : '0;
  assign msi_addr_h_hit_vector = (N_INT_VEC > 0) ? (|addr_hit[(162+N_INT_VEC-1):162]) : '0;
  assign msi_data_hit_vector   = (N_INT_VEC > 0) ? (|addr_hit[(178+N_INT_VEC-1):178]) : '0;
  assign msi_vect_hit_vector   = (N_INT_VEC > 0) ? (|addr_hit[(194+N_INT_VEC-1):194]) : '0;

  always_comb begin
    reg_rdata_next = '0;
    unique case (1'b1)

      // caps (low)
      addr_hit[0]: begin
        reg_rdata_next[7:0] = capabilities_version_qs;
        reg_rdata_next[8] = capabilities_sv32_qs;
        reg_rdata_next[9] = capabilities_sv39_qs;
        reg_rdata_next[10] = capabilities_sv48_qs;
        reg_rdata_next[11] = capabilities_sv57_qs;
        reg_rdata_next[14:12] = '0;
        reg_rdata_next[15] = capabilities_svpbmt_qs;
        reg_rdata_next[16] = capabilities_sv32x4_qs;
        reg_rdata_next[17] = capabilities_sv39x4_qs;
        reg_rdata_next[18] = capabilities_sv48x4_qs;
        reg_rdata_next[19] = capabilities_sv57x4_qs;
        reg_rdata_next[20] = capabilities_amo_mrif_qs;
        reg_rdata_next[21] = '0;
        reg_rdata_next[22] = capabilities_msi_flat_qs;
        reg_rdata_next[23] = capabilities_msi_mrif_qs;
        reg_rdata_next[24] = capabilities_amo_hwad_qs;
        reg_rdata_next[25] = capabilities_ats_qs;
        reg_rdata_next[26] = capabilities_t2gpa_qs;
        reg_rdata_next[27] = capabilities_endi_qs;
        reg_rdata_next[29:28] = capabilities_igs_qs;
        reg_rdata_next[30] = capabilities_hpm_qs;
        reg_rdata_next[31] = capabilities_dbg_qs;
      end

      // caps (high)
      addr_hit[1]: begin
        reg_rdata_next[5:0] = capabilities_pas_qs;
        reg_rdata_next[6] = capabilities_pd8_qs;
        reg_rdata_next[7] = capabilities_pd17_qs;
        reg_rdata_next[8] = capabilities_pd20_qs;
        reg_rdata_next[31:9] = '0;
      end

      // fctl
      addr_hit[2]: begin
        reg_rdata_next[0] = fctl_be_qs;
        reg_rdata_next[1] = fctl_wsi_qs;
        reg_rdata_next[2] = fctl_gxl_qs;
        reg_rdata_next[15:3] = '0;
        reg_rdata_next[31:16] = '0;
      end

      // ddtp (low)
      addr_hit[3]: begin
        reg_rdata_next[3:0] = ddtp_iommu_mode_qs;
        reg_rdata_next[4] = ddtp_busy_qs;
        reg_rdata_next[9:5] = '0;
        reg_rdata_next[31:10] = ddtp_ppn_l_qs;
      end

      // ddtp (high)
      addr_hit[4]: begin
        reg_rdata_next[21:0] = ddtp_ppn_h_qs;
        reg_rdata_next[31:22] = '0;
      end

      // cqb (low)
      addr_hit[5]: begin
        reg_rdata_next[4:0] = cqb_log2sz_1_qs;
        reg_rdata_next[9:5] = '0;
        reg_rdata_next[31:10] = cqb_ppn_l_qs;
      end

      // cqb (high)
      addr_hit[6]: begin
        reg_rdata_next[21:0] = cqb_ppn_h_qs;
        reg_rdata_next[31:22] = '0;
      end

      // cqh
      addr_hit[7]: begin
        reg_rdata_next[31:0] = cqh_qs;
      end

      // cqt
      addr_hit[8]: begin
        reg_rdata_next[31:0] = cqt_qs;
      end

      // fqb (low)
      addr_hit[9]: begin
        reg_rdata_next[4:0] = fqb_log2sz_1_qs;
        reg_rdata_next[9:5] = '0;
        reg_rdata_next[31:10] = fqb_ppn_l_qs;
      end

      // fqb (high)
      addr_hit[10]: begin
        reg_rdata_next[21:0] = fqb_ppn_h_qs;
        reg_rdata_next[31:22] = '0;
      end

      // fqh
      addr_hit[11]: begin
        reg_rdata_next[31:0] = fqh_qs;
      end

      // fqt
      addr_hit[12]: begin
        reg_rdata_next[31:0] = fqt_qs;
      end

      // cqcsr
      addr_hit[13]: begin
        reg_rdata_next[0] = cqcsr_cqen_qs;
        reg_rdata_next[1] = cqcsr_cie_qs;
        reg_rdata_next[7:2] = '0;
        reg_rdata_next[8] = cqcsr_cqmf_qs;
        reg_rdata_next[9] = cqcsr_cmd_to_qs;
        reg_rdata_next[10] = cqcsr_cmd_ill_qs;
        reg_rdata_next[11] = cqcsr_fence_w_ip_qs;
        reg_rdata_next[15:12] = '0;
        reg_rdata_next[16] = cqcsr_cqon_qs;
        reg_rdata_next[17] = cqcsr_busy_qs;
        reg_rdata_next[27:18] = '0;
        reg_rdata_next[31:28] = '0;
      end

      // fqcsr
      addr_hit[14]: begin
        reg_rdata_next[0] = fqcsr_fqen_qs;
        reg_rdata_next[1] = fqcsr_fie_qs;
        reg_rdata_next[7:2] = '0;
        reg_rdata_next[8] = fqcsr_fqmf_qs;
        reg_rdata_next[9] = fqcsr_fqof_qs;
        reg_rdata_next[15:10] = '0;
        reg_rdata_next[16] = fqcsr_fqon_qs;
        reg_rdata_next[17] = fqcsr_busy_qs;
        reg_rdata_next[27:18] = '0;
        reg_rdata_next[31:28] = '0;
      end

      // ipsr
      addr_hit[15]: begin
        reg_rdata_next[0] = ipsr_cip_qs;
        reg_rdata_next[1] = ipsr_fip_qs;
        reg_rdata_next[2] = ipsr_pmip_qs;
        reg_rdata_next[3] = ipsr_pip_qs;
        reg_rdata_next[31:4] = '0;
      end

      // iocountovf
      addr_hit[16]: begin
        reg_rdata_next[0] = iohpmcycles_of_qs;
        for (int unsigned i = 1; i < (N_IOHPMCTR + 1); i++) begin
          reg_rdata_next[i] = iohpmevt_of_qs[i-1];
        end
        if (N_IOHPMCTR != 31) 
          reg_rdata_next[31:N_IOHPMCTR+1] = '0;
      end

      // iocountinh
      addr_hit[17]: begin
        reg_rdata_next[0] = iocountinh_cy_qs;
        for (int unsigned i = 1; i < (N_IOHPMCTR + 1); i++) begin
          reg_rdata_next[i] = iocountinh_hpm_qs[i-1];
        end
        if (N_IOHPMCTR != 31) 
          reg_rdata_next[31:N_IOHPMCTR+1] = '0;
      end

      // iohpmcycles (low)
      addr_hit[18]: begin
        reg_rdata_next[31:0] = iohpmcycles_counter_l_qs;
      end

      // iohpmcycles (high)
      addr_hit[19]: begin
        reg_rdata_next[30:0] = iohpmcycles_counter_h_qs;
        reg_rdata_next[31] = iohpmcycles_of_qs;
      end

      // iohpmctr_n (low)
      (iohpmctr_l_hit_vector): begin

        for (int unsigned i = 0; i < N_IOHPMCTR; i++) begin
          if (addr_hit[i+20])
            reg_rdata_next[31:0] = iohpmctr_counter_l_qs[i];
        end
      end

      // iohpmctr_n (high)
      (iohpmctr_h_hit_vector): begin

        for (int unsigned i = 0; i < N_IOHPMCTR; i++) begin
          if (addr_hit[i+51])
            reg_rdata_next[31:0] = iohpmctr_counter_h_qs[i];
        end
      end

      // iohpmevt_n (low)
      (iohpmevt_l_hit_vector): begin

        for (int unsigned i = 0; i < N_IOHPMCTR; i++) begin
          if (addr_hit[i+82]) begin
            reg_rdata_next[14:0]  = iohpmevt_eventid_qs[i];
            reg_rdata_next[15]    = iohpmevt_dmask_qs[i];
            reg_rdata_next[31:16] = iohpmevt_pid_pscid_l_qs[i];
          end 
        end
      end

      // iohpmevt_n (high)
      (iohpmevt_h_hit_vector): begin

        for (int unsigned i = 0; i < N_IOHPMCTR; i++) begin
          if (addr_hit[i+113]) begin
            reg_rdata_next[3:0]   = iohpmevt_pid_pscid_h_qs[i];
            reg_rdata_next[27:4]  = iohpmevt_did_gscid_qs[i];
            reg_rdata_next[28]    = iohpmevt_pv_pscv_qs[i];
            reg_rdata_next[29]    = iohpmevt_dv_gscv_qs[i];
            reg_rdata_next[30]    = iohpmevt_idt_qs[i];
            reg_rdata_next[31]    = iohpmevt_of_qs[i];
          end 
        end
      end

      // icvec (low)
      addr_hit[144]: begin
        reg_rdata_next[(LOG2_INTVEC-1)+0:0] = icvec_civ_qs;
        reg_rdata_next[(LOG2_INTVEC-1)+4:4] = icvec_fiv_qs;
        reg_rdata_next[(LOG2_INTVEC-1)+8:8] = icvec_pmiv_qs;
        reg_rdata_next[(LOG2_INTVEC-1)+12:12] = icvec_piv_qs;
        reg_rdata_next[31:16] = '0;
      end

      // icvec (high)
      addr_hit[145]: begin
        reg_rdata_next[31:0] = '0;
      end

      // msi_addr_x (low)
      (msi_addr_l_hit_vector): begin

        for (int unsigned i = 0; i < N_INT_VEC; i++) begin
          if (addr_hit[i+146]) begin
            reg_rdata_next[1:0] = '0;
            reg_rdata_next[31:2] = msi_addr_l_qs[i];
          end
        end
      end

      // msi_addr_x (high)
      (msi_addr_h_hit_vector): begin

        for (int unsigned i = 0; i < N_INT_VEC; i++) begin
          if (addr_hit[i+162]) begin
            reg_rdata_next[23:0] = msi_addr_h_qs[i];
            reg_rdata_next[31:24] = '0;
          end
        end
      end

      // msi_data_x
      (msi_data_hit_vector): begin

        for (int unsigned i = 0; i < N_INT_VEC; i++) begin
          if (addr_hit[i+178]) begin
            reg_rdata_next[31:0] = msi_data_qs[i];
          end
        end
      end

      // msi_vec_ctl_x
      (msi_vect_hit_vector): begin

        for (int unsigned i = 0; i < N_INT_VEC; i++) begin
          if (addr_hit[i+194]) begin
            reg_rdata_next[0] = msi_vec_ctl_qs[i];
            reg_rdata_next[31:1] = '0;
          end
        end
      end

      default: begin
        reg_rdata_next = '0;
      end
    endcase
  end

  // * Unused signal tieoff

  // wdata / byte enable are not always fully used
  // add a blanket unused statement to handle lint waivers
  logic unused_wdata;
  logic unused_be;
  assign unused_wdata = ^reg_wdata;
  assign unused_be = ^reg_be;

  // Assertions for Register Interface
  `ASSERT(en2addrHit, (reg_we || reg_re) |-> $onehot0(addr_hit))

endmodule
